# VLIW Processor Architecture Specification

## Overview

A 4-slot VLIW processor targeting FPGA implementation (Xilinx/AMD), designed for
pure processing kernels. The pipeline is **fully exposed**: there is no
interlock, no branch-shadow squash and no interrupt mechanism. Instruction
latencies, the branch shadow and the write ordering are **architectural** —
the compiler must satisfy them, and a scheduling mistake yields a wrong
result rather than a stall. In exchange the machine has no hazard hardware
on its critical path, and the register file may be used as a dataflow
buffer. One dynamic mechanism remains, for the single hazard a compiler
cannot decide statically (§No Interlock, §Faults and Host Control).

---

## Top-level Parameters

| Parameter          | Default | Range  | Description                              |
|--------------------|---------|--------|------------------------------------------|
| `IMEM_DEPTH_LOG2`  | 10      | 10–14  | Instruction memory depth (1K–16K words)  |
| `DMEM_DEPTH_LOG2`  | 11      | 10–14  | Data memory depth (1K–16K 32-bit words)  |
| `BRAM_OUT_REG`     | TBD     | 0–1    | Hardened BRAM/DPRAM output register, per memory; `1` = +1 read-latency cycle for higher `fmax` (see §Memory Model) |

---

## VLIW Word

- **Total width**: 144 bits = 4 × 36 bits
- **Slots**: 2× ALU, 1× Load/Store, 1× Control
- **PC unit**: 1 VLIW word per cycle (not byte-addressed)
- **Slot instruction width**: each slot is a self-contained **36-bit**
  instruction. There is no dedicated `valid` bit — an unused slot is encoded
  as the slot's **`NOP` opcode** (`opcode = 000000`), so an empty bundle is
  four `NOP`s (an all-zero 144-bit word).
- **BRAM mapping**: 144-bit-wide × 2^IMEM_DEPTH_LOG2 deep, which is **one
  BRAM36 per slot** in its 36-bit-wide mode. The four extra bits per slot
  over a 32-bit encoding are therefore free: they come from the BRAM parity
  bits, which the `NOP`-opcode validity scheme had already released. Nothing
  is split across BRAMs and nothing is wasted.
- **What the 4 extra bits buy**: 8-bit global source addresses (5 banks × 32
  registers = 160 names, up from the 7-bit / 128-name limit) and materially
  wider constants in every slot — see the per-slot specifications.

---

## Register File

- **Physical**: shared register file (implementation in `../lib/vliwrf`),
  sized to provide the per-slot read/write ports listed below
- **Banks**: 5 banks of 32 registers (one per write port: ALU0, ALU1,
  LS-A, LS-B, CTRL — the LS slot owns one bank per lane of a dual load,
  LOAD_STORE.md §2)
- **Read**: any slot can read any bank (full 8-bit source address: bank[2:0] + reg[4:0])
- **Write**: each slot writes only its own bank (5-bit destination, bank implicit from slot)
- **Hazard model**: this write-local / read-global split keeps every write
  port private to one slot, so write-port arbitration does not exist in
  hardware; ordering writes to one register is the compiler's obligation
  (§No Interlock)
- **Zero register (`r0`)**: a **single canonical zero** lives at one
  physical location, conventionally **bank 0, reg 0** (global read address
  `0000000`). Because every slot can read any bank, every slot reads `r0`
  through this one address — no need to replicate zero in every bank. The
  per-bank locals at "reg 0" of banks 1–3 are therefore **free general-purpose
  registers** (or scratch / discard slots) for their owning slot.
- **Write ports**: exactly **one per slot** — four total. Each slot retires at
  most one result per cycle, so the write-port count is fixed by the slot count;
  there is nothing in the datapath that can drive a fifth concurrent write. This
  is what keeps each bank a single-writer structure (see §No Interlock).
  There is no interrupt entry, hence no context save at all — a fault halts
  the core and the host inspects the register file as it stands
  (§Faults and Host Control).

| Slot        | Write port | Bank bits |
|-------------|------------|-----------|
| ALU 0       | port 0     | `000`     |
| ALU 1       | port 1     | `001`     |
| Load/Store (LS-A, lane 0) | port 2 | `010` |
| Load/Store (LS-B, lane 1) | port 3 | `011` |
| Control     | port 4     | `100`     |


