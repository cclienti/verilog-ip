# VLIW Load/Store Unit Specification

## 1. Overview

The Load/Store (LS) Unit is the core's single memory port. It is responsible
for:

- Loads and stores to the on-chip **data scratchpad** (the `parmem3_2`
  prime-interleaved banked memory, side A — §10)
- Access to the **memory-mapped control registers** at the top of the data
  address space (hardware-loop context and IRQ control — see §4)
- Address generation (`rs_base + sign_ext(imm)`), sub-word steering, and
  sign/zero extension

It is a single-issue slot: at most one memory instruction executes per VLIW
word. There is **no** instruction cache, data cache, store buffer, or
load/store reordering — the data path is a directly-addressed scratchpad
(ARCHITECTURE.md §Memory Model), and the single in-order port makes memory
accesses program-ordered by construction (§6).

The core adds no dedicated hardware for interrupt context save: the handler
spills and fills registers through this slot with ordinary `store`/`load`
(ARCHITECTURE.md §Interrupts and Exceptions).

---

## 2. Register File Interface

The LS Unit is one of the four issue slots. It owns **banks 2 and 3** of the
register file — `LS-A` (`010`, lane-0 results) and `LS-B` (`011`, lane-1
results); destinations are 5-bit with the bank implicit from the lane.

| Port        | Count | Width                               | Purpose                                   |
|-------------|-------|-------------------------------------|-------------------------------------------|
| Read ports  | **4** | 7-bit addr (3-bit bank + 5-bit reg) | `rs_base`; `rs_index`/`rs_stride`/`rs_data`; `s0`; `s1` |
| Write ports | **2** | 5-bit addr, bank implicit from lane | `rd`/`d0` (LS-A); `d1` (LS-B)             |

