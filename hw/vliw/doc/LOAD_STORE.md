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
**2 writes**. No instruction does both: reads 3/4 carry store data and
write B carries a load result, so the two never coexist. All sources are full 7-bit **global** addresses (any bank, any
slot's results); destinations are 5-bit.

| Instruction class          | Writes    | Reads                                  |
|----------------------------|-----------|----------------------------------------|
| Load (base+imm)            | `rd`      | `rs_base`                              |
| Indexed load               | `rd`      | `rs_base`, `rs_index`                  |
| Store                      | —         | `rs_base`, `rs_data`                   |
| Indexed store              | —         | `rs_base`, `rs_index`, `rs_data`       |
| `XCHW` (exchange)          | `rd`      | `rs_base`, `rs_data`                   |
| `LD2*` (dual load)         | `d0`,`d1` | `rs_base`, `rs_stride`                 |
| `ST2*` (dual store)        | —         | `rs_base`, `rs_stride`, `s0`, `s1`     |

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
| read 3        | `[27:21]` | `s0` (dual stores — dual tier only)                  |
| read 4        | `[6:0]`   | `s1` (dual stores), `rs_datax` (indexed stores)      |
| write A addr  | `[25:21]` | `rd`, `d0`                                           |
| write B addr  | `[6:2]`   | `d1`                                                 |

Consequences:

- An instruction that does not use a rail leaves those bits as an
  immediate field or reserved; the corresponding port still issues a read,
  which is simply discarded — with no interlock to mislead, an unused rail
  needs no valid bit at all.
- Rail 3 overlaps opcode bits in the classic tier, so `s0` exists only in
  the dual tier — which is exactly the set of instructions needing four
  reads (the dual stores). Rail 4 is reachable from both tiers.
- An indexed **store** reads three registers, and puts its data on rail 4
  (`rs_datax`) rather than rail 2: that keeps `rs_index` on rail 2 with
  the indexed loads, so the effective-address adder's second operand is
  always read port 2 and the **address** path needs no multiplexer. The
  cost lands on the store-data multiplexer instead — the shorter path.
- The residual multiplexing is on the **data** side (lane-0 write data
  comes from rail 2 for a classic store, rail 3 for a dual store) and on
  the immediate reassembly path — both off the register-read address
  path, which is the timing-critical one (the RR→EX1 path,
  ARCHITECTURE.md §Pipeline).

Source-register hazards are the **compiler's responsibility**: the core
ships without an interlock, so a source read before its producer's latency
has elapsed returns a stale value silently (SCOREBOARD.md, status note).
Memory-address hazards, by contrast, are covered by construction — a single
in-order port (§6).

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

The **dual stores** (§10.2) read four 7-bit registers — `rs_base`,
`rs_stride`, `s0`, `s1` = 28 payload bits — which a 6-bit opcode cannot
leave room for; the 4-bit tier trades opcode space for payload exactly
there, and nothing else needs it. Dual *loads* read two registers and
write two 5-bit destinations (24 bits), so they stay in the classic
tier. By Kraft's budget the split costs the classic tier half its code
points (32 remain — 23 used today).

**NOP** is classic-tier `opcode = 000000` (the canonical empty-slot
encoding; the assembler emits the all-zero word `0x00000000`).

### 3.1 Encoding reference card

Opcode assignment is **flat and sequential** within each tier (same
convention as the control slot). Access width and sign/zero behaviour are
folded into the opcode for **every** instruction — there are no width or
`funct` fields anywhere in the slot. `NOP = 000000`.

**Field positions** — the single authoritative field map. Every operand
role is pinned to one bit range (its §2.1 rail) across all instructions
that use it; a field is absent, not moved, when an instruction does not
use that role:

| Field       | Bits                    | Width | Port / rail  | Used by                                  |
|-------------|-------------------------|-------|--------------|------------------------------------------|
| `opcode`    | `[31:26]`               | 6     | —            | classic tier (`[31] = 0`)                |
| `opcode`    | `[31:28]`               | 4     | —            | dual tier (`[31] = 1`)                   |
| `rs_base`   | `[20:14]`               | 7     | read 1       | **all** loads, stores, dual ops          |
| `rs_index`  | `[13:7]`                | 7     | read 2       | indexed loads and stores (`L*X`, `S*X`)  |
| `rs_data`   | `[13:7]`                | 7     | read 2       | classic stores (`SB`/`SH`/`SW`)          |
| `rs_stride` | `[13:7]`                | 7     | read 2       | dual loads and stores                    |
| `s0`        | `[27:21]`               | 7     | read 3       | `ST2*` (lane-0 store data)               |
| `s1`        | `[6:0]`                 | 7     | read 4       | `ST2*` (lane-1 store data)               |
| `rs_datax`  | `[6:0]`                 | 7     | read 4       | indexed stores (`SWX`/`SHX`/`SBX`)       |
| `rd`        | `[25:21]`               | 5     | write A addr | all classic loads                        |
| `d0`        | `[25:21]`               | 5     | write A addr | `LD2*` (lane-0 result → LS-A)            |
| `d1`        | `[6:2]`                 | 5     | write B addr | `LD2*` (lane-1 result → LS-B)            |
| `imm14`     | `[13:0]`                | 14    | —            | base+immediate loads                     |
| `imm12`     | `{[25:21], [6:0]}`      | 12    | —            | classic stores (split, §3.3)             |
| `imm7`      | `[6:0]`                 | 7     | —            | `XCHW` (§3.8)                            |

Notes on the map:

- Rails may **overlap** between roles that never coexist: `s0` `[27:21]`
  covers `d0` `[25:21]` (no instruction has both), and `s1` `[6:0]`
  covers `d1` `[6:2]`. Each port still reads a constant slice.
- A port whose rail carries something else in the current instruction
  (an immediate, reserved bits, opcode bits) performs a harmless read or
  is write-disabled; decode provides the per-port valid bit (§2.1).
- All layouts (§3.2, §3.3, §3.6, §3.7, §3.8 and the two pair forms of
  §10.2) account for exactly 32 bits.

The field map and both opcode maps are held as tables in
`hw/vliw/tools/ls_isa.py`, which validates them (field widths, layout
coverage, rail consistency, opcode uniqueness, `NOP` = 0, encode/decode
round trip) and generates these markdown tables, the assembler
instruction reference and the RTL decode package. `--check-doc` reads
this file back and compares its field map, opcode maps and reserved
ranges against those tables, so the two cannot drift apart:

```sh
tools/ls_isa.py --check | --check-doc | --md | --asm | --sv | --decode <word>
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
| `001110` | `LD2B`   | `d0, d1, (rs_base, rs_stride)` | dual load byte, sign-ext | §10.2 |
| `001111` | `LD2BU`  | `d0, d1, (rs_base, rs_stride)` | dual load byte, zero-ext | §10.2 |
| `010000` | `LD2H`   | `d0, d1, (rs_base, rs_stride)` | dual load half, sign-ext | §10.2 |
| `010001` | `LD2HU`  | `d0, d1, (rs_base, rs_stride)` | dual load half, zero-ext | §10.2 |
| `010010` | `LD2W`   | `d0, d1, (rs_base, rs_stride)` | dual load word           | §10.2 |
| `010011` | `SWX`    | `rs_data, (rs_base, rs_index)` | store word indexed       | §3.7   |
| `010100` | `SHX`    | `rs_data, (rs_base, rs_index)` | store half indexed       | §3.7   |
| `010101` | `SBX`    | `rs_data, (rs_base, rs_index)` | store byte indexed       | §3.7   |
| `010110` | `XCHW`   | `rd, rs_data, imm(rs_base)`    | exchange word            | §3.8   |

Reserved: classic-tier opcodes `010111`–`011111` (9 entries) and
dual-tier opcodes `1011`–`1111` (5 entries, §10.2). Executing a reserved
opcode raises an **illegal-instruction trap** (same entry path as `TRAP`;
`trap_code` in `ABI.md`) — the assembler must never emit one.

**Notes:**
- `rs_base`, `rs_data` are **7-bit** global register addresses
  (`bank[2:0]` + `reg[4:0]`).
- `rd`, `d0` and `d1` are **5-bit** with the bank implicit: `rd`/`d0`
  write LS-A, `d1` writes LS-B (§2).
- The immediate is a **signed byte offset** (§3.5).
- Load offset is `imm14` (**±8 KB**); store offset is `imm12` (**±2 KB**) — the
  store spends 7 extra encoding bits on its second source register (§3.3);
  `XCHW`'s offset is `imm7` (**±63 B**, §3.8).
- Register-**indexed** loads (`LBX`…`LHUX`, §3.6) and stores
  (`SWX`/`SHX`/`SBX`, §3.7) replace the immediate with a second source
  register `rs_index` (`EA = rs_base + rs_index`); the indexed store reads
  three registers, which the 4-read-port register file of §2 provides.

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

- Stores write only the addressed byte lane(s) via the bank byte write-enables;
  the rest of the 32-bit word is unchanged.
- Data memory is **little-endian**: byte 0 of a word is the least-significant
  byte.

### 3.5 Addressing and alignment

- The data address space is **byte-addressed**. The effective address selects a
  32-bit memory word by `EA[DMEM_DEPTH_LOG2+3 : 2]` and a byte lane by
  `EA[1:0]`; the word address is `DMEM_DEPTH_LOG2 + 2` bits wide because the
  scratchpad holds `3 × 2^DMEM_DEPTH_LOG2` words (§10.1).
- **Natural alignment is required**, by access width and independently of the
  addressing mode: half-word accesses (`LH/LHU/SH/SHX/LD2H/LD2HU/ST2H`) need
  `EA[0] = 0`; word accesses (`LW/SW/SWX/LD2W/ST2/XCHW`) need `EA[1:0] = 00`;
  byte accesses have no constraint. Each lane of a pair is checked
  independently. A misaligned access raises an **alignment trap**
  (synchronous, via the `TRAP` path; `trap_code` in `ABI.md`). The hardware
  does not split misaligned accesses.
- Addressing modes are **base + immediate** (§3.2/§3.3/§3.8), **base + index
  register** (§3.6/§3.7) and **base + lane × stride register** (the pairs of
  §10.2). There is no PC-relative or auto-update
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
- The `rs_index` / stride register is typically maintained by the control-slot
  integer ALU, keeping the address recurrence off the ALU slots.

### 3.7 Indexed store (register offset)

The store counterpart of §3.6, reading **three** registers — possible
because the register file provides four read ports (§2):

| [31:26]   | [25:21]   | [20:14]    | [13:7]      | [6:0]        |
|-----------|-----------|------------|-------------|--------------|
| opcode(6) | unused(5) | rs_base(7) | rs_index(7) | rs_datax(7)  |

- `EA = rs_base + rs_index` (byte address); `mem[EA] <- rs_data` over the
  addressed byte lane(s) only, with the same width (§3.4) and alignment
  (§3.5) rules as the immediate-offset stores. Available at all three
  store widths (`SWX SHX SBX`).
- The store data is read on **port 4** (`rs_datax`, rail 4) rather than
  port 2. This keeps `rs_index` on rail 2 alongside `rs_stride` and the
  indexed loads' index, so the effective-address adder's second operand
  is always port 2 — no multiplexer on the address path (§2.1). The
  assembler syntax still writes the operand as `rs_data`.
- Typical uses: scatter (`a[idx[k]] = v`), table and frame writes at a
  computed offset, and symmetry with the indexed loads — an asymmetric
  set costs the compiler an extra `ADD` for no reason.

### 3.8 Exchange (`XCHW`)

Writes a register to memory and returns the **pre-write** word:

| [31:26]   | [25:21] | [20:14]    | [13:7]     | [6:0]     |
|-----------|---------|------------|------------|-----------|
| opcode(6) | rd(5)   | rs_base(7) | rs_data(7) | imm7(7)   |

- `EA = rs_base + sign_ext(imm7)` (byte address, word-aligned);
  `rd <- mem32[EA]` **and** `mem32[EA] <- rs_data` in one access.
- The immediate is 7 bits (**±63 bytes**) because `rd` occupies the
  field an immediate-offset store uses for `imm[11:7]` (§3.3).
- **Word only**: there are no `XCHB`/`XCHH` forms in this revision.
- No memory support is required: the banks are READ_FIRST, so a write
  already presents the pre-write cell content on the read port (§10.3)
  — `XCHW` is a store that names a destination for that value.
- Reads two registers and writes one (§2), all on their §2.1 rails.
  The result retires like a load, at `W + 2` (§5.1).
- Typical uses: the circular **delay-line update** — write the newest
  sample into the cell holding the oldest and receive the evicted
  sample in `rd`, one access per tap step; flag or semaphore swap with
  the NoC interface (post a state and learn the previous one — §6);
  free-list pop.

---

## 4. Data Memory Address Space

### 4.1 Layout

The data address space is the on-chip **`parmem3_2` scratchpad** (§10.1):
three banks of `2^DMEM_DEPTH_LOG2` words, so
**`3 × 2^DMEM_DEPTH_LOG2` words** of 32 bits (byte size
`3 × 2^(DMEM_DEPTH_LOG2+2)`). Side A is this LS slot; side B is the NoC /
network interface (§6, ARCHITECTURE.md §Data Memory and NoC Interface).
The **top 9 words** are not backed by memory: the LS unit decodes them as
memory-mapped control registers (§4.2).

```
byte 0                                              top of data space
| general scratchpad (3 x 2^DMEM_DEPTH_LOG2 - 9)  | MMIO regs (9 words) |
```

> Because the word address is `DMEM_DEPTH_LOG2 + 2` bits wide while only
> `3 × 2^DMEM_DEPTH_LOG2` words are backed, a further `2^DMEM_DEPTH_LOG2`
> words at the top of the *encodable* range are unbacked by construction
> (that region is what `parmem3_2` reports through `oob`). Relocating the
> MMIO block there would return those 9 words to the scratchpad and make
> the decode a plain range check — noted as an option in §10.5, not the
> current map.

### 4.2 Memory-mapped control registers

The LS unit routes accesses whose word address falls in the top region to the
control registers below instead of the scratchpad banks. This is the single authoritative
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
- Offsets are word offsets from the top of the backed region; e.g. `-1` is
  byte address `3 × 2^(DMEM_DEPTH_LOG2+2) - 4`.

### 4.3 Endianness

Little-endian throughout (byte 0 = least-significant byte), matching the
scalar-ISA convention borrowed from RV32IM.

---

## 5. Pipeline and Latency

### 5.1 Latency contract

| Instruction | Result available (VLIW words after issue) | Notes                         |
|-------------|-------------------------------------------|-------------------------------|
| `LB`…`LHU`, `L*X` | `rd` at **W + 2**                   | `BRAM_OUT_REG = 0` baseline   |
| `SB`…`SW`, `S*X`  | — (no register result)              | commits in program order (§6) |
| `XCHW`      | `rd` at **W + 2**                         | pre-write word (§3.8)         |
| `LD2*`      | `d0` **and** `d1` at **W + 2**            | conflicting pair: +1 cycle, same latency (§10.4) |
| `ST2*`      | — (no register result)                    | conflicting pair: +1 cycle (§10.4) |

Address calculation happens in EX1; the registered bank read returns data at
EX2, so a load result retires at `W + 2` — the same distance as an ALU `ADD`
(ARCHITECTURE.md §Compiler latency model). With no interlock these latencies
are **architectural**, not advisory: they are part of the contract the
compiler must satisfy (§5.2).

### 5.2 Compiler obligations (load-use)

There is no interlock: the rules below are contractual, and violating one
produces a wrong result, not a stall.

- A consumer of a load must issue at least `1 + ADRREG + OUTREGA` bundles
  after it (`W + 2` in the baseline). Scheduled earlier, it reads whatever
  the destination register held before — silently.
- The same applies to every source of a load or store (`rs_base`,
  `rs_data`, `rs_index`, `rs_stride`, `s0`, `s1`): each must have settled
  before the access issues.
- A register may be rewritten as soon as its previous value has been
  consumed — the register file may be used as a dataflow buffer, a value
  occupying a name for a single cycle (SCOREBOARD.md §7.6). The write
  ordering to one register is the compiler's to keep: with non-uniform
  latencies (EX2…EX5) a shorter operation issued later can land *before*
  a longer one issued earlier.
- A store produces no register result; `XCHW` produces one exactly like a
  load.
- A dual load writes `d0` in LS-A and `d1` in LS-B **at the same latency**,
  conflicting or not (§10.4) — a conflict costs one cycle of execution
  time, not a change of schedule.

### 5.3 BRAM output register (`fmax`)

The banks may enable the hardened **output register** (`BRAM_OUT_REG`, mapped
to `parmem3_2`'s `OUTREGA`/`OUTREGB` — §10.1), adding **one** read-latency
cycle for higher `fmax` (the synthesizer absorbs a datapath register into the
BRAM macro). This
shifts the load result to `W + 3`. Without an interlock this is an
**ISA-visible** choice: changing `BRAM_OUT_REG` (or `ADRREG`, §10.1)
invalidates compiled code and requires a rebuild.

---

## 6. Memory Ordering and the NoC Port

Because there is exactly **one** LS slot and issue is in-order, all Port-A memory
accesses execute in **program order**. Consequences:

- **A load observes every prior store from this core** to the same address, with
  no store buffer and no store-to-load forwarding network: the earlier store's
  bank write precedes the later load's read by construction. Memory RAW/WAW/WAR
  ordering is therefore free — nothing needs to track memory addresses.
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
| `DMEM_DEPTH_LOG2`  | 11      | Words **per bank**; the scratchpad holds `3 × 2^DMEM_DEPTH_LOG2` 32-bit words (§10.1) |
| `BRAM_OUT_REG`     | TBD     | Bank output register (`OUTREGA`/`OUTREGB` of `parmem3_2`); `1` adds one load-latency cycle (§5.3) |
| `ADRREG`           | 0       | Address-phase pipeline register in `parmem3_2` (§10.1); `1` adds one further load-latency cycle, `conflict`/`oob` stay combinational |

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

The `MUL` **must** be scheduled at least 2 words after the `LW`: nothing
stalls it, so scheduling it earlier reads a stale `r10`. The compiler spaces
them by pipelining across iterations (§9, SCOREBOARD.md §7.6).

**Reading a control register** (poll the hardware-loop iteration count):

```asm
    LW    r5, LOOP_COUNT    ; MMIO word at offset -6 from top of data space
```

**Dual-operand streaming** (one `LD2` fetches one element of each input
array; the stride register holds the distance between the two arrays, so a
single pointer walks both — §10.2):

```asm
    LD2W  r10, r11, (r20, r21)  ; r20 = &a[i]; r21 = &b[i] - &a[i] (words)
                                ;   a[i] -> r10 (LS-A), b[i] -> r11 (LS-B)
    MUL   r12, r10, r11         ; ALU0 (schedule >= 2 words after the LD2)
    ADD   r13, r13, r12         ; ALU1: accumulate
    ADDI  r20, r20, 4           ; control slot: bump the single pointer
```

The distance `r21` must satisfy `r21 % 3 != 0` for the pair to issue in one
cycle; otherwise the access still executes, one cycle slower (§10.4). Padding
the two arrays apart is a performance hint, not a correctness requirement.

**Scatter** (indexed load and indexed store share the index register on
rail 2 — §3.6/§3.7):

```asm
    LWX   r10, (r20, r21)       ; r10 <- src[idx]   (r21 = byte index)
    SWX   r10, (r22, r21)       ; dst[idx] <- r10
```

**Circular delay line** (`XCHW` writes the newest sample into the cell
holding the oldest and returns the evicted one — §3.8):

```asm
    XCHW  r10, r11, 0(r20)      ; r10 <- x[p] (oldest); x[p] <- r11 (newest)
                                ; r20 walks the circular buffer
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
file). The access direction and width (§10.3) are given by the opcode,
never by a field.