### Implementation of `r0`

Only **one physical storage cell** needs to actually hold zero — at the
canonical address `0000000` (bank 0, reg 0). Three implementation styles are
possible; option A is recommended for this design.


#### Option A — Init + write-enable mask (recommended)

Combine the two tricks shown above:

- One physical cell is initialized to 0 at FPGA configuration time.
- The single write port that owns bank 0 is masked when `waddr == 0`.

**Pros**: zero impact on the read path (purely registered BRAM output → keeps
>200 MHz), one AND gate per relevant write port, no extra latency.
**Cons**: relies on `initial` being honored (it is, on Xilinx/AMD BRAM/LUTRAM
and in all mainstream simulators).

#### Option B — Read-side mux (force read data to 0)

Force the read data of any port to 0 whenever its read address is the
canonical `0000000`, regardless of what the storage cell contains:

```systemverilog
assign rdata[p] = (raddr[p] == 7'b0000000) ? 32'b0 : mem_rdata[p];
```

**Pros**: no init required, no write-enable masking, robust against any reset
or partial-reconfiguration corner case.
**Cons**: adds a 32-bit 2:1 mux **after** the registered BRAM output, on the
RR→EX1 critical path. On Xilinx BRAM the registered output is the fast path,
and an extra LUT layer typically costs 0.5–1.0 ns → may break the >200 MHz
target. Mitigation: register the `(raddr == 0)` flag one cycle ahead and apply
the mux in EX1, but then the zeroing is no longer visible at the RR stage.

#### Option C — Write-side AND on the data bus

Force the **stored value** to 0 by AND-gating `wdata` with `(waddr != 0)`
instead of masking `wen`:

```systemverilog
wire [31:0] wdata_eff = wdata[0] & {32{waddr[0] != 5'd0}};
always_ff @(posedge clk)
    if (wen[0]) mem[0][waddr[0]] <= wdata_eff;
```

**Pros**: works even if the BRAM macro doesn't expose a per-port write-enable
the way you want; cell `[0][0]` is naturally rewritten to 0 on every write
addressed to it, so no init is even needed (after the first write).
**Cons**: 32-bit AND in front of the BRAM data input (one LUT layer on the
write path — usually not critical), and `r0` only becomes 0 **after** the
first write to address 0 (so an `initial` is still recommended for cycle-0
correctness).

#### Summary

| Option | Read-path cost | Write-path cost | Needs init | Recommended |
|--------|----------------|-----------------|------------|-------------|
| A — init + `wen` mask        | none      | 1 AND gate (port 0 only) | yes | **✓** |
| B — read-side mux            | +1 LUT layer (32-bit mux) | none | no  |       |
| C — write-side data AND      | none      | 32 AND gates on port 0   | optional |     |

The other banks need **no special handling**: their local "address 0" is a
normal R/W register usable as scratch by the slot that owns the bank.

Compiler convention: emit `r0` as the global 8-bit address `00000000` whenever a
zero source operand is needed (e.g. `ADD rd, r0, rs` for `MOV`, `JAL r0, target`
for `J`).
---

## Slot Formats

### Common header (all slots)

Every slot is a **32-bit** instruction. The two top fields have the same meaning
in every slot:

| Bit     | Field    | Description                                            |
|---------|----------|--------------------------------------------------------|
| [35:30] | `opcode` | 6-bit instruction selector (per-slot opcode space)     |

There is no `fmt` bit: register and immediate forms are **distinct opcodes**
within each slot's flat 6-bit space (e.g. `ADD`/`ADDI`, `MOV`/`MOVI`). On the
LUT6 fabric a 6-bit field costs the same to decode as 5, and the per-slot opcode
namespaces make opcodes plentiful, so a flat encoding is free.

`opcode = 000000` is **`NOP`** in every slot (the canonical empty-slot encoding);
there is no dedicated `valid` bit. Source registers are **8-bit** global
addresses (`bank[2:0]` + `reg[4:0]`, any bank); the destination is **5-bit**
(bank implicit from the slot).

---

### ALU Slot (×2)

