# VLIW Load/Store Unit Specification

## 1. Overview

The Load/Store (LS) Unit is the core's single memory port. It is responsible
for:

- Loads and stores to the on-chip **data scratchpad** (the `parmem3_2`
  prime-interleaved banked memory, side A — §10)
- Access to the **memory-mapped control registers** at the top of the data
  address space (hardware-loop context — see §4)
- Address generation (`rs_base + sign_ext(imm)`), sub-word steering, and
  sign/zero extension

It is a single-issue slot: at most one memory instruction executes per VLIW
word. There is **no** instruction cache, data cache, store buffer, or
load/store reordering — the data path is a directly-addressed scratchpad
(ARCHITECTURE.md §Memory Model), and the single in-order port makes memory
accesses program-ordered by construction (§6).

There are no interrupts and no trap handlers, so this slot carries no
context-save duty: a fault halts the core and the host inspects the register
file over the NI port (ARCHITECTURE.md §Faults and Host Control).

---

## 2. Register File Interface

The LS Unit is one of the four issue slots. It owns **banks 2 and 3** of the
register file — `LS-A` (`010`, lane-0 results) and `LS-B` (`011`, lane-1
results); destinations are 5-bit with the bank implicit from the lane.

| Port        | Count | Width                               | Purpose                                   |
|-------------|-------|-------------------------------------|-------------------------------------------|
| Read ports  | **4** | 8-bit addr (3-bit bank + 5-bit reg) | `rs_base`; `rs_index`/`rs_stride`/`rs_data`; `s0`; `s1` |
| Write ports | **2** | 5-bit addr, bank implicit from lane | `rd`/`d0` (LS-A); `d1` (LS-B)             |

The register file holds **5 banks of 32 registers** (160 architectural
names). Each bank has **one write port and ten read ports**, the read
ports being LUTRAM replicas of the same content, so every one of the
bundle's ten reads addresses any bank independently — there is no
per-bank read limit. The partitioning is on the **write** side: one bank
per slot, and two for the LS slot (LS-A, LS-B).

A source address is therefore 8 bits — `bank[2:0]` selects one of the five
populated banks and `reg[4:0]` the register within it. Depth 32 is not a
free parameter: Xilinx distributed RAM has a minimum primitive depth of 32
words, so a shallower bank would occupy exactly the same LUTs while halving
the name space.