The pair instructions **split across the two encoding tiers by how many
registers they name**, not by being "dual":

| Instruction | Tier | Registers named | Payload |
|-------------|------|-----------------|---------|
| `LD2*` (5 opcodes, `001110`–`010010`) | classic, 6-bit opcode | 2 reads + 2 destinations | 24 of 26 bits |
| `ST2*` (3 opcodes, `1000`–`1010`)     | dual, 4-bit opcode     | 4 reads                  | 28 of 28 bits |

Only the four-source stores need the wide payload, so only they pay the
4-bit opcode; the dual loads fit the ordinary classic layout with two
bits to spare. Dual-tier codes `1011`–`1111` stay reserved — the
natural users are further four-source forms (an indexed dual store
`ST2X*` would need exactly the same 28 bits).

**Dual-tier opcode map** (the dual loads are in the §3.1 classic map):

| Opcode | Mnemonic | Operands                       | Description        |
|--------|----------|--------------------------------|--------------------|
| `1000` | `ST2`    | `(rs_base, rs_stride), s0, s1` | dual store word    |
| `1001` | `ST2H`   | `(rs_base, rs_stride), s0, s1` | dual store half    |
| `1010` | `ST2B`   | `(rs_base, rs_stride), s0, s1` | dual store byte    |
| `1011`–`1111` | — | reserved (5 codes)              |                    |

