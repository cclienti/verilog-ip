# VLIW Processor Architecture Specification

## Overview

A 4-slot VLIW processor targeting FPGA implementation (Xilinx/AMD), designed for
pure processing kernels. A lightweight **hardware scoreboard** (interlock)
guarantees correctness; the compiler inserts NOPs only for performance, never
for correctness (Hexagon-style). Per-instruction latencies are known and
exposed to the compiler for **optimization**, but they are not welded into the
ISA — pipeline depth and individual latencies can change without breaking
binaries. See §Scoreboard.

---

## Top-level Parameters

| Parameter          | Default | Range  | Description                              |
|--------------------|---------|--------|------------------------------------------|
| `IMEM_DEPTH_LOG2`  | 10      | 10–14  | Instruction memory depth (1K–16K words)  |
| `DMEM_DEPTH_LOG2`  | 11      | 10–14  | Data memory depth (1K–16K 32-bit words)  |
| `NB_IRQ`           | 1       | 1–32   | Number of IRQ lines                      |
| `BRAM_OUT_REG`     | TBD     | 0–1    | Hardened BRAM/DPRAM output register, per memory; `1` = +1 read-latency cycle for higher `fmax` (see §Memory Model) |

---

## VLIW Word

- **Total width**: 128 bits = 4 × 32 bits
- **Slots**: 2× ALU, 1× Load/Store, 1× Control
- **PC unit**: 1 VLIW word per cycle (not byte-addressed)
- **Slot instruction width**: each slot is a self-contained **32-bit**
  instruction (same width as the scalar ISA). There is no dedicated `valid`
  bit — an unused slot is encoded as the slot's **`NOP` opcode** (`opcode =
  000000`), so an empty bundle is four `NOP`s (an all-zero 128-bit word).
- **BRAM mapping**: 128-bit-wide × 2^IMEM_DEPTH_LOG2 deep. Because slots no
  longer use a BRAM parity bit as a `valid` flag (validity is now the per-slot
  `NOP` opcode), the BRAM parity bits are **free** and may be used for optional
  ECC.

---

## Register File

- **Physical**: shared register file (implementation in `../lib/vliwrf`),
  sized to provide the per-slot read/write ports listed below
- **Banks**: 4 banks of 32 registers (one bank per slot)
- **Read**: any slot can read any bank (full 7-bit source address: bank[2:0] + reg[4:0])
- **Write**: each slot writes only its own bank (5-bit destination, bank implicit from slot)
- **Hazard model**: this write-local / read-global split is exactly what makes
  the hardware scoreboard cheap — WAW hazards and write-port conflicts stay
  inside a single bank, and only RAW hazards cross banks (see §Scoreboard)
- **Zero register (`r0`)**: a **single canonical zero** lives at one
  physical location, conventionally **bank 0, reg 0** (global read address
  `0000000`). Because every slot can read any bank, every slot reads `r0`
  through this one address — no need to replicate zero in every bank. The
  per-bank locals at "reg 0" of banks 1–3 are therefore **free general-purpose
  registers** (or scratch / discard slots) for their owning slot.
- **Write ports**: exactly **one per slot** — four total. Each slot retires at
  most one result per cycle, so the write-port count is fixed by the slot count;
  there is nothing in the datapath that can drive a fifth concurrent write. This
  is what keeps each bank a single-writer structure (see §Scoreboard).
  Register state is spilled/filled to memory in software on interrupt entry/exit
  (see §Interrupts and Exceptions) — there are no dedicated context-save ports.

| Slot        | Write port | Bank bits |
|-------------|------------|-----------|
| ALU 0       | port 0     | `000`     |
| ALU 1       | port 1     | `001`     |
| Load/Store  | port 2     | `010`     |
| Control     | port 3     | `011`     |


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

Compiler convention: emit `r0` as the global 7-bit address `0000000` whenever a
zero source operand is needed (e.g. `ADD rd, r0, rs` for `MOV`, `JAL r0, target`
for `J`).
---

## Slot Formats

### Common header (all slots)

Every slot is a **32-bit** instruction. The two top fields have the same meaning
in every slot:

| Bit     | Field    | Description                                            |
|---------|----------|--------------------------------------------------------|
| [31:26] | `opcode` | 6-bit instruction selector (per-slot opcode space)     |

There is no `fmt` bit: register and immediate forms are **distinct opcodes**
within each slot's flat 6-bit space (e.g. `ADD`/`ADDI`, `MOV`/`MOVI`). On the
LUT6 fabric a 6-bit field costs the same to decode as 5, and the per-slot opcode
namespaces make opcodes plentiful, so a flat encoding is free.

`opcode = 000000` is **`NOP`** in every slot (the canonical empty-slot encoding);
there is no dedicated `valid` bit. Source registers are **7-bit** global
addresses (`bank[2:0]` + `reg[4:0]`, any bank); the destination is **5-bit**
(bank implicit from the slot).

---

### ALU Slot (×2)

**R-type**: register–register operation

| [31:26]   | [25:21] | [20:14] | [13:7] | [6:0]    |
|-----------|---------|---------|--------|----------|
| opcode(6) | rd(5)   | rs1(7)  | rs2(7) | funct(7) |

- `funct(7)` refines the operation / reserves room for future 3-operand forms;
  the base ops are fully selected by `opcode`, so the assembler emits `0`.

**I-type**: register–immediate operation (distinct opcode from its R-type form)

| [31:26]   | [25:21] | [20:14] | [13:0]    |
|-----------|---------|---------|-----------|
| opcode(6) | rd(5)   | rs1(7)  | imm14(14) |

- `imm14` is signed, sign-extended to 32 bits → range **±8191**.

**U-type** (`LUI`):

| [31:26] | [25:21] | [20:1]    | [0]       |
|---------|---------|-----------|-----------|
| `LUI`   | rd(5)   | imm20(20) | unused(1) |

#### ALU Opcodes

| Opcode     | Format | Description                   | Latency |
|------------|--------|-------------------------------|---------|
| `ADD`      | R/I    | rd = rs1 + rs2/imm            | 2       |
| `SUB`      | R      | rd = rs1 - rs2                | 2       |
| `AND`      | R/I    | rd = rs1 & rs2/imm            | 2       |
| `OR`       | R/I    | rd = rs1 \| rs2/imm           | 2       |
| `XOR`      | R/I    | rd = rs1 ^ rs2/imm            | 2       |
| `SLT`      | R/I    | rd = (rs1 < rs2/imm) signed   | 2       |
| `SLTU`     | R/I    | rd = (rs1 < rs2/imm) unsigned | 2       |
| `SLL`      | R/I    | rd = rs1 << rs2/imm (barrel)  | 3       |
| `SRL`      | R/I    | rd = rs1 >> rs2/imm logical   | 3       |
| `SRA`      | R/I    | rd = rs1 >> rs2/imm arith     | 3       |
| `MUL`      | R      | rd = rs1 * rs2 (low 32-bit)   | 4       |
| `MULH`     | R      | rd = rs1 * rs2 (high 32-bit)  | 4       |
| `INV_SQRT` | R      | rd ≈ 1/sqrt(rs1)              | 5       |
| `LUI`      | U      | rd = imm20 << 12              | 2       |

- **Format `R/I`** means the operation has **two distinct opcodes** — a
  register form and an immediate form (e.g. `ADD` and `ADDI`) — since there is no
  `fmt` bit to select between them.

#### ALU Pseudo-instructions (compiler expands)

| Pseudo        | Real instruction      | Meaning              |
|---------------|-----------------------|----------------------|
| `NOP`         | opcode `000000`       | empty slot (dedicated NOP) |
| `MOV rd, rs`  | `ADD rd, r0, rs`      | register copy        |
| `NEG rd, rs`  | `SUB rd, r0, rs`      | negate               |
| `NOT rd, rs`  | `XOR rd, rs, -1`      | bitwise not          |
| `LI rd, imm`  | `ADDI rd, r0, imm14`  | load small immediate |

#### 32-bit constant generation (2 VLIW words)

```
LUI  rd, imm20        # rd = imm20 << 12
ADDI rd, rd, imm12    # rd = rd + sign_ext(imm12)
```

---

### Load/Store Slot (×1)

The Load/Store slot is a full **32-bit** instruction using the common header
(flat `opcode[31:26]`, `NOP = 000000`). It is the core's single memory port —
loads and stores to the on-chip data scratchpad and to the memory-mapped control
registers at the top of the data address space. Access width and sign/zero
extension are folded into the opcode (`LB LH LW LBU LHU` / `SB SH SW`); the
address is `rs_base + sign_ext(imm)` (byte-addressed, little-endian). Loads carry
a 14-bit offset (**±8 KB**); stores an `imm12` (**±2 KB**), since a store spends a
second source register on `rs_data`. Load latency is **2 cycles** at the
`BRAM_OUT_REG = 0` baseline (see §Memory Model); load-use RAW hazards are covered
by the scoreboard (§Scoreboard).

The complete encoding, addressing/alignment rules, the data-memory address map
(including the memory-mapped `LOOP_*` and `IRQ_*` registers), and memory-ordering
semantics are specified in **`LOAD_STORE.md`**, which is the authoritative
reference; they are not duplicated here to avoid drift.

---

### Control Slot (×1)

The Control slot is a full **32-bit** instruction using the common header
(flat `opcode[31:26]`, `NOP = 000000`). It owns PC sequencing, branches,
jumps, traps, and the single-context hardware loop, and also carries a
**lightweight integer ALU** (`ADD/SUB/ADDI`, `AND/OR/XOR/ANDI`, `SLT*` — no
multiply/shift, result at W+1) so pointer/loop-counter/condition arithmetic can
run in the otherwise-idle control slot instead of stealing an ALU slot. Its
complete encoding — `BEQ…BGEU`, `JAL`, `JALR`, `TRAP`, `ERET`, `LOOP`/`LOOPI`,
`LCLR`, `MOV`/`MOVI`, `CMOV`/`CMOVI`, and the integer ops — is specified in
**`CONTROL_UNIT.md`**, which is the authoritative reference; it is not duplicated
here to avoid drift.

Field conventions (see `CONTROL_UNIT.md` §3 for exact bit layouts):

- 7-bit global source addresses (`rs1`, `rs2`); 5-bit destination (`rd`).
- Signed `target` / `imm` fields sit at `[11:0]` and share one sign-extend
  circuit.
- `JAL` uses a 21-bit target (**±1 M VLIW words**); conditional branches a
  12-bit target (**±2048 VLIW words**); `JALR` a 12-bit offset.
- Branch shadow = `BRANCH_SHADOW` VLIW words, **hardware-squashed** on a taken
  redirect (CONTROL_UNIT.md §5.1): the compiler fills it for performance only,
  never for correctness, and emits no `NOP` padding. This is a **control**
  hazard, handled by the front-end flush and *not* by the data scoreboard (see
  §Scoreboard).

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
| IF    | Fetch     | Read 128-bit VLIW word from IMEM                  | BRAM registered output|
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
> This deepens the pipeline (and, for fetch, grows `BRANCH_SHADOW`) but changes
> **no binaries**: the scoreboard covers the data latency and the hardware
> squash covers the longer shadow. See §Memory Model. The stage list above is
> the `BRAM_OUT_REG = 0` baseline.

### Compiler latency model (performance)

These latencies are a **scheduling guide for the compiler**, not a correctness
contract: the hardware scoreboard (§Scoreboard) enforces correctness regardless.
The compiler spaces dependent instructions by the values below to **avoid
stalls**; if it doesn't, the pipeline stalls and the result is still correct,
only slower.

For every register `rN` written by instruction `I` issued at VLIW word W, the
earliest a dependent instruction can read `rN` **without stalling** is:

| Operation         | Earliest next read (VLIW words after writer) |
|-------------------|----------------------------------------------|
| ADD/SUB/logic     | W + 2                                        |
| LOAD              | W + 2                                        |
| Barrel shift      | W + 3                                        |
| MUL/MULH          | W + 4                                        |
| INV_SQRT          | W + 5                                        |
| JAL/JALR (rd)     | W + 1                                        |
| Branch (shadow)   | 3-word shadow, HW-squashed — fill for perf    |

> The branch row is a **control** hazard, not a data hazard, so the data
> scoreboard does not cover it. The branch shadow is **hardware-squashed** on a
> taken redirect (see `CONTROL_UNIT.md` §5.1), so branch NOPs are performance-
> only just like data-hazard NOPs; the compiler fills the shadow to avoid
> bubbles but never for correctness.

---

## Scoreboard (Hardware Interlock)

The processor uses a lightweight hardware **scoreboard** to guarantee
correctness. NOPs become a **performance** concern only (Hexagon-style): a
compiler scheduling mistake produces a stall, never silent corruption. This
also decouples the ISA from the pipeline — instruction latencies or pipeline
depth can change without breaking existing binaries.

### Why it is cheap here

The register file is **write-local / read-global** (see §Register File): each
slot writes only its own bank, any slot reads any bank. This asymmetry maps
directly onto the scoreboard:

- **WAW hazards and write-port conflicts are local to a bank** — only that
  bank's owning slot ever writes it.
- **Only RAW hazards cross banks** — because any slot can read any bank.

Issue is in-order and lock-step, so there is no CAM, no Tomasulo tags, no
renaming, and no reorder buffer.

### Per-bank state

For each bank `b`:

- **`busy_b[r]`** — one bit per register: a write to `r` is in flight. An
  optional refinement `ready_at_b[r]` records the cycle the value becomes
  readable, enabling early (bypassed) issue.
- **`wbres_b[0..LMAX]`** — a shift-register delay line reserving future
  write-back cycles. Results retire at different stages (ADD/LOAD @ EX2,
  shift @ EX3, MUL/MULH @ EX4, INV_SQRT @ EX5), so two ops issued by the
  **same** slot at different cycles can land on that bank's single write port on
  the **same** cycle. `wbres_b` counts reservations per future cycle and
  compares them against the bank's write-port count (1) to catch this
  structural collision.

`LMAX` is the deepest write-back latency (5, for `INV_SQRT`).

### Issue check (combinational, all-or-nothing)

The whole bundle (up to 4 ops) issues only if **no** op raises a hazard — a
single verdict for the entire packet.

- For each **source** `(bank, reg)` global read: **RAW stall** if
  `busy_bank[reg]` and the value is not yet readable/forwardable this cycle.
  This is the only wide network — up to ~8 read operands (2 per ALU, up to 2 for
  LS, 2 for CTRL) muxed across the banks into comparators. It mirrors the RF
  read crossbar (same fan-in).
- For each **destination** `(own bank b, reg)`: **WAW stall** if `busy_b[reg]`;
  **structural stall** if the reserved target cycle in `wbres_b` would exceed
  the write-port count. Both checks touch only the issuing slot's own bank.

### Stall and update

- **No hazard:** the packet issues; `busy` is set on destinations and entries
  are inserted into the `wbres` delay lines.
- **Hazard:** a single **global lock-step stall** freezes the front end (PC,
  fetch, issue registers) while the delay lines keep shifting — *freeze the
  front, drain the back*. In-flight writes retire, `busy` bits clear, and the
  packet re-tests on the next cycle.

**WAR is free:** in-order issue with operand read at a fixed stage (RR)
guarantees an earlier reader samples before a later writer commits.

### Scope: data hazards only

The scoreboard covers **data** hazards (RAW / WAW / write-port structural).
**Control** hazards — the branch shadow — are handled separately by the
front-end **squash**: on a taken branch / jump / trap the EX1 `flush` forces the
in-flight shadow slots to NOP and masks their write-enables (see
`CONTROL_UNIT.md` §5.1). Branch NOPs are therefore performance-only too, so the
"NOPs never affect correctness" property holds for both data and control
hazards. (A first FPGA bring-up MAY instead require the compiler to pad the
shadow with NOPs — an implementation shortcut, not an ISA change; see
`CONTROL_UNIT.md` §5.1.)

The global-stall mechanism also generalizes cleanly to **variable-latency**
accesses (the NoC port B, or a future cache): a miss asserts the same global
stall so that relative timings are preserved. The current on-chip DMEM is
fixed-latency (2 cycles), so loads are deterministic.

### Cost

A few hundred flip-flops (`busy` bits plus the per-bank delay lines) and a
muxed ~8-operand RAW check. No renaming, no ROB, no reservation stations — one
to two orders of magnitude cheaper than an out-of-order core of the same width.

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

### On-chip read latency is an `fmax` knob, not an ISA property

Each on-chip memory (IMEM, DMEM, register file) may be built **with or without
the hardened BRAM output register** (`BRAM_OUT_REG`). Enabling it adds **one
cycle of read latency** in exchange for higher `fmax`: on Xilinx the synthesizer
*absorbs* a datapath register placed after the memory into the BRAM's built-in
output register, so it costs no fabric flop and shortens the clock-to-out path.

This latency is a pure **timing / `fmax`** choice with **no binary impact**:

- **Data reads** (register file, loads): the scoreboard enforces correctness at
  whatever the latency is; a deeper read just shifts the advisory latency
  numbers (§Compiler latency model) uniformly.
- **Instruction fetch**: a deeper fetch grows the front end, hence grows
  `BRANCH_SHADOW`. Because the shadow is **hardware-squashed** and
  micro-architectural — not a delay slot (see `CONTROL_UNIT.md` §5.1) — the same
  binaries run unchanged; only cycle counts move. This is precisely why the
  shadow was kept squash-based rather than compiler-frozen.

### Future external memory (out of scope)

The scoreboard's global stall is already **variable-latency-ready** (see
§Scoreboard): a future variant could attach external DRAM behind a cache or a
DMA engine and assert the same stall on a miss, **without ISA changes**. That is
explicitly out of scope for the base core, which is cacheless and deterministic.

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

## Interrupts and Exceptions

Interrupts and synchronous traps share one mechanism, driven entirely by the
control slot's `TRAP` / `ERET` pair (encoding and shadow behaviour in
CONTROL_UNIT.md §3.6 and §5). The core adds **no dedicated context-save
hardware** — register state is memory, saved and restored in software like any
RISC-style processor.

### Entry

On a synchronous `TRAP` or an accepted external IRQ (enabled in `IRQ_MASK`),
hardware:

- saves the architectural resume PC to `IRQ_SAVED_PC` (the just-resolved
  next-PC — see §Entry point and saved PC below),
- records the cause in `IRQ_CAUSE` and sets the pending bit in `IRQ_STATUS`,
- jumps to `IRQ_VECTOR`,
- **squashes** the younger in-flight slots via the same EX1 `flush` used for
  branches (details in §Entry point and saved PC), so entry incurs no software
  NOP shadow.

All of these live in the memory-mapped control-register region at the top of
DMEM (map in `LOAD_STORE.md` §4.2); the
handler reads and writes them with ordinary `load`/`store` — there are no
architectural status registers.

### Entry point and saved PC

An external IRQ is asynchronous — it can land on the same cycle a control
transfer is resolving — so the hardware must capture the *right* resume PC. Two
rules make the interrupt precise:

1. **Injection at EX1.** The IRQ is taken at the branch-resolution stage,
   reusing the branch `flush`: the bundle in EX1 commits, the younger
   `BRANCH_SHADOW` slots (RR/ID/IF) are squashed (with their scoreboard
   reservations inhibited, see CONTROL_UNIT.md §5.1), and older bundles (EX2+)
   drain and commit. Injecting at the resolution stage avoids the race in which
   an unresolved branch *behind* the interrupt point would later reach EX1 and
   hijack the ISR's fetch stream. Older long-latency writes (MUL, INV_SQRT)
   drain under scoreboard control, so the handler's context spill reads settled
   values.

2. **Save the *architectural* next-PC, not the raw PC.** `IRQ_SAVED_PC` is the
   next-PC selector output for the EX1 bundle **with the trap override removed**
   (priorities 3–6 of CONTROL_UNIT.md §5) — i.e. whatever that bundle already
   decided:

   | EX1 bundle at the interrupt instant | `IRQ_SAVED_PC`                           |
   |-------------------------------------|------------------------------------------|
   | taken branch                        | branch target                            |
   | not-taken branch                    | `PC + 1`                                 |
   | `JAL` / `JALR`                      | jump target                              |
   | loop back-edge firing               | `loop_start` (count already decremented) |
   | loop skip (`count == 0`)            | skip target                              |
   | ordinary instruction                | `PC + 1`                                 |

   So a coincident **taken** branch still squashes its own shadow and its target
   becomes the resume PC; a **not-taken** branch resumes at `PC + 1`. The trap
   input only steers the actual fetch to `IRQ_VECTOR` and latches this
   already-computed value — there is no second PC-computation path.

A synchronous `TRAP` is the degenerate case of the same rule: its bundle is in
EX1 with nothing else resolving, so the saved value is `TRAP_PC + 1`
(CONTROL_UNIT.md §3.6). If a synchronous `TRAP` and an async IRQ land on the
same cycle, one is taken and the other stays pending in `IRQ_STATUS`.

### Context save / restore (software)

The handler spills whatever registers it clobbers to a stack in the **data
memory address space** using ordinary `store` instructions through the
Load/Store slot, and reloads them with `load` on the way out. This reuses the
existing 4 write / 8 read ports — there are no extra register-file ports and no
extra banks. The hardware-loop context is **not** auto-saved and has its own
memory-mapped save/restore path (see CONTROL_UNIT.md §4.8).

### Exit

`ERET` restores the PC from `IRQ_SAVED_PC` and clears the pending bit in
`IRQ_STATUS`; like `TRAP` it is hardware-squashed, so return incurs no shadow.
(`trap_code` allocation and exact bit layouts are defined in `ABI.md`.)

---

## Reset and Clock

| Property | Value                             |
|----------|-----------------------------------|
| Reset    | Synchronous, active high (`srst`) |
| Clock    | Single clock domain (`clk`)       |
| Target   | Xilinx/AMD FPGA, >200 MHz         |

---

## BRAM Resource Estimate

| Memory          | Width    | Depth                | BRAMs (36Kb) |
|-----------------|----------|----------------------|--------------|
| Instruction     | 128 bits | 2^`IMEM_DEPTH_LOG2`  | 1–2          |
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
| Jumps                     | `JAL` (link = next PC), `JALR` (`rs1 + imm12`)             |
| Type taxonomy             | R / I / U / B / J terminology                              |
| Hardwired zero register   | `r0` convention (`x0` in RV)                               |
| 32-bit constant idiom     | `LUI` + `ADDI` (20-bit + 12-bit immediates)                |
| Pseudo-instructions       | `NOP MOV NEG NOT LI J CALL RET BEQZ BNEZ`                  |
| Trap / return model       | Conceptually similar to `ECALL` / `MRET`                   |

### Differences from RISC-V

| Aspect                | This VLIW                                       | RISC-V                                |
|-----------------------|-------------------------------------------------|---------------------------------------|
| Word format           | 128-bit VLIW, 4 × 32-bit slots                  | 32-bit (or 16-bit `C`) scalar         |
| Bit-level encoding    | Custom (flat `opcode[31:26]` per slot)          | 7-bit major opcode in `[6:0]`         |
| Opcode width          | Flat 6-bit opcode per slot (no `fmt` bit)       | 7-bit op + `funct3` + `funct7`        |
| Register file         | 4 banks × 32 regs, 7-bit global read address    | Flat 32 regs, 5-bit address           |
| PC unit               | VLIW-word addressed                             | Byte addressed                        |
| Branch range          | ±2048 VLIW words (12-bit field)                 | ±4 KiB bytes                          |
| `JAL` range           | ±1 M VLIW words (21-bit field)                  | ±1 MiB bytes (20-bit field)           |
| Hazard handling       | Hardware scoreboard interlock; latencies advisory (perf only) | Implementation-defined interlocks |
| Hardware loops        | `LOOP` / `LOOPI`, single-context (see CONTROL_UNIT) | Not present (custom extensions only)  |
| `INV_SQRT`            | Native ALU op                                   | Not present                           |
| IRQ control           | Memory-mapped registers                         | CSR-based (`csrrw`, etc.)             |
| Missing               | `AUIPC FENCE ECALL EBREAK CSR* atomics F D C V` | Present in standard extensions        |

### One-line summary

> *Mnemonics and per-instruction semantics are RV32IM-flavored; everything
> below the assembler (encoding, packing, register file, PC unit, control
> flow extensions) is custom and FPGA-tuned.*