Two identical ALU slots (writing banks 0 and 1). Each is a full **36-bit**
instruction using the common header (flat `opcode[35:30]`, `NOP = 000000`),
with **R-type** (reg–reg, plus a `funct(9)` extension field), **I-type**
(reg–`imm17`, signed **±65535**; register and immediate forms are distinct
opcodes) and **U-type** (`LUI`, `imm20`) formats. Operations:
`ADD SUB AND OR XOR SLT SLTU SLL SRL SRA MUL MULH INV_SQRT LUI`, with advisory
latencies of 2–5 cycles (see §Compiler latency model).

The complete encoding — opcode map, bit layouts, pseudo-instructions
(`MOV NEG NOT LI`) and the `LUI`+`ADDI` 32-bit constant idiom — is specified in
**`ALU.md`**, which is the authoritative reference; it is not duplicated here
to avoid drift.

---

### Load/Store Slot (×1)

The Load/Store slot is a full **32-bit** instruction using the common header
(flat `opcode[35:30]`, `NOP = 000000`). It is the core's single memory port —
loads and stores to the on-chip data scratchpad and to the memory-mapped control
registers at the top of the data address space. Access width and sign/zero
extension are folded into the opcode (`LB LH LW LBU LHU` / `SB SH SW`); the
address is `rs_base + sign_ext(imm)` (byte-addressed, little-endian). Loads carry
a 17-bit offset (**±64 KB**); stores an `imm14` (**±8 KB**), since a store spends a
second source register on `rs_data`. Load latency is **2 cycles** at the
`BRAM_OUT_REG = 0` baseline (see §Memory Model); load-use RAW hazards are covered
by the compiler (§Latency model, §No Interlock).

The complete encoding, addressing/alignment rules, the data-memory address map
(including the memory-mapped `LOOP_*` registers), and memory-ordering
semantics are specified in **`LOAD_STORE.md`**, which is the authoritative
reference; they are not duplicated here to avoid drift.

---

### Control Slot (×1)

The Control slot is a full **32-bit** instruction using the common header
(flat `opcode[35:30]`, `NOP = 000000`). It owns PC sequencing, branches,
jumps, halts, and the single-context hardware loop, and also carries a
**lightweight integer ALU** (`ADD/SUB/ADDI`, `AND/OR/XOR/ANDI`, `SLT*` — no
multiply/shift, result at W+1) so pointer/loop-counter/condition arithmetic can
run in the otherwise-idle control slot instead of stealing an ALU slot. Its
complete encoding — `BEQ…BGEU`, `JAL`, `JALR`, `TRAP`, `LOOP`/`LOOPI`,
`LCLR`, `MOV`/`MOVI`, `CMOV`/`CMOVI`, and the integer ops — is specified in
**`CONTROL_UNIT.md`**, which is the authoritative reference; it is not duplicated
here to avoid drift.

Field conventions (see `CONTROL_UNIT.md` §3 for exact bit layouts):

- 8-bit global source addresses (`rs1`, `rs2`); 5-bit destination (`rd`).
- Signed `target` / `imm` fields share one sign-extend alignment at bit 8;
  the branch target sits higher, at `[29:16]` (CONTROL_UNIT.md §3.1).
- `JAL` uses a 25-bit target (**±16 M VLIW words**); conditional branches a
  14-bit target (**±8191 VLIW words**); `JALR` a 17-bit offset.
- Branch shadow = `BRANCH_SHADOW` VLIW words of **architectural delay slots**
  (CONTROL_UNIT.md §5.1): they execute whether or not the branch is taken, and
  the compiler must fill them — with `NOP`s when it has nothing to hoist. This
  is a **control** hazard the compiler owns, exactly as it owns the data
  hazards (§Latency model).

#### Control pseudo-instructions

| Pseudo        | Real instruction  | Meaning                |
|---------------|------------------|------------------------|
| `J target`    | `JAL r0, target`  | unconditional jump     |
| `CALL target` | `JAL ra, target`  | subroutine call        |
| `RET`         | `JALR r0, ra, 0`  | return from subroutine |
| `BEQZ rs, t`  | `BEQ r0, rs, t`   | branch if zero         |
| `BNEZ rs, t`  | `BNE r0, rs, t`   | branch if not zero     |