**Payload layouts** — every field sits on its §2.1 rail, so no
register-file port needs an address multiplexer and the dual loads reuse
the classic tier's rails unchanged (`d0` shares the `rd` rail, `rs_base`
rail 1, `rs_stride` rail 2):

```
common:  [20:14] rs_base(7)  [13:7] rs_stride(7)          (rails 1, 2)

LD2*:    [31:26] opcode(6)  [25:21] d0(5)   [6:2] d1(5)   [1:0] rsvd
ST2*:    [31:28] opcode(4)  [27:21] s0(7)   [6:0] s1(7)
```

- `LD2B/LD2BU/LD2H/LD2HU/LD2W` are five classic opcodes, one per
  width and extension — the same convention as `LB/LBU/LH/LHU/LW`.
- `ST2/ST2H/ST2B` fill their 28-bit payload with four 7-bit sources, so
  the width goes in the opcode as well. Sources are **full 7-bit global
  addresses** (any bank — the 10-read-port register file removes any
  lane-implicit restriction).
- Load destinations are 5-bit, bank-implicit per lane (`d0` → LS-A,
  `d1` → LS-B). Addresses are **word** EAs (the pair is word-aligned
  by construction; sub-word dual accesses select within the word —
  §3.4 extension rules apply per lane).

### 10.3 Access direction and exchange semantics (normative)