Maximum simultaneous demand is set by the dual store (§10.2): `rs_base` +
`rs_stride` + `s0` + `s1` = **4 reads**; the dual load writes `d0` + `d1` =
**2 writes**. All sources are full 7-bit **global** addresses (any bank, any
slot's results); destinations are 5-bit.

| Instruction class          | Writes    | Reads                                  |
|----------------------------|-----------|----------------------------------------|
| Load (base+imm)            | `rd`      | `rs_base`                              |
| Indexed load               | `rd`      | `rs_base`, `rs_index`                  |
| Store                      | —         | `rs_base`, `rs_data`                   |
| `LD2` (dual load)          | `d0`,`d1` | `rs_base`, `rs_stride`                 |
| `ST2*` (dual store)        | —         | `rs_base`, `rs_stride`, `s0`, `s1`     |
| `STLD2`/`LDST2` (mixed)    | `d1`/`d0` | `rs_base`, `rs_stride`, `s0`/`s1`      |

### 2.1 Operand rails (encoding constraint)

Register fields are **not** placed per-instruction: every operand role is
pinned to a fixed bit range — a *rail* — shared by every instruction that
uses that role. Each register-file port therefore takes its address from
**one constant bit range**, with no per-opcode address multiplexer at the
head of the register-read path:

| Port          | Rail      | Roles carried                                        |
|---------------|-----------|------------------------------------------------------|
| read 1        | `[20:14]` | `rs_base` (every memory instruction)                 |
| read 2        | `[13:7]`  | `rs_index`, `rs_stride`, `rs_data` (classic store)   |
| read 3        | `[27:21]` | `s0` (dual-tier stores — dual tier only)             |
| read 4        | `[6:0]`   | `s1` (`ST2*`, `LDST2`)                               |
| write A addr  | `[25:21]` | `rd`, `d0`                                           |
| write B addr  | `[6:2]`   | `d1`                                                 |

Consequences:

- An instruction that does not use a rail leaves those bits as an
  immediate field, a subfield or reserved; the corresponding port still
  issues a (harmless) read, so **decode supplies a per-port valid bit** —
  the scoreboard must not see an unused rail as a dependency (§5.2).
- Rails 3 and 4 overlap immediate bits in the classic tier, so `s0`/`s1`
  exist only in the dual tier — matching the fact that only dual stores
  need four reads.
- The residual multiplexing is on the **data** side (lane-0 write data
  comes from rail 2 for a classic store, rail 3 for a dual store) and on
  the immediate reassembly path — both off the register-read address
  path, which is the timing-critical one (the RR→EX1 path,
  ARCHITECTURE.md §Pipeline).

Source-register hazards (a load/store whose sources are still in flight)
are covered by the hardware scoreboard (ARCHITECTURE.md §Scoreboard);
memory-address hazards are covered by the single in-order port (§6).

---

## 3. Instruction Set

Memory instructions are encoded in a **32-bit slot** with a **two-tier
opcode**, split by bit 31:

```
[31] = 0:   [31:26]    [25:0]           classic tier: flat 6-bit opcode
            opcode(6)  payload(26)      (values 000000–011111, 32 codes)

[31] = 1:   [31:28]    [27:0]           dual-access tier: 4-bit opcode
            opcode(4)  payload(28)      (values 1000–1111, 8 codes — §10.2)
```

The dual-access pair instructions (§10) need 28 payload bits (up to four
7-bit register sources), which a 6-bit opcode cannot leave room for; the
4-bit tier trades opcode space for payload exactly there. By Kraft's
budget the split costs the classic tier half its code points (32 remain
— ample: 14 used today).

**NOP** is classic-tier `opcode = 000000` (the canonical empty-slot
encoding; the assembler emits the all-zero word `0x00000000`).

### 3.1 Encoding reference card

Opcode assignment is **flat and sequential** within each tier (same
convention as the control slot). Access width and sign/zero behaviour are
folded into the opcode for every classic-tier instruction and for the dual
stores; only `LD2` carries them as payload subfields (§10.2). There is no
`funct` field. `NOP = 000000`.

**Field positions** — the single authoritative field map. Every operand
role is pinned to one bit range (its §2.1 rail) across all instructions
that use it; a field is absent, not moved, when an instruction does not
use that role:

| Field       | Bits                    | Width | Port / rail  | Used by                                  |
|-------------|-------------------------|-------|--------------|------------------------------------------|
| `opcode`    | `[31:26]`               | 6     | —            | classic tier (`[31] = 0`)                |
| `opcode`    | `[31:28]`               | 4     | —            | dual tier (`[31] = 1`)                   |
| `rs_base`   | `[20:14]`               | 7     | read 1       | **all** loads, stores, dual ops          |
| `rs_index`  | `[13:7]`                | 7     | read 2       | indexed loads (`LBX`…`LHUX`)             |
| `rs_data`   | `[13:7]`                | 7     | read 2       | classic stores (`SB`/`SH`/`SW`)          |
| `rs_stride` | `[13:7]`                | 7     | read 2       | all dual ops                             |
| `s0`        | `[27:21]`               | 7     | read 3       | `ST2*`, `STLD2` (lane-0 store data)      |
| `s1`        | `[6:0]`                 | 7     | read 4       | `ST2*`, `LDST2` (lane-1 store data)      |
| `rd`        | `[25:21]`               | 5     | write A addr | all classic loads                        |
| `d0`        | `[25:21]`               | 5     | write A addr | `LD2`, `LDST2` (lane-0 result → LS-A)    |
| `d1`        | `[6:2]`                 | 5     | write B addr | `LD2`, `STLD2` (lane-1 result → LS-B)    |
| `imm14`     | `[13:0]`                | 14    | —            | base+immediate loads                     |
| `imm12`     | `{[25:21], [6:0]}`      | 12    | —            | classic stores (split, §3.3)             |
| `w`         | `[27:26]`               | 2     | —            | `LD2` access width (00 B, 01 H, 10 W)    |
| `u`         | `[1]`                   | 1     | —            | `LD2` zero-extend (byte/half)            |

Notes on the map:

- Rails may **overlap** between roles that never coexist: `s0` `[27:21]`
  covers `d0` `[25:21]` (no instruction has both), and `s1` `[6:0]`
  covers `d1` `[6:2]`. Each port still reads a constant slice.
- A port whose rail carries something else in the current instruction
  (an immediate, a subfield, opcode bits) performs a harmless read or
  is write-disabled; decode provides the per-port valid bit (§2.1).
- All layouts (§3.2, §3.3, §3.6, and the four dual forms of §10.2)
  account for exactly 32 bits.

The field map and both opcode maps are held as tables in
`hw/vliw/tools/ls_isa.py`, which validates them (field widths, layout
coverage, rail consistency, opcode uniqueness, `NOP` = 0, encode/decode
round trip) and generates these markdown tables, the assembler
instruction reference and the RTL decode package:

```sh
tools/ls_isa.py --check | --md | --asm | --sv | --decode <word>
```

**Opcode map** — the single authoritative list of LS-slot opcodes:

| Opcode   | Mnemonic | Operands                | Description                    | Layout |
|----------|----------|-------------------------|--------------------------------|--------|
| `000000` | `NOP`    | —                       | no operation                   | §3     |
| `000001` | `LB`     | `rd, imm(rs_base)`      | load byte, sign-extended       | §3.2   |
| `000010` | `LH`     | `rd, imm(rs_base)`      | load half-word, sign-extended  | §3.2   |
| `000011` | `LW`     | `rd, imm(rs_base)`      | load word                      | §3.2   |
| `000100` | `LBU`    | `rd, imm(rs_base)`      | load byte, zero-extended       | §3.2   |
| `000101` | `LHU`    | `rd, imm(rs_base)`      | load half-word, zero-extended  | §3.2   |
| `000110` | `SB`     | `rs_data, imm(rs_base)` | store byte (low 8 bits)        | §3.3   |
| `000111` | `SH`     | `rs_data, imm(rs_base)` | store half-word (low 16 bits)  | §3.3   |
| `001000` | `SW`     | `rs_data, imm(rs_base)` | store word                     | §3.3   |
| `001001` | `LBX`    | `rd, (rs_base, rs_index)` | load byte indexed, sign-ext  | §3.6   |
| `001010` | `LHX`    | `rd, (rs_base, rs_index)` | load half indexed, sign-ext  | §3.6   |
| `001011` | `LWX`    | `rd, (rs_base, rs_index)` | load word indexed            | §3.6   |
| `001100` | `LBUX`   | `rd, (rs_base, rs_index)` | load byte indexed, zero-ext  | §3.6   |
| `001101` | `LHUX`   | `rd, (rs_base, rs_index)` | load half indexed, zero-ext  | §3.6   |

Reserved: classic-tier opcodes `001110`–`011111` (18 entries) and
dual-tier opcodes `1110`–`1111` (§10.2). Executing a reserved opcode
raises an **illegal-instruction trap** (same entry path as `TRAP`;
`trap_code` in `ABI.md`) — the assembler must never emit one.

**Notes:**
- `rs_base`, `rs_data` are **7-bit** global register addresses
  (`bank[2:0]` + `reg[4:0]`).
- `rd` is **5-bit** (bank implicit — the LS bank).
- The immediate is a **signed byte offset** (§3.5).
- Load offset is `imm14` (**±8 KB**); store offset is `imm12` (**±2 KB**) — the
  store spends 7 extra encoding bits on its second source register (§3.3).
- Register-**indexed** loads (`LBX`…`LHUX`, §3.6) replace the immediate with a
  second source register `rs_index` (`EA = rs_base + rs_index`). Indexed
  *stores* need a third read port, which the 4-read-port register file of §2
  now provides — they are a planned addition (§10.5).

### 3.2 Load format

| [31:26]   | [25:21] | [20:14]    | [13:0]    |
|-----------|---------|------------|-----------|
| opcode(6) | rd(5)   | rs_base(7) | imm14(14) |

- Effective address `EA = rs_base + sign_ext(imm14)` (byte address).
- `imm14` signed → offset range **±8191 bytes (±8 KB)**.
- `rd <- extend(mem[EA])`, sign- or zero-extended per opcode (§3.4).

### 3.3 Store format

| [31:26]   | [25:21]     | [20:14]    | [13:7]     | [6:0]      |
|-----------|-------------|------------|------------|------------|
| opcode(6) | imm[11:7]   | rs_base(7) | rs_data(7) | imm[6:0]   |

- Effective address `EA = rs_base + sign_ext(imm12)` (byte address), with
  `imm12 = {inst[25:21], inst[6:0]}`.
- `imm12` signed → offset range **±2047 bytes (±2 KB)**.
- `mem[EA] <- rs_data` over the addressed byte lane(s) only (§3.4).
- A store reads **two** registers (`rs_data` + `rs_base`, both 7-bit), which is
  why only 12 immediate bits remain versus the load's 14.
- The immediate is **split** so that `rs_base` and `rs_data` stay on rails 1
  and 2 (§2.1) — the same reason RISC-V splits its S-type immediate.
  Reassembly is fixed wiring; the split costs nothing at run time.

### 3.4 Access widths and extension

| Load | Store | Width         | Load result           |
|------|-------|---------------|-----------------------|
| `LB` | `SB`  | byte (8-bit)  | sign-extended to 32   |
| `LH` | `SH`  | half (16-bit) | sign-extended to 32   |
| `LW` | `SW`  | word (32-bit) | as-is                 |
| `LBU`| —     | byte (8-bit)  | zero-extended to 32   |
| `LHU`| —     | half (16-bit) | zero-extended to 32   |

- Stores write only the addressed byte lane(s) via the DPRAM byte write-enables;
  the rest of the 32-bit word is unchanged.
- Data memory is **little-endian**: byte 0 of a word is the least-significant
  byte.

### 3.5 Addressing and alignment

- The data address space is **byte-addressed**. The effective address selects a
  32-bit DPRAM word by `EA[DMEM_DEPTH_LOG2+1 : 2]` and a byte lane by `EA[1:0]`.
- **Natural alignment is required**: `LH/LHU/SH` need `EA[0] = 0`; `LW/SW` need
  `EA[1:0] = 00`; `LB/LBU/SB` have no alignment constraint. A misaligned access
  raises an **alignment trap** (synchronous, via the `TRAP` path; `trap_code` in
  `ABI.md`). The hardware does not split misaligned accesses.
- Addressing modes are **base + immediate** (§3.2/§3.3) and **base + index
  register** (indexed loads, §3.6). There is no PC-relative or auto-update
  (post-increment) addressing: pointer/stride arithmetic is done in the ALU or
  control slots — the control slot's integer ALU (CONTROL_UNIT.md §3.9) can bump
  a pointer in parallel without stealing an ALU slot. `imm(rs_base)` is the
  assembler syntax; `(rs_base)` is shorthand for offset 0.

### 3.6 Indexed load (register offset)

Register-indexed loads compute the effective address from **two registers**
instead of base + immediate:

| [31:26]   | [25:21] | [20:14]    | [13:7]      | [6:0]     |
|-----------|---------|------------|-------------|-----------|
| opcode(6) | rd(5)   | rs_base(7) | rs_index(7) | unused(7) |

- `EA = rs_base + rs_index` (byte address); the same width/extension (§3.4) and
  alignment (§3.5) rules apply. Available for all five load widths
  (`LBX LHX LWX LBUX LHUX`).
- Reads two registers (`rs_base`, `rs_index`) and writes `rd`, both on their
  §2.1 rails (`rs_index` shares rail 2 with `rs_stride`).
- **Stores have no indexed form**: an indexed store would read three registers
  (`rs_base` + `rs_index` + `rs_data`), exceeding the 2 read ports. Bump store
  pointers with the control-slot integer ALU (CONTROL_UNIT.md §3.9) instead.
- The `rs_index` / stride register is typically maintained by the control-slot
  integer ALU, keeping the address recurrence off the ALU slots.

---

## 4. Data Memory Address Space

### 4.1 Layout

The data address space is the on-chip **DPRAM scratchpad**:
`2^DMEM_DEPTH_LOG2` words of 32 bits (byte size `2^(DMEM_DEPTH_LOG2+2)`). Port A
is this LS slot; Port B is the NoC / network interface (ARCHITECTURE.md §Data
Memory and NoC Interface). The **top 9 words** are not backed by DPRAM: the LS
unit decodes them as memory-mapped control registers (§4.2).

```
byte 0                                         top of data space
| general scratchpad (DPRAM)              | MMIO regs (top 9 words) |
```

### 4.2 Memory-mapped control registers

The LS unit routes accesses whose word address falls in the top region to the
control registers below instead of the DPRAM. This is the single authoritative
map; the loop registers are used by CONTROL_UNIT.md §4.8 and the IRQ registers
by ARCHITECTURE.md §Interrupts and Exceptions.

| Offset from top | Name           | Width             | Access | Description                                  |
|-----------------|----------------|-------------------|--------|----------------------------------------------|
| -9              | `LOOP_ACTIVE`  | 1                 | RW     | Hardware-loop active flag                    |
| -8              | `LOOP_START`   | `IMEM_DEPTH_LOG2` | RW     | Hardware-loop start PC                        |
| -7              | `LOOP_END`     | `IMEM_DEPTH_LOG2` | RW     | Hardware-loop end PC                          |
| -6              | `LOOP_COUNT`   | 32                | RW     | Hardware-loop remaining iterations            |
| -5              | `IRQ_SAVED_PC` | 32                | RO     | Resume PC saved on trap / IRQ entry           |
| -4              | `IRQ_VECTOR`   | 32                | RW     | VLIW-word address of the ISR                  |
| -3              | `IRQ_MASK`     | `NB_IRQ`          | RW     | Per-line IRQ enable bits                       |
| -2              | `IRQ_CAUSE`    | `NB_IRQ`          | RO     | Cause code written by hardware                 |
| -1              | `IRQ_STATUS`   | `NB_IRQ`          | RO     | Pending IRQ bits, cleared on `ERET`            |

- The `LOOP_*` registers access the **committed** loop state
  (CONTROL_UNIT.md §4.4), so a handler always reads values consistent with
  `IRQ_SAVED_PC`. All control registers reset to `0`; `IRQ_MASK = 0` keeps
  every line masked until software has programmed `IRQ_VECTOR`
  (ARCHITECTURE.md §Reset and Clock).
- MMIO registers are accessed with **word** operations (`LW`/`SW`) and must be
  word-aligned; a sub-word or misaligned MMIO access raises an alignment trap.
- Writes to **RO** registers have no effect; reads of narrow registers
  zero-extend to 32 bits.
- Offsets are word offsets from the top; e.g. `-1` is byte address
  `2^(DMEM_DEPTH_LOG2+2) - 4`.

### 4.3 Endianness

Little-endian throughout (byte 0 = least-significant byte), matching the
scalar-ISA convention borrowed from RV32IM.

---

## 5. Pipeline and Latency

### 5.1 Latency contract

| Instruction | Result available (VLIW words after issue) | Notes                         |
|-------------|-------------------------------------------|-------------------------------|
| `LB`…`LHU`  | `rd` at **W + 2**                         | `BRAM_OUT_REG = 0` baseline   |
| `SB`…`SW`   | — (no register result)                    | commits in program order (§6) |

Address calculation happens in EX1; the registered DPRAM read returns data at
EX2, so a load result retires at `W + 2` — the same distance as an ALU `ADD`
(ARCHITECTURE.md §Compiler latency model). These latencies are a **scheduling
guide**, not a correctness contract: the scoreboard enforces correctness
regardless (§5.2).

### 5.2 Scoreboard interaction (load-use)

- A load reserves `rd`'s `busy` / `wbres` entry at issue and clears it at its
  scheduled write-back (EX2). A dependent instruction that reads `rd` **before**
  `W + 2` is **stalled** by the scoreboard, never fed stale data — a
  mis-scheduled load-use costs a cycle, never correctness.
- A load/store whose `rs_base` (or a store's `rs_data`) is still in flight
  stalls at issue until the source is ready — ordinary RAW handling.
- A store produces no register result, so it makes no `rd` reservation.

### 5.3 BRAM output register (`fmax`)

The DPRAM may enable the hardened **output register** (`BRAM_OUT_REG`,
ARCHITECTURE.md §Memory Model), adding **one** read-latency cycle for higher
`fmax` (the synthesizer absorbs a datapath register into the BRAM macro). This
shifts the load result to `W + 3`; the scoreboard covers the actual latency
whatever it is, so no binary changes — only cycle counts move.

---

## 6. Memory Ordering and the NoC Port

Because there is exactly **one** LS slot and issue is in-order, all Port-A memory
accesses execute in **program order**. Consequences:

- **A load observes every prior store from this core** to the same address, with
  no store buffer and no store-to-load forwarding network: the earlier store's
  DPRAM write precedes the later load's read by construction. Memory RAW/WAW/WAR
  ordering is therefore free — the register scoreboard does **not** need to track
  addresses.
- **Port B (NoC / NI) is not coherent with Port A.** Port B is `parmem3_2`'s
  side B (§10.1) — a single linear-addressed port on its own clock; the two
  sides carry no arbitration and no snooping (ARCHITECTURE.md §Data Memory and
  NoC Interface); ordering between core accesses and NoC accesses is the
  responsibility of the software / DMA protocol (typically scratchpad
  double-buffering — ARCHITECTURE.md §Memory Model). A core load has no way to
  observe an in-flight NoC write except through that protocol.
- There are no fences or atomics; none are needed for a single-core, single-port,
  in-order scratchpad. (A future multi-master or cached variant would add them —
  out of scope, ARCHITECTURE.md §Memory Model.)

---

## 7. Pseudo-instructions

| Pseudo              | Expansion                          | Notes                              |
|---------------------|------------------------------------|------------------------------------|
| `LW rd, (rs)`       | `LW rd, 0(rs)`                     | zero offset                        |
| `SW rs_data, (rs)`  | `SW rs_data, 0(rs)`               | zero offset                        |
| `PUSH rs`           | `ADDI sp, sp, -4` ; `SW rs, 0(sp)` | spans ALU + LS slots (see `ABI.md`)|
| `POP rd`            | `LW rd, 0(sp)` ; `ADDI sp, sp, 4`  | spans LS + ALU slots               |

`PUSH`/`POP` are multi-slot idioms, not single instructions; the `sp`/`ra`
register conventions are defined in `ABI.md`. Absolute addressing of a symbol
uses the two-word `LUI`+`ADDI` constant-generation idiom (`ALU.md` §6) to form
the base, then a `0` offset.

---

## 8. Parameters

| Parameter          | Default | Description                                                     |
|--------------------|---------|-----------------------------------------------------------------|
| `DMEM_DEPTH_LOG2`  | 11      | Data memory depth: `2^DMEM_DEPTH_LOG2` 32-bit words (1K–16K)     |
| `BRAM_OUT_REG`     | TBD     | DPRAM output register; `1` adds one load-latency cycle (§5.3)    |

`NB_IRQ` (ARCHITECTURE.md) sizes the `IRQ_*` MMIO registers in §4.2.

---

## 9. Examples

**Streaming inner-loop body** (one load + one MAC per VLIW word; the LS slot runs
in lock-step with the ALU slots):

```asm
    LW    r10, 0(r20)      ; load next element   (result at W+2)
    MUL   r11, r10, r12    ; ALU slot
    ADD   r13, r13, r11    ; ALU slot
    ADDI  r20, r20, 4      ; ALU slot: bump byte pointer
```

The scoreboard stalls the `MUL` if it is scheduled within 2 words of the `LW`;
the compiler spaces them (here by pipelining across iterations of the hardware
loop) to avoid the stall.

**Reading a control register** (poll the hardware-loop iteration count):

```asm
    LW    r5, LOOP_COUNT    ; MMIO word at offset -6 from top of data space
```

**Register spill in an interrupt handler** (software context save — no dedicated
hardware, ARCHITECTURE.md §Interrupts and Exceptions):

```asm
    ADDI  sp, sp, -8
    SW    r1, 0(sp)
    SW    r2, 4(sp)
    ; ... handler body ...
    LW    r2, 4(sp)
    LW    r1, 0(sp)
    ADDI  sp, sp, 8
    ERET
```

---

## 10. Data Memory Implementation: `parmem3_2` and the Dual Access Pair

### 10.1 Memory selection (normative)

The data scratchpad is implemented by **`parmem3_2`**
(`hw/lib/parmem/parmem3_2`): three prime-interleaved banks on
true-dual-port dual-clock BRAM (READ_FIRST), CRT-addressed with **no
divider** (`bank = EA mod 3`, `index = EA` low bits; bijective since
`gcd(3, 2^DEPTH) = 1`). Side A is this LS unit; **side B is the NoC/NI
port of §6** — a single linear-addressed requester on its own clock
(the dual-clock banks are the clock-domain crossing), preserving the §6
ordering model unchanged.

Why 3 banks (measured — `hw/lib/parmem/doc/RESULTS.md`):

- Meets the 200 MHz target even on xc7z020-1 at 295 LUTs / 3 RAMB36;
  fastest cell of the parmem family on every measured fabric.
- **Decimal-friendly conflict set**: since `10 ≡ 1 (mod 3)`, every
  decimal-round stride (`10^k` and `d·10^k`: 10, 100, 1000, 640,
  800, 1920 …) is conflict-free; a stride conflicts only when its
  digit sum is divisible by 3. Power-of-2 strides never conflict.
- Capacity is `3 × 2^DEPTH` words (the §8 `DMEM_DEPTH_LOG2` counts
  words per bank); `BRAM_OUT_REG` maps to `OUTREGA/OUTREGB` (§5.3),
  and the optional `ADRREG` address-phase register adds one cycle
  while keeping `conflict`/`oob` combinational at issue.

### 10.2 Dual strided access pair — encoding

The LS slot's dual-op class accesses a **pair from one instruction**:
lane `i` (`i = 0, 1`) at `EA_i = addr + i·stride` (`stride` signed, in
words). Lane 0's result writes the LS-A bank, lane 1's the LS-B bank
(one write port each — §2 grows to the 5-bank, 10-read-port register
file). All dual ops live in the **dual-access tier** (`[31] = 1`,
4-bit opcode, 28-bit payload — §3); the per-lane read/write mix
(§10.3) is implied by the opcode, not a field.

**Dual-tier opcode map:**

| Opcode | Mnemonic | Operands                          | Lanes (0, 1)   |
|--------|----------|-----------------------------------|----------------|
| `1000` | `LD2`    | `d0, d1, (rs_base, rs_stride)`    | read, read     |
| `1001` | `ST2`    | `(rs_base, rs_stride), s0, s1`    | write, write (word) |
| `1010` | `ST2H`   | `(rs_base, rs_stride), s0, s1`    | write, write (half) |
| `1011` | `ST2B`   | `(rs_base, rs_stride), s0, s1`    | write, write (byte) |
| `1100` | `STLD2`  | `d1, (rs_base, rs_stride), s0`    | write, read (word) |
| `1101` | `LDST2`  | `d0, (rs_base, rs_stride), s1`    | read, write (word) |
| `1110` | —        | reserved                          |                |
| `1111` | —        | reserved                          |                |

**Payload layouts** — every field sits on its §2.1 rail, shared with the
classic tier (`rs_base` on rail 1, the second address operand on rail 2,
`rd`/`d0` on the write-A rail), so no register-file port needs an
address multiplexer:

```
common:  [20:14] rs_base(7)  [13:7] rs_stride(7)          (rails 1, 2)

LD2:     [27:26] w(2)   [25:21] d0(5)   [6:2] d1(5)  [1] u  [0] rsvd
ST2*:    [27:21] s0(7)                  [6:0] s1(7)         (width in opcode)
STLD2:   [27:21] s0(7)                  [6:2] d1(5)  [1:0] rsvd
LDST2:   [27:26] rsvd   [25:21] d0(5)   [6:0] s1(7)
```

- `LD2` folds its width and extension into subfields: `w` = 00 byte,
  01 half, 10 word; `u` = zero-extend (byte/half only). One opcode
  covers `LD2B/LD2BU/LD2H/LD2HU/LD2W` (assembler mnemonics).
- `ST2*` has a full 28-bit payload (four 7-bit sources would not leave
  width bits), so the store width is folded into the opcode —
  consistent with the classic tier's `SB/SH/SW` convention. Sources
  are **full 7-bit global addresses** (any bank — the 10-read-port
  register file removes the lane-implicit restriction).
- The mixed forms (`STLD2`/`LDST2`) are **word-only** in this
  revision (their use cases — streaming copy, exchange pipelines —
  are word-based); their reserved bits are the landing zone for
  sub-word variants if ever needed.
- Load destinations are 5-bit, bank-implicit per lane (`d0` → LS-A,
  `d1` → LS-B). Addresses are **word** EAs (the pair is word-aligned
  by construction; sub-word dual accesses select within the word —
  §3.4 extension rules apply per lane).

### 10.3 Per-lane read/write mix (normative)

`wen` is **per lane**: each enabled lane independently reads or writes.
All four combinations are legal — dual load, dual store, and both
mixed forms (e.g. lane 0 writes while lane 1 reads).

- Because enabled lanes own distinct banks whenever
  `stride ≢ 0 (mod 3)`, a mixed pair costs the same single cycle as a
  uniform pair.
- READ_FIRST semantics make a **writing lane return the pre-write cell
  content** on its read-data lane — exchange (`XCHW`-class) semantics
  come free; a single-lane exchange is the degenerate case.
- **Single-slot streaming copy**: lane 0 writes `dst[i]` while lane 1
  reads `src[i+1]`'s stream — one word moved per cycle from one LS
  slot. The two lanes share one `addr`/`stride` pair, so `src` and
  `dst` must sit at a constant layout distance `D` with
  `D ≢ 0 (mod 3)` — an allocator placement rule, same family as the
  padding hints of §10.4.
- Register budget: a mixed pair reads `rs_base`, `rs_stride`, and one
  store-data source (3 reads) and makes one load-result write — within
  the dual-store worst case.

### 10.4 Conflict auto-serialization (normative)

`conflict` (`stride ≡ 0 (mod 3)` with both lanes enabled) is a pure
function of the stride residue and the lane mask, available **in the
issue cycle** (by construction, even with `ADRREG`). It is not a trap
and not an illegal encoding — the hardware **serializes**:

1. The LS unit splits the pair into two single-lane accesses (lane 0
   first, then lane 1 — a one-bit sequencer re-presents the access
   with the complementary lane mask).
2. The pipeline inserts **one dynamic NOP**: IF/ID freeze for one
   cycle, bubble downstream. The conflicting bundle occupies the
   memory stage for two cycles; total cost is **+1 cycle**, nothing
   else.
3. Lane 1's load result writes back one cycle after lane 0's, into
   the write slot freed by the bubble — no write-port arbitration.
   Latency guide: conflicting dual load returns `d0` at `W + 2` and
   `d1` at `W + 3` (baseline §5.1 numbering); the scoreboard covers
   the actual latency as always (§5.2).
4. **Split atomicity**: once the first half has executed, the bundle
   is committed — the second half is non-interruptible. IRQ
   acceptance is delayed by at most one cycle; a flush/squash cannot
   separate the halves (consistent with the EX1 commit point,
   CONTROL_UNIT.md §5). This rule is what makes a conflicting dual
   **store** safe.

Consequently, strides that are multiples of 3 are **legal but slow**.
The compiler's layout rules (pad pitches whose digit sum is divisible
by 3) are **performance hints, not correctness requirements**. `oob`
is unchanged: per-lane trap, offending lane suppressed, and the trap
takes precedence over `conflict` when both assert.

### 10.5 Open items

- Classic-tier additions enabled by the 10-read-port register file:
  `XCHW` (single-lane exchange) and the indexed stores `SWX/SHX/SBX`
  (a third read port makes them encodable) — opcode values to be
  assigned in the §3.1 map.
- Sub-word store support on the word-wide banks (byte write enables in
  `dpmemrf`, as for the current DPRAM path of §3.4).
- Per-lane `wen` in the `parmem3_2` RTL (the component currently
  implements the shared-`wen` contract).