---

## Pipeline

### Stages

```
Cycle:  1     2     3     4     5     6     7     8
       [IF]─[ID]─[RR]─[EX1]─[EX2]─[EX3]─[EX4]─[EX5]
                            ↑WB   ↑WB   ↑WB   ↑WB   ↑WB
                            ADD   BAR   MUL         ISQRT
                            LOAD
```

| Stage | Name      | Description                                       | Implementation        |
|-------|-----------|---------------------------------------------------|-----------------------|
| IF    | Fetch     | Read 144-bit VLIW word from IMEM                  | BRAM registered output|
| ID    | Decode    | Split slots, decode opcodes, compute RF addresses | Combinational         |
| RR    | Reg Read  | Read register file                                | BRAM registered output|
| EX1   | Execute 1 | ALU first stage, LS address calc, branch resolve  | Registered            |
| EX2   | Execute 2 | Writeback: ADD/SUB/logic/LOAD                     | Registered            |
| EX3   | Execute 3 | Writeback: barrel shift                           | Registered            |
| EX4   | Execute 4 | Writeback: multiplier                             | Registered            |
| EX5   | Execute 5 | Writeback: INV_SQRT                               | Registered            |

> **BRAM output register (`fmax`).** IF and RR read BRAM (fetch and register
> file). Each may enable the hardened **output register** (`BRAM_OUT_REG`),
> adding one read-latency cycle for higher `fmax` — on Xilinx the synthesizer
> *absorbs* a datapath register into the BRAM macro, so it costs no fabric flop.
> This deepens the pipeline (and, for fetch, grows `BRANCH_SHADOW`) and is
> therefore **ISA-visible**: both the data latencies and the number of delay
> slots move, so the kernels must be rebuilt. See §Memory Model. The stage
> list above is the `BRAM_OUT_REG = 0` baseline.

### Latency model (architectural)

These latencies are a **correctness contract**, not a scheduling hint: nothing
interlocks. A dependent instruction scheduled earlier than the values below
reads the destination register's *previous* content, silently and without
diagnostic.

For every register `rN` written by instruction `I` issued at VLIW word W, the
earliest a dependent instruction may read `rN` is:

| Operation         | Earliest next read (VLIW words after writer) |
|-------------------|----------------------------------------------|
| ADD/SUB/logic     | W + 2                                        |
| LOAD              | W + 2                                        |
| Barrel shift      | W + 3                                        |
| MUL/MULH          | W + 4                                        |
| INV_SQRT          | W + 5                                        |
| JAL/JALR (rd)     | W + 1                                        |
| Branch (shadow)   | 3 **architectural delay slots** — always executed |

> The branch shadow is **not squashed**: the `BRANCH_SHADOW` words following a
> branch execute whether or not the branch is taken. They are delay slots in
> the classical sense, and the compiler must fill them with useful work or
> explicit `NOP`s — an unfilled shadow is a correctness fault, not a lost
> cycle.

> **Write ordering.** Latencies are not uniform (W+2 to W+5), so two writes to
> the *same* register may land out of program order — a `MUL` at W+4 followed
> by an `ADD` at W+2 leaves the multiply's value in place. The compiler owns
> this ordering; a machine with an interlock got it for free from the WAW
> check (SCOREBOARD.md §4).

---

## No Interlock (the exposed contract)

The core ships **without** a hardware interlock. The workload is small compute
kernels compiled from available sources, so a latency change is a rebuild
rather than a binary-compatibility event, and the ~10-operand comparison
network an interlock puts on the RR→EX1 path buys a guarantee this machine
does not need.

What the compiler owns, in full:

- **Data latencies** (§Latency model) — read a value before it lands and you
  get the previous one.
- **Write ordering to one register**, because latencies differ per operation.
- **The branch shadow** — three architectural delay slots, always executed.
- **Restartability**, if wanted: a value in flight survives an arbitrary delay
  only if nothing overwrites its register meanwhile. Dense code may reuse a
  single register as a dataflow buffer (a value consumed in the one cycle it
  occupies the name); code that must tolerate being interrupted mid-flight
  needs `ceil(L / II)` names instead. Since this core has no interrupts
  (§Faults and Host Control), the dense form is the normal one.