Both lanes of a pair have the **same direction**: a pair is either a
dual load (`LD2`) or a dual store (`ST2*`) — the memory takes one
shared write enable for the group, as `parmem3_2` implements today.

READ_FIRST still gives a useful property for free: a **writing lane
returns the pre-write content** of its cell on the corresponding read
data lane. A single-lane store therefore yields the old value without
a second access — this is what `XCHW` (§3.8) exposes, and it needs no
memory change at all.

> **Design note — mixed read/write pairs.** An earlier revision
> defined mixed forms (`STLD2`/`LDST2`: one lane storing while the
> other loads, for single-slot streaming copies and delay-line
> updates) and a per-lane `wen`. They were **removed**: word-only
> mixed ops serve mainly the sub-word data the dual tier exists to
> stream, and making them sub-word does not fit — the shared width
> plus the load lane's sign control need 3 payload bits where only 2
> remain, so width would have to move into the opcode and consume 4 of
> the tier's 8 codes. Their payoff is also modest: the LS slot is
> single-issue, so the alternative costs one extra bundle, and bulk
> copies belong to the NoC/DMA path (§6). Dual-tier opcodes
> `1011`–`1111` are reserved; if a kernel study shows delay-line updates dominating, the
> natural re-introduction is width-in-opcode
> (`STLD2W/STLD2H/LDST2W/LDST2H`) with the load lane's `u` in a
> reserved payload bit.

