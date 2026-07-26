# VLIW Load/Store Unit Specification

## 1. Overview

The Load/Store (LS) Unit is the core's single memory port. It is responsible
for:

- Loads and stores to the on-chip **data scratchpad** (DPRAM, Port A)
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

The LS Unit is one of the four issue slots. It owns **bank 2** (`010`) of the
register file; its `rd` writes go there (5-bit destination, bank implicit).

| Port        | Count | Width                               | Purpose                                   |
|-------------|-------|-------------------------------------|-------------------------------------------|
| Read ports  | **2** | 7-bit addr (3-bit bank + 5-bit reg) | `rs_base`; `rs_data` (stores) or `rs_index` (indexed loads) |
| Write port  | **1** | 5-bit addr, bank implicit from slot | `rd` (loads)                              |

Rationale for **2 read / 1 write**:

| Instruction class | rd  | rs_base | 2nd read   |
|-------------------|-----|---------|------------|
| Load (base+imm)   | yes | yes     | —          |
| Indexed load      | yes | yes     | `rs_index` |
| Store             | no  | yes     | `rs_data`  |

Maximum simultaneous demand = **2 reads** (a store reads `rs_base` + `rs_data`;
an indexed load reads `rs_base` + `rs_index`) and **1 write** (a load writes
`rd`). Sources are full 7-bit global
addresses (any bank); the load destination is 5-bit (the LS bank). Source-
register hazards (a load/store whose `rs_base`/`rs_data` is still in flight) are
covered by the hardware scoreboard (ARCHITECTURE.md §Scoreboard); memory-address
hazards are covered by the single in-order port (§6).

---

## 3. Instruction Set

Memory instructions are encoded in a **32-bit slot** with a single flat 6-bit
opcode, in the LS slot's own opcode space:

```
[31:26]    [25:0]
opcode(6)  payload(26)
```

**NOP** is `opcode = 000000` (the canonical empty-slot encoding; the assembler
emits the all-zero word `0x00000000`).

### 3.1 Encoding reference card

The 6-bit opcode is a **flat, sequential** assignment in the LS slot's own
opcode space (same convention as the control slot). The access width and
sign/zero behaviour are **folded into the opcode** — there is no separate width
or `funct` field. `NOP = 000000`.

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

Reserved: opcodes `001110`–`111111` (50 entries). Executing a reserved opcode
raises an **illegal-instruction trap** (same entry path as `TRAP`; `trap_code`
in `ABI.md`) — the assembler must never emit one.

**Notes:**
- `rs_base`, `rs_data` are **7-bit** global register addresses
  (`bank[2:0]` + `reg[4:0]`).
- `rd` is **5-bit** (bank implicit — the LS bank).
- The immediate is a **signed byte offset** (§3.5).
- Load offset is `imm14` (**±8 KB**); store offset is `imm12` (**±2 KB**) — the
  store spends 7 extra encoding bits on its second source register (§3.3).
- Register-**indexed** loads (`LBX`…`LHUX`, §3.6) replace the immediate with a
  second source register `rs_index` (`EA = rs_base + rs_index`); there is no
  indexed store (it would need a third read port).

### 3.2 Load format

| [31:26]   | [25:21] | [20:14]    | [13:0]    |
|-----------|---------|------------|-----------|
| opcode(6) | rd(5)   | rs_base(7) | imm14(14) |

- Effective address `EA = rs_base + sign_ext(imm14)` (byte address).
- `imm14` signed → offset range **±8191 bytes (±8 KB)**.
- `rd <- extend(mem[EA])`, sign- or zero-extended per opcode (§3.4).

### 3.3 Store format

| [31:26]   | [25:19]    | [18:12]    | [11:0]    |
|-----------|------------|------------|-----------|
| opcode(6) | rs_data(7) | rs_base(7) | imm12(12) |

- Effective address `EA = rs_base + sign_ext(imm12)` (byte address).
- `imm12` signed → offset range **±2047 bytes (±2 KB)**.
- `mem[EA] <- rs_data` over the addressed byte lane(s) only (§3.4).
- A store reads **two** registers (`rs_data` + `rs_base`, both 7-bit), which is
  why only 12 immediate bits remain versus the load's 14.

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
- Reads two registers (`rs_base`, `rs_index`) and writes `rd` — fits the LS
  slot's existing **2 read / 1 write** ports, so **no new register-file ports**.
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
- **Port B (NoC / NI) is not coherent with Port A.** The two DPRAM ports carry
  no arbitration and no snooping (ARCHITECTURE.md §Data Memory and NoC
  Interface); ordering between core accesses and NoC accesses is the
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
uses the two-word `LUI`+`ADDI` constant-generation idiom (ARCHITECTURE.md §ALU
Slot) to form the base, then a `0` offset.

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