What hardware still owns is exactly one thing: **the bank-conflict freeze**.
A strided pair whose stride is a multiple of 3 needs two bank accesses
(LOAD_STORE.md §10.4), and the stride is a *register* value — no static
schedule can anticipate it. The whole pipeline therefore freezes for one
cycle, in-flight operations included, so every pipeline-relative latency is
preserved and the bubble is invisible except in the cycle count. That is the
design rule: **hardware handles only what the compiler cannot decide.**

`SCOREBOARD.md` is retained in full as the specification of an interlocked
variant, with a status note marking what no longer applies; its §7.6 remains
the clearest statement of the obligations above.

---

## Memory Model

The core uses **directly-addressed on-chip scratchpads, not caches.** Both the
instruction and data memories are FPGA BRAM/DPRAM in the single `clk` domain,
addressed directly by the core: there is **no instruction cache and no data
cache**, by design.

### Why no caches

- **Determinism.** The zero-overhead hardware loop, the fixed `BRANCH_SHADOW`,
  and the exposed per-instruction latency model all assume fixed, known fetch
  and load latency. A cache miss is a non-deterministic bubble — it would
  undermine the predictable cycle counts that make this core useful as a
  tensor/DSP tile.
- **Nothing to cache.** Kernels fit in IMEM (1K–16K VLIW words); their working
  set is streamed into the DMEM scratchpad by the NoC/NI (Port B, DMA-style).
  There is no larger backing memory the core demand-fetches from.
- **No coherency burden.** DMEM Port A (core) and Port B (NoC) share the DPRAM
  with no arbitration by construction (see §Data Memory and NoC Interface). A
  data cache in front of Port A would owe coherency against Port B writes — a
  large complexity jump for no benefit in the scratchpad model.

### Working set larger than on-chip memory

Handled **explicitly**, the accelerator way, not with a cache:

- **Program > IMEM**: size `IMEM_DEPTH_LOG2`, or reload / overlay IMEM by DMA
  between kernels (deterministic, software-scheduled).
- **Data > DMEM**: double-buffer / tile the scratchpad, orchestrated by the
  NoC/NI — the standard tiled-dataflow pattern.

### On-chip read latency is an ISA property

Each on-chip memory (IMEM, DMEM, register file) may be built **with or without
the hardened BRAM output register** (`BRAM_OUT_REG`). Enabling it adds **one
cycle of read latency** in exchange for higher `fmax`: on Xilinx the synthesizer
*absorbs* a datapath register placed after the memory into the BRAM's built-in
output register, so it costs no fabric flop and shortens the clock-to-out path.

Without an interlock this choice is **visible to software**, and changing it
invalidates compiled code:

- **Data reads** (register file, loads): every latency in §Latency model
  shifts by one, so every dependence distance the compiler emitted becomes
  wrong by one.
- **Instruction fetch**: a deeper fetch grows `BRANCH_SHADOW`, and the shadow
  is now made of **architectural delay slots** — one more word to fill after
  every branch.

Both are compile-time constants (`BRAM_OUT_REG`, and `ADRREG` for the data
memory, LOAD_STORE.md §10.1): pick them per build, then rebuild the kernels.

### Future external memory (out of scope)

The bank-conflict freeze (§No Interlock) is a **total** pipeline freeze, so
the same mechanism would serve a variable-latency memory: a miss would hold
every stage until the data arrives, preserving all pipeline-relative timings
and therefore the compiler's schedule. That is explicitly out of scope for
the base core, which is cacheless and deterministic — but the mechanism it
would need already exists.

---

## Data Memory and NoC Interface

### DPRAM split

```
┌─────────────────┐
│  Port A         │ ← Load/Store slot (processor)
│  DPRAM          │
│  Port B         │ ← NoC / Network Interface
└─────────────────┘
```

No arbitration needed — ports never conflict by construction.

### NoC/NI handshake (port B)