### 10.4 Conflict auto-serialization (normative)

`conflict` (`stride ≡ 0 (mod 3)` with both lanes enabled) is a pure
function of the stride residue and the lane mask, available **in the
issue cycle** (by construction, even with `ADRREG`). It is not a trap
and not an illegal encoding — the hardware **serializes**:

1. The LS unit splits the pair into two single-lane bank accesses
   (lane 0 then lane 1 — a one-bit sequencer re-presents the access
   with the complementary lane mask).
2. The whole machine is **frozen for one cycle** while the second
   access is performed: every stage holds its state, in-flight
   operations included. This is a **total freeze**, not a front-end
   freeze with a bubble travelling downstream, and the distinction is
   a correctness requirement, not a preference — see below.
3. Because nothing advanced during the frozen cycle, **both lanes
   retire together**: a conflicting pair has exactly the same latency
   as a conflict-free one (`1 + ADRREG + OUTREGA` cycles, §5.1). The
   only observable effect is that the program took one extra cycle.
4. **Atomicity comes for free.** The pair executes as one indivisible
   operation spanning two cycles: with the machine frozen, no flush,
   trap or interrupt can insert itself between the halves, so a
   conflicting dual **store** cannot be left half-committed.

**Why a total freeze.** Without an interlock the code is cycle-exact:
a consumer is scheduled at the precise cycle its producer's value
reaches the register file (SCOREBOARD.md, status note). A freeze that
stopped only the front end while in-flight operations drained would
delay that consumer by one cycle while its producer landed on time —
the consumer would read whatever the register holds one cycle later,
silently. Freezing everything delays producer and consumer equally, so
every latency is unchanged in pipeline-relative terms and the
compiler's schedule survives a bubble it could not have predicted:
`conflict` depends on a **register** value, so no static schedule can
anticipate it. This is the property that lets a stride multiple of 3
stay a performance matter instead of a correctness one.