Maximum simultaneous demand is set by the dual store (§10.2): `rs_base` +
`rs_stride` + `s0` + `s1` = **4 reads**; the dual load writes `d0` + `d1` =
**2 writes**. No instruction does both: reads 3/4 carry store data and
write B carries a load result, so the two never coexist. All sources are full 8-bit **global** addresses (any bank, any
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
| `MOV` (register move)      | `rd`      | `rs`                                   |
| `MOV2` (dual move)         | `d0`,`d1` | `rs`, `rs1`                            |

### 2.1 Operand rails (encoding constraint)

Register fields are **not** placed per-instruction: every operand role is
pinned to a fixed bit range — a *rail* — shared by every instruction that
uses that role. Each register-file port therefore takes its address from
**one constant bit range**, with no per-opcode address multiplexer at the
head of the register-read path:

| Port          | Rail      | Roles carried                                        |
|---------------|-----------|------------------------------------------------------|
| read 1        | `[7:0]`   | `rs_base` (every memory instruction), `rs_mov`       |
| read 2        | `[15:8]`  | `rs_index`, `rs_stride`, `rs_data` (classic store), `rs_mov1` |
| read 3        | `[31:24]` | `s0` (dual stores — dual tier only)                  |
| read 4        | `[23:16]` | `s1` (dual stores), `rs_datax` (indexed stores)      |
| write A addr  | `[29:25]` | `rd`, `d0`                                           |
| write B addr  | `[20:16]` | `d1`                                                 |

The four read rails are the four **bytes** of `[31:0]`. That alignment is
forced by the dual store, which carries four 8-bit sources and no
destination and therefore tiles the payload exactly; every other format
inherits it, which is what leaves each classic-tier immediate in one
contiguous run.

Consequences:

- An instruction that does not use a rail leaves those bits as an
  immediate field or reserved; the corresponding port still issues a read,
  which is simply discarded — with no interlock to mislead, an unused rail
  needs no valid bit at all.
- Rail 3 `[31:24]` overlaps the classic-tier opcode `[35:30]` on its two
  top bits, so `s0` exists only in the dual tier — which is exactly the
  set of instructions needing four reads (the dual stores). Rail 4 is
  reachable from both tiers.
- An indexed **store** reads three registers, and puts its data on rail 4
  (`rs_datax`) rather than rail 2: that keeps `rs_index` on rail 2 with
  the indexed loads, so the effective-address adder's second operand is
  always read port 2 and the **address** path needs no multiplexer. The
  cost lands on the store-data multiplexer instead — the shorter path.
- The residual multiplexing is on the **data** side only: lane-0 write
  data comes from rail 2 for a classic store and from rail 3 for a dual
  store. That path is off the register-read address path, which is the
  timing-critical one (the RR→EX1 path, ARCHITECTURE.md §Pipeline). No
  immediate is split in the 36-bit map, so there is no reassembly path
  left at all.

Source-register hazards are the **compiler's responsibility**: the core
ships without an interlock, so a source read before its producer's latency
has elapsed returns a stale value silently (SCOREBOARD.md, status note).
Memory-address hazards, by contrast, are covered by construction — a single
in-order port (§6).

---

## 3. Instruction Set

Memory instructions are encoded in a **36-bit slot** with a **two-tier
opcode**, split by bit 35:

```
[35] = 0:   [35:30]    [29:0]           classic tier: flat 6-bit opcode
            opcode(6)  payload(30)      (values 000000–011111, 32 codes)

[35] = 1:   [35:32]    [31:0]           dual-access tier: 4-bit opcode
            opcode(4)  payload(32)      (values 1000–1111, 8 codes — §10.2)
```

The slot is 36 bits and the bundle 4 × 36 = **144 bits**, which is one
Xilinx BRAM36 per slot in 36-bit mode: the instruction memory needs no
word splitting and wastes no parity bits.

The **dual stores** (§10.2) read four 8-bit registers — `rs_base`,
`rs_stride`, `s0`, `s1` = 32 payload bits — which a 6-bit opcode cannot
leave room for; the 4-bit tier trades opcode space for payload exactly
there, and nothing else needs it. Dual *loads* read two registers and
write two 5-bit destinations (26 bits), so they stay in the classic
tier. By Kraft's budget the split costs the classic tier half its code
points (32 remain — 23 used today).

**NOP** is classic-tier `opcode = 000000` (the canonical empty-slot
encoding; the assembler emits the all-zero word `0x000000000`).

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
| `opcode`    | `[35:30]`               | 6     | —            | classic tier (`[35] = 0`)                |
| `opcode`    | `[35:32]`               | 4     | —            | dual tier (`[35] = 1`)                   |
| `rs_base`   | `[7:0]`                 | 8     | read 1       | **all** loads, stores, dual ops          |
| `rs_index`  | `[15:8]`                | 8     | read 2       | indexed loads and stores (`L*X`, `S*X`)  |
| `rs_data`   | `[15:8]`                | 8     | read 2       | classic stores (`SB`/`SH`/`SW`)          |
| `rs_stride` | `[15:8]`                | 8     | read 2       | dual loads and stores                    |
| `s0`        | `[31:24]`               | 8     | read 3       | `ST2*` (lane-0 store data)               |
| `s1`        | `[23:16]`               | 8     | read 4       | `ST2*` (lane-1 store data)               |
| `rs_datax`  | `[23:16]`               | 8     | read 4       | indexed stores (`SWX`/`SHX`/`SBX`)       |
| `rs_mov`    | `[7:0]`                 | 8     | read 1       | `MOV` source, `MOV2` lane 0 (§3.9)       |
| `rs_mov1`   | `[15:8]`                | 8     | read 2       | `MOV2` lane 1 (§3.10)                    |
| `rd`        | `[29:25]`               | 5     | write A addr | all classic loads                        |
| `d0`        | `[29:25]`               | 5     | write A addr | `LD2*` (lane-0 result → LS-A)            |
| `d1`        | `[20:16]`               | 5     | write B addr | `LD2*` (lane-1 result → LS-B)            |
| `imm17`     | `[24:8]`                | 17    | —            | base+immediate loads                     |
| `imm14`     | `[29:16]`               | 14    | —            | classic stores (§3.3)                    |
| `imm9`      | `[24:16]`               | 9     | —            | `XCHW` (§3.8)                            |

Notes on the map:

- Rails may **overlap** between roles that never coexist: `s0` `[31:24]`
  covers `d0` `[29:25]` (no instruction has both), and `s1` `[23:16]`
  covers `d1` `[20:16]`. Each port still reads a constant slice.
- A port whose rail carries something else in the current instruction
  (an immediate, reserved bits, opcode bits) performs a harmless read or
  is write-disabled; decode provides the per-port valid bit (§2.1).
- **No field is split.** Every immediate occupies one contiguous run, in
  the bits the dual store spends on `s0`/`s1`.
- All layouts (§3.2, §3.3, §3.6, §3.7, §3.8 and the two pair forms of
  §10.2) account for exactly 36 bits.

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
| `010111` | `MOV`    | `rd, rs`                       | register move to LS-A    | §3.9   |
| `011000` | `MOV2`   | `d0, d1, (rs, rs1)`            | dual register move       | §3.10  |

Reserved: classic-tier opcodes `011001`–`011111` (7 entries) and
dual-tier opcodes `1011`–`1111` (5 entries, §10.2). Executing a reserved
opcode **halts the core** with cause `ILLEGAL` (ARCHITECTURE.md §Faults and
Host Control) — the assembler must never emit one.

**Notes:**
- `rs_base`, `rs_data` are **8-bit** global register addresses
  (`bank[2:0]` + `reg[4:0]`).
- `rd`, `d0` and `d1` are **5-bit** with the bank implicit: `rd`/`d0`
  write LS-A, `d1` writes LS-B (§2).
- The immediate is a **signed byte offset** (§3.5).
- Load offset is `imm17` (**±64 KB**); store offset is `imm14` (**±8 KB**) — the
  store spends 8 extra encoding bits on its second source register (§3.3);
  `XCHW`'s offset is `imm9` (**±255 B**, §3.8).
- Register-**indexed** loads (`LBX`…`LHUX`, §3.6) and stores
  (`SWX`/`SHX`/`SBX`, §3.7) replace the immediate with a second source
  register `rs_index` (`EA = rs_base + rs_index`); the indexed store reads
  three registers, which the 4-read-port register file of §2 provides.

### 3.2 Load format

| [35:30]   | [29:25] | [24:8]    | [7:0]      |
|-----------|---------|-----------|------------|
| opcode(6) | rd(5)   | imm17(17) | rs_base(8) |

- Effective address `EA = rs_base + sign_ext(imm17)` (byte address).
- `imm17` signed → offset range **±65535 bytes (±64 KB)**.
- `rd <- extend(mem[EA])`, sign- or zero-extended per opcode (§3.4).

### 3.3 Store format

| [35:30]   | [29:16]   | [15:8]     | [7:0]      |
|-----------|-----------|------------|------------|
| opcode(6) | imm14(14) | rs_data(8) | rs_base(8) |

- Effective address `EA = rs_base + sign_ext(imm14)` (byte address).
- `imm14` signed → offset range **±8191 bytes (±8 KB)**.
- `mem[EA] <- rs_data` over the addressed byte lane(s) only (§3.4).
- A store reads **two** registers (`rs_data` + `rs_base`, both 8-bit), which is
  why only 14 immediate bits remain versus the load's 17.
- The immediate is **contiguous**: `rs_base` and `rs_data` sit on rails 1
  and 2 (§2.1), which are the two low bytes, so the immediate takes the
  bits above them in one run. The 36-bit slot removes the split that a
  32-bit slot forced here (the same split RISC-V carries in its S-type).

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
- **Unaligned addressing is not supported, and not checked either.** The
  low address bits below the access width are **truncated**, not faulted:
  a half-word access (`LH/LHU/SH/SHX/LD2H/LD2HU/ST2H`) ignores `EA[0]`, a
  word access (`LW/SW/SWX/LD2W/ST2/XCHW`) ignores `EA[1:0]`, a byte access
  ignores nothing. A dual access truncates its **base to a word** whatever
  its width (§10.2). There is no alignment comparator and no alignment
  fault: the access simply lands on the containing element. Emitting an
  unaligned address is a compiler error that the hardware will not report,
  in the same way it does not report a too-short latency.
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

| [35:30]   | [29:25] | [24:16]   | [15:8]      | [7:0]      |
|-----------|---------|-----------|-------------|------------|
| opcode(6) | rd(5)   | unused(9) | rs_index(8) | rs_base(8) |

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

| [35:30]   | [29:24]   | [23:16]     | [15:8]      | [7:0]      |
|-----------|-----------|-------------|-------------|------------|
| opcode(6) | unused(6) | rs_datax(8) | rs_index(8) | rs_base(8) |

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

| [35:30]   | [29:25] | [24:16]  | [15:8]     | [7:0]      |
|-----------|---------|----------|------------|------------|
| opcode(6) | rd(5)   | imm9(9)  | rs_data(8) | rs_base(8) |

- `EA = rs_base + sign_ext(imm9)` (byte address, word-aligned);
  `rd <- mem32[EA]` **and** `mem32[EA] <- rs_data` in one access.
- The immediate is 9 bits (**±255 bytes**) because `rd` occupies five of
  the bits an immediate-offset store spends on `imm14` (§3.3).
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

### 3.9 Register move (`MOV`)

| [35:30]  | [29:25] | [24:8]      | [7:0] |
|----------|---------|-------------|-------|
| `010111` | rd(5)   | unused(17)  | rs(8) |

- `rd <- rs`: copy any of the 160 global names into this slot's LS-A bank.
  No memory access, no address computation.
- **Why this slot needs a real opcode.** The register file is
  write-local / read-global (§2): reads reach every bank, so a move is never
  needed to *consume* a value — it is needed only to *place* one. The two ALU
  slots and the control slot each own an ALU and synthesise the move as a
  pseudo-instruction (`ADD rd, r0, rs`, or equally `XOR rd, rs, r0`); the LS
  slot owns no ALU at all, only an address adder and the sub-word steering, so
  it cannot. Adding a logic unit here to reach the same result would cost far
  more than this opcode: `MOV` is a wire from read port 1 to the write port,
  reusing the write-data multiplexer that already selects between load data
  and the `XCHW` pre-write word.
- **What it buys.** Without it, the only way to write LS-A / LS-B is a load, so
  a kernel whose pressure sits in banks 0–1 cannot use the 64 free names in
  banks 2–3 except through memory:

```asm
; without MOV — spill and refill through the scratchpad
        SW     b0r5, 0(b4r1)        ; LS slot
        LW     b2r1, 0(b4r1)        ; LS slot, plus load latency and traffic

; with MOV
        MOV    b2r1, b0r5           ; one LS slot, no memory access
```

- Retires at `W + 2` like every other LS result (§5.1) — see §3.10 for why it
  is not made faster.

### 3.10 Dual register move (`MOV2`)

| [35:30]  | [29:25] | [24:21]   | [20:16] | [15:8]  | [7:0] |
|----------|---------|-----------|---------|---------|-------|
| `011000` | d0(5)   | unused(4) | d1(5)   | rs1(8)  | rs(8) |

- `d0 <- rs` and `d1 <- rs1` in one issue: fills both LS banks in a single
  cycle, the move counterpart of `LD2*` and on the same rails (§2.1).
- Its four operands cost 26 payload bits, so it stays in the classic tier.

**Latency is uniform across the slot, deliberately.** `MOV` and `MOV2` never
reach the memory and could in principle retire earlier than a load, but each
bank has exactly **one write port**. A `MOV` issued at `T` retiring at `T + 1`
would collide with a load issued at `T - 1` retiring at the same cycle. Tying
every LS result to the same retire distance — `W + 2`, plus one cycle per
`BRAM_OUT_REG` / `ADRREG` option — makes LS results retire strictly in issue
order, one per cycle, so the single write port can never be double-driven. The
moves ride the pipeline registers alongside the load data; the cost is latency
they do not need, and the gain is that the slot has one latency rule instead
of two.

---

## 4. Data Memory Address Space

### 4.1 Layout

The data address space is the on-chip **`parmem3_2` scratchpad** (§10.1):
three banks of `2^DMEM_DEPTH_LOG2` words, so
**`3 × 2^DMEM_DEPTH_LOG2` words** of 32 bits (byte size
`3 × 2^(DMEM_DEPTH_LOG2+2)`). Side A is this LS slot; side B is the NoC /
network interface (§6, ARCHITECTURE.md §Data Memory and NoC Interface).
The **top 4 words** are not backed by memory: the LS unit decodes them as
memory-mapped loop registers (§4.2).

```
byte 0                                              top of data space
| general scratchpad (3 x 2^DMEM_DEPTH_LOG2 - 4)  | LOOP regs (4 words) |
```

> Because the word address is `DMEM_DEPTH_LOG2 + 2` bits wide while only
> `3 × 2^DMEM_DEPTH_LOG2` words are backed, a further `2^DMEM_DEPTH_LOG2`
> words at the top of the *encodable* range are unbacked by construction.
> The MMIO block is relocated there (§10.5): those 9 words return to the
> scratchpad and the decode becomes a plain range check on the high address
> bits. There is no longer an out-of-bounds fault to reconcile it with —
> see below.

### 4.2 Memory-mapped control registers

The LS unit routes accesses whose word address falls in the top region to the
control registers below instead of the scratchpad banks. This is the single authoritative
map; the loop registers are used by CONTROL_UNIT.md §4.8.

| Offset from top | Name           | Width             | Access | Description                                  |
|-----------------|----------------|-------------------|--------|----------------------------------------------|
| -4              | `LOOP_ACTIVE`  | 1                 | RW     | Hardware-loop active flag                    |
| -3              | `LOOP_START`   | `IMEM_DEPTH_LOG2` | RW     | Hardware-loop start PC                        |
| -2              | `LOOP_END`     | `IMEM_DEPTH_LOG2` | RW     | Hardware-loop end PC                          |
| -1              | `LOOP_COUNT`   | 32                | RW     | Hardware-loop remaining iterations            |

- The `LOOP_*` registers access the **committed** loop state
  (CONTROL_UNIT.md §4.4). All reset to `0`.
- MMIO registers are accessed with **word** operations (`LW`/`SW`) and must be
  word-aligned; the low two address bits are truncated like everywhere else
  (§3.5), so a sub-word MMIO access reads or writes the containing register
  word rather than faulting.
- Writes to **RO** registers have no effect; reads of narrow registers
  zero-extend to 32 bits.
- Offsets are word offsets from the top of the backed region; e.g. `-1` is
  byte address `3 × 2^(DMEM_DEPTH_LOG2+2) - 4`.
- **The host control block is not here.** Fault status and the run/halt
  controls live in the *unbacked* region above the scratchpad and are
  reachable from **side B only** (ARCHITECTURE.md §Faults and Host Control):
  the core cannot alter its own run state, and the host does not have to
  contend with it for scratchpad words.

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
| `MOV`       | `rd` at **W + 2**                         | never reaches memory (§3.9)   |
| `MOV2`      | `d0` **and** `d1` at **W + 2**            | never reaches memory (§3.10)  |

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
| `ADRREG`           | 0       | Address-phase pipeline register in `parmem3_2` (§10.1); `1` adds one further load-latency cycle, `conflict` stays combinational |

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

**Polling for work between kernels** (there are no interrupts: the NI writes a
descriptor and a completion flag through side B, the core reads them between
blocks — ARCHITECTURE.md §Faults and Host Control):

```asm
poll:
    LW    r10, FLAG(c1)      ; flag written by the NI through side B
    ; ... 2 bundles of other work or NOPs (load latency, section 5.1) ...
    BEQ   r10, r0, poll      ; not ready: poll again
    ; ... 3 delay-slot bundles, always executed ...
    LW    r11, DESC(c1)      ; descriptor: base, length, kernel id
```

Note the two exposed latencies in this fragment: `r10` may not be read before
`W + 2`, and the three bundles after `BEQ` execute whether or not the branch
is taken (ARCHITECTURE.md §Latency model).

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
  while keeping `conflict` combinational at issue.

### 10.2 Dual strided access pair — encoding

The LS slot's dual-op class accesses a **pair from one instruction**:
lane `i` (`i = 0, 1`) at `EA_i = rs_base + i·rs_stride`, both **in bytes**
and `rs_stride` signed — the same units as every other addressing mode in
this slot (§3.5). Lane 0's result writes the LS-A bank, lane 1's the LS-B bank
(one write port each — §2 grows to the 5-bank, 10-read-port register
file). The access direction and width (§10.3) are given by the opcode,
never by a field.

**Byte addressing, word banks.** The banks are 32 bits wide, so lane `i`
addresses bank word `EA_i >> 2` and selects byte lane `EA_i[1:0]` inside it.
Both are wire slices, not arithmetic. The base is **truncated to a word**
(`rs_base[1:0]` dropped, §3.5) — by construction, not by a check, so nothing
has to be verified and nothing can fault. The lane word addresses are then
exactly

```
word_i = (rs_base >> 2) + i · (rs_stride >> 2)
```

so the stride's own low two bits are simply dropped: 4 bytes of stride is one
word, 8 bytes is two. This buys two things at once.

*Contiguous sub-word data works.* A stride smaller than 4 bytes puts both
lanes **in the same word** — `int16` pairs, `int8` pairs — and one bank read
serves them both, the sub-word steering extracting the two elements. That is
one access, not two, and no conflict is possible:

```asm
; int16 array, word-aligned base, contiguous pair
        LD2H   b2r1, b3r1, (b0r10, b0r11)   ; b0r11 = 2 bytes
        ; -> h[0] and h[1], both out of the same 32-bit word, one bank access
```

*The conflict predicate stays a pure function of the stride.* With the base
word-aligned, the lane-to-lane word distance is `rs_stride >> 2` and does not
depend on the base at all — which is what keeps `conflict` computable before
the address adder (§10.4).

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
common:  [7:0] rs_base(8)   [15:8] rs_stride(8)           (rails 1, 2)

LD2*:    [35:30] opcode(6)  [29:25] d0(5)  [24:21] rsvd  [20:16] d1(5)
ST2*:    [35:32] opcode(4)  [31:24] s0(8)  [23:16] s1(8)
```

- `LD2B/LD2BU/LD2H/LD2HU/LD2W` are five classic opcodes, one per
  width and extension — the same convention as `LB/LBU/LH/LHU/LW`.
- `ST2/ST2H/ST2B` fill their 32-bit payload with four 8-bit sources, so
  the width goes in the opcode as well. Sources are **full 8-bit global
  addresses** (any bank — the read-replicated register file of §2 imposes
  no restriction on which banks the four sources name).
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

Let `Δ = rs_stride >> 2` be the lane-to-lane distance in bank words
(§10.2; exact because the dual base is word-aligned). Two conditions
follow from it, and they must not be confused:

```
same_word = (Δ == 0)                    -- both lanes inside one 32-bit word
conflict  = (Δ != 0) && (Δ % 3 == 0)    -- distinct words, same bank
```

`same_word` is **free**: one bank read serves both lanes and the sub-word
steering splits it. It covers contiguous `int16`/`int8` pairs and the
broadcast case `rs_stride = 0`, neither of which costs an extra cycle. An
earlier revision tested only `stride ≡ 0 (mod 3)`, which is true of `0` as
well — so it froze the core on every broadcast, for nothing.

`conflict` is the real case, and like `same_word` it is a pure function of
the stride residue and the lane mask, never of the addresses, so it is
available **in the issue cycle** (by construction, even with `ADRREG`). It is
not a fault and not an illegal encoding — the hardware **serializes**:

1. **The memory splits the pair itself.** `parmem3_2` (and `parmem5_2`)
   sequence the two single-lane accesses internally — lane 0, then lane 1
   with the complementary lane mask — and expose the fact to the core as a
   single **registered** `freeze` output. The LS unit carries no sequencer:
   it presents one dual access and consumes one `freeze` bit.

   The bit must come out of a flip-flop, not combinationally. A path from
   the stride register through the residue tree to the global clock enable
   of every pipeline stage would be the worst path in the machine. Being
   registered, it also lands at the right time: at cycle `T` the pair is
   issued and lane 0 is performed, at `T+1` the bit freezes the core while
   lane 1 completes, at `T+2` execution resumes.

   This is why the mechanism is confined to the **`L = 2`** members of the
   family. A `parmemB_L` with more lanes would have to freeze the core for
   up to `L` cycles per conflict, which is a different and far less
   attractive trade; the wider components stay conflict-reporting only.
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
   operation spanning two cycles: with the machine frozen, no flush
   can insert itself between the halves, so a conflicting dual **store**
   cannot be left half-committed. Nothing else could: there are no
   interrupts, and a fault stops the core outright.

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
by 3) are **performance hints, not correctness requirements**.

**No out-of-bounds fault.** An earlier revision had `parmem3_2` report an
`oob` condition per lane, suppress the offending lane and halt the core. That
mechanism is **removed**: an address beyond the backed scratchpad is not
detected and not reported. Addresses in the unbacked top region decode as
MMIO (§4.1); anything else outside the backed range reads or writes an
undefined location. Staying in range is a compiler obligation like every
other, and `conflict` is now the only condition the memory reports.

### 10.5 Open items

- Sub-word store support on the word-wide banks (byte write enables in
  `dpmemrf`, as §3.4 requires).