| Signal     | Width             | Direction | Description                    |
|------------|-------------------|-----------|--------------------------------|
| `ni_req`   | 1                 | NI→core   | transaction request            |
| `ni_wen`   | 1                 | NI→core   | 1=write, 0=read                |
| `ni_addr`  | `DMEM_DEPTH_LOG2` | NI→core   | word address                   |
| `ni_wdata` | 32                | NI→core   | write data                     |
| `ni_ack`   | 1                 | core→NI   | transaction accepted (1-cycle) |
| `ni_rdata` | 32                | core→NI   | read data (valid when ack=1)   |

---

## Faults and Host Control

The core has **no interrupts**. Masking them while writes are in flight would
mask them permanently — a software-pipelined kernel always has a write in
flight — so the dispatch model is **run to completion with polling**: the NI
writes a work descriptor and a completion flag into the scratchpad through
side B, and the core reads them between kernels (§NoC/NI handshake). This
removes the entire interrupt subsystem: no vector, no mask, no cause-driven
entry, no `ERET`, no saved-PC shadow, and no restartability requirement on
kernel code.

### Faults are fatal

A synchronous fault **halts** the core. There is no handler and no resume:

| Cause | Raised by |
|-------|-----------|
| `MISALIGN` | an access violating §3.5 natural alignment (LOAD_STORE.md) |
| `OOB`      | an effective address outside the backed scratchpad (`oob`, LOAD_STORE.md §10.4) |
| `ILLEGAL`  | a reserved opcode in any slot |
| `SOFTWARE` | the control slot's `TRAP` instruction — a deliberate halt, usable as an assertion or breakpoint |

On a fault the core stops fetching, latches the cause and the faulting bundle
PC, and raises `faulted` in its status word. Nothing is written back from the
faulting bundle onward; earlier in-flight results land normally, which leaves
the register file in a state the host can inspect.

### Host control block (side B)

The `parmem3_2` word address is `DMEM_DEPTH_LOG2 + 2` bits wide while only
`3 × 2^DMEM_DEPTH_LOG2` words are backed, so a whole `2^DMEM_DEPTH_LOG2`-word
region above the scratchpad is unbacked by construction (LOAD_STORE.md §4.1).
The control block is decoded there, at the base of that region, and is
reachable **from side B only** — the NI and the host own it; the core cannot
alter its own run state.

| Offset | Name          | Access | Description |
|--------|---------------|--------|-------------|
| +0     | `CTRL`        | W      | bit 0 `RUN` — writing 1 flushes the pipeline, clears `faulted`, sets PC to `START_PC` and runs; bit 1 `HALT` — stop fetching at the next bundle boundary |
| +1     | `STATUS`      | R      | bit 0 `running`, bit 1 `halted`, bit 2 `faulted` |
| +2     | `FAULT_CAUSE` | R      | cause code of the halting fault (table above) |
| +3     | `FAULT_PC`    | R      | VLIW-word address of the faulting bundle |
| +4     | `START_PC`    | RW     | PC loaded by `RUN`; resets to **0** |

The intended sequence is: poll `STATUS` until `halted`, load code and data
through side B, then write `RUN`. A clean restart from zero is the reset
default — `START_PC` exists so a host can also resume at a kernel entry point
without rewriting IMEM.

- **Reset** leaves the core halted with `START_PC = 0`; it never runs until
  the host asks (§Reset and Clock).
- `RUN` empties the pipeline before fetching, so no in-flight operation from a
  previous kernel can land in the new one.
- `HALT` stops at a bundle boundary and lets in-flight writes retire, so the
  register file is coherent when the host inspects it.
- The block is on side B's clock (the NI domain); the dual-clock banks are the
  crossing, exactly as for the scratchpad.

> **Open item — instruction memory.** Loading IMEM from the NI is not
> specified here. A clean restart usually implies new code, so the NI needs a
> write path to IMEM (a second port, or a boot-time DMA); it is the one piece
> of the host interface still missing.

---

## Reset and Clock

| Property | Value                             |
|----------|-----------------------------------|
| Reset    | Synchronous, active high (`srst`) |
| Clock    | Single clock domain (`clk`)       |
| Target   | Xilinx/AMD FPGA, >200 MHz         |

**Architectural state at reset (`srst`):**