Consequently, strides that are multiples of 3 are **legal but slow**.
The compiler's layout rules (pad pitches whose digit sum is divisible
by 3) are **performance hints, not correctness requirements**. `oob`
is unchanged: per-lane trap, offending lane suppressed, and the trap
takes precedence over `conflict` when both assert.

### 10.5 Open items

- Sub-word store support on the word-wide banks (byte write enables in
  `dpmemrf`, as §3.4 requires).
- **MMIO relocation.** The word address is `DMEM_DEPTH_LOG2 + 2` bits
  while only `3 × 2^DMEM_DEPTH_LOG2` words are backed, so a whole
  `2^DMEM_DEPTH_LOG2`-word region above the scratchpad is unbacked by
  construction. Moving the §4.2 control registers there would return 9
  words to the scratchpad and turn their decode into a plain range
  check; it also overlaps `parmem3_2`'s `oob` region, so the two
  decodes must be reconciled.
- **Sub-word dual addressing.** §10.2 states dual lane addresses as
  word EAs while §10.3's stride is in words, which leaves byte- and
  half-granular `LD2`/`ST2*` unable to name a sub-word element. Either
  `addr`/`stride` become byte quantities for those variants (bank word
  = `EA_i >> 2`, byte lane = `EA_i[1:0]`) or the sub-word dual forms
  are defined as word-strided with in-word selection only. To be
  resolved before the dual tier is implemented.