| State                                       | Reset value                                              |
|---------------------------------------------|----------------------------------------------------------|
| `PC`                                        | `0` — execution starts at IMEM word 0                    |
| Pipeline                                    | empty (all slots `NOP`)                                  |
| `loop_active` (committed **and** speculative) | `0` (no armed loop)                                    |
| Core run state                              | **halted**; `START_PC = 0`, `faulted = 0` (§Faults and Host Control) |
| General-purpose registers                   | **not reset by `srst`** (BRAM contents persist); `0` after FPGA configuration (`initial`), `r0` permanently 0 (§Implementation of `r0`) |

---

## BRAM Resource Estimate

| Memory          | Width    | Depth                | BRAMs (36Kb) |
|-----------------|----------|----------------------|--------------|
| Instruction     | 144 bits | 2^`IMEM_DEPTH_LOG2`  | 1–2          |
| Data            | 32 bits  | 2^`DMEM_DEPTH_LOG2`  | 1–4          |
| Register file   | 32 bits  | 6×32                 | ~1           |
| **Total (typ)** |          |                      | **~4**       |

---

## Relationship to RISC-V

The scalar instruction semantics of this VLIW are **inspired by RV32IM**, but
the encoding, register file, addressing unit, and several control-flow
features are custom. The processor is **not binary-compatible with RISC-V**
and is **not** a RISC-V implementation.

### Borrowed from RISC-V

| Aspect                    | RISC-V origin                                              |
|---------------------------|------------------------------------------------------------|
| ALU mnemonics & semantics | `ADD SUB AND OR XOR SLT SLTU SLL SRL SRA MUL MULH LUI`     |
| Load/store mnemonics      | `LB LH LW LBU LHU / SB SH SW` — names and width/sign semantics (encoding is a custom flat per-slot opcode) |
| Branches                  | `BEQ BNE BLT BGE BLTU BGEU` — same conditions              |
| Jumps                     | `JAL` (link = next PC), `JALR` (`rs1 + imm17`)             |
| Type taxonomy             | R / I / U / B / J terminology                              |
| Hardwired zero register   | `r0` convention (`x0` in RV)                               |
| 32-bit constant idiom     | `LUI` + `ADDI` (20-bit + 12-bit immediates)                |
| Pseudo-instructions       | `NOP MOV NEG NOT LI J CALL RET BEQZ BNEZ`                  |
| Trap / return model       | None — `TRAP` halts, there is no handler and no return     |

### Differences from RISC-V

| Aspect                | This VLIW                                       | RISC-V                                |
|-----------------------|-------------------------------------------------|---------------------------------------|
| Word format           | 144-bit VLIW, 4 × 36-bit slots                  | 32-bit (or 16-bit `C`) scalar         |
| Bit-level encoding    | Custom (flat `opcode[35:30]` per slot)          | 7-bit major opcode in `[6:0]`         |
| Opcode width          | Flat 6-bit opcode per slot (no `fmt` bit)       | 7-bit op + `funct3` + `funct7`        |
| Register file         | 5 banks × 32 regs, 8-bit global read address    | Flat 32 regs, 5-bit address           |
| PC unit               | VLIW-word addressed                             | Byte addressed                        |
| Branch range          | ±2048 VLIW words (12-bit field)                 | ±4 KiB bytes                          |
| `JAL` range           | ±1 M VLIW words (21-bit field)                  | ±1 MiB bytes (20-bit field)           |
| Hazard handling       | **None** — exposed pipeline, latencies and delay slots architectural | Implementation-defined interlocks |
| Hardware loops        | `LOOP` / `LOOPI`, single-context (see CONTROL_UNIT) | Not present (custom extensions only)  |
| `INV_SQRT`            | Native ALU op                                   | Not present                           |
| Exceptions            | Fatal: halt + cause, read by the host over the NI port | Trap handler, resumable               |
| Missing               | `AUIPC FENCE ECALL EBREAK CSR* atomics F D C V` | Present in standard extensions        |

### One-line summary

> *Mnemonics and per-instruction semantics are RV32IM-flavored; everything
> below the assembler (encoding, packing, register file, PC unit, control
> flow extensions) is custom and FPGA-tuned.*
