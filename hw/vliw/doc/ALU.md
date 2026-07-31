# VLIW ALU Slot Specification

## 1. Overview

The processor carries **two identical ALU slots** (ALU 0 and ALU 1). Each is
responsible for:

- Integer arithmetic (`ADD`, `SUB`), logic (`AND`, `OR`, `XOR`)
- Compares (`SLT`, `SLTU` — materialized 0/1 results)
- Barrel shifts (`SLL`, `SRL`, `SRA`)
- Multiplication (`MUL`, `MULH`)
- Upper-immediate constant generation (`LUI`)

Each slot is single-issue: at most one ALU instruction per slot per VLIW word,
so up to **two ALU operations per bundle**. The two slots are functionally
identical — the compiler may place any ALU operation in either slot.

ALU 0 writes **bank 0** (`000`), ALU 1 writes **bank 1** (`001`)
(ARCHITECTURE.md §Register File).

---

## 2. Register File Interface

Each ALU slot sees:

| Port        | Count | Width                               | Purpose            |
|-------------|-------|-------------------------------------|--------------------|
| Read ports  | **2** | 8-bit addr (3-bit bank + 5-bit reg) | `rs1`, `rs2`       |
| Write port  | **1** | 5-bit addr, bank implicit from slot | `rd`               |

Rationale for **2 read / 1 write**:

| Instruction class | rd  | rs1 | rs2 |
|-------------------|-----|-----|-----|
| R-type            | yes | yes | yes |
| I-type            | yes | yes | no  |
| U-type (`LUI`)    | yes | no  | no  |

Maximum simultaneous demand = 2 reads (R-type), 1 write — the standard per-slot
allocation, identical to the other slots.

**`r0` note.** The canonical zero lives at **bank 0, reg 0** — inside ALU 0's
own bank. ALU 0's write port is therefore masked when `rd = 0`
(ARCHITECTURE.md §Implementation of `r0`, option A). Bank 1's "reg 0" is a
**normal general-purpose register** for ALU 1 (scratch / discard by
convention).

---

## 3. Instruction Set

ALU instructions are encoded in a **36-bit slot** with a single flat 6-bit
opcode, in the ALU slots' own opcode space (both slots decode the same space):

```
[35:30]    [29:0]
opcode(6)  payload(30)
```

There is no format bit: register and immediate forms of an operation (e.g.
`ADD` / `ADDI`) are **distinct opcodes**.

**NOP** is `opcode = 000000` (the canonical empty-slot encoding; the assembler
emits the all-zero word `0x000000000`).

### 3.1 Encoding reference card

**Fixed field positions (where applicable):**

| Field    | Bits    | Width | Notes                                    |
|----------|---------|-------|------------------------------------------|
| `opcode` | [35:30] | 6     | instruction selector                     |
| `rd`     | [29:25] | 5     | dest register, bank implicit from slot   |
| `rs1`    | [7:0]   | 8     | source 1 (R-type and I-type) — read rail 1 |
| `rs2`    | [15:8]  | 8     | source 2 (R-type only) — read rail 2     |
| `funct`  | [24:16] | 9     | R-type extension field (assembler emits 0) |
| `imm17`  | [24:8]  | 17    | signed immediate (I-type)                |
| `imm20`  | [19:0]  | 20    | upper immediate (`LUI` only)             |

Both sources sit on fixed **rails** — the two low bytes — so each read port
takes its address from one constant slice with no per-opcode multiplexer,
the same discipline as the LS slot (LOAD_STORE.md §2.1). Every immediate
is contiguous.

**Opcode map** — the single authoritative list of ALU-slot opcodes:

| Opcode   | Mnemonic   | Operands          | Description                                      | Layout |
|----------|------------|-------------------|--------------------------------------------------|--------|
| `000000` | `NOP`      | —                 | no operation                                     | §3     |
| `000001` | `ADD`      | `rd, rs1, rs2`    | `rd <- rs1 + rs2`                                | §3.2   |
| `000010` | `ADDI`     | `rd, rs1, imm17`  | `rd <- rs1 + sign_ext(imm17)`                    | §3.3   |
| `000011` | `SUB`      | `rd, rs1, rs2`    | `rd <- rs1 - rs2`                                | §3.2   |
| `000100` | `AND`      | `rd, rs1, rs2`    | `rd <- rs1 & rs2`                                | §3.2   |
| `000101` | `ANDI`     | `rd, rs1, imm17`  | `rd <- rs1 & sign_ext(imm17)`                    | §3.3   |
| `000110` | `OR`       | `rd, rs1, rs2`    | `rd <- rs1 \| rs2`                               | §3.2   |
| `000111` | `ORI`      | `rd, rs1, imm17`  | `rd <- rs1 \| sign_ext(imm17)`                   | §3.3   |
| `001000` | `XOR`      | `rd, rs1, rs2`    | `rd <- rs1 ^ rs2`                                | §3.2   |
| `001001` | `XORI`     | `rd, rs1, imm17`  | `rd <- rs1 ^ sign_ext(imm17)`                    | §3.3   |
| `001010` | `SLT`      | `rd, rs1, rs2`    | `rd <- (rs1 <  rs2) signed ? 1 : 0`              | §3.2   |
| `001011` | `SLTI`     | `rd, rs1, imm17`  | `rd <- (rs1 < sign_ext(imm17)) signed ? 1 : 0`   | §3.3   |
| `001100` | `SLTU`     | `rd, rs1, rs2`    | `rd <- (rs1 <  rs2) unsigned ? 1 : 0`            | §3.2   |
| `001101` | `SLTIU`    | `rd, rs1, imm17`  | `rd <- (rs1 < sign_ext(imm17)) unsigned ? 1 : 0` | §3.3   |
| `001110` | `SLL`      | `rd, rs1, rs2`    | `rd <- rs1 << rs2[4:0]`                          | §3.2   |
| `001111` | `SLLI`     | `rd, rs1, shamt`  | `rd <- rs1 << shamt`                             | §3.3   |
| `010000` | `SRL`      | `rd, rs1, rs2`    | `rd <- rs1 >> rs2[4:0]` (logical)                | §3.2   |
| `010001` | `SRLI`     | `rd, rs1, shamt`  | `rd <- rs1 >> shamt` (logical)                   | §3.3   |
| `010010` | `SRA`      | `rd, rs1, rs2`    | `rd <- rs1 >> rs2[4:0]` (arithmetic)             | §3.2   |
| `010011` | `SRAI`     | `rd, rs1, shamt`  | `rd <- rs1 >> shamt` (arithmetic)                | §3.3   |
| `010100` | `MUL`      | `rd, rs1, rs2`    | `rd <- (rs1 * rs2)[31:0]`                        | §3.2   |
| `010101` | `MULH`     | `rd, rs1, rs2`    | `rd <- (rs1 * rs2)[63:32]` (signed × signed)     | §3.2   |
| `010111` | `LUI`      | `rd, imm20`       | `rd <- imm20 << 12`                              | §3.4   |

Reserved: opcode `010110` (`INV_SQRT`, deferred — §3.5) and `011000`–`111111`
(41 entries in total). Executing a reserved opcode
**halts the core** with cause `ILLEGAL` (ARCHITECTURE.md §Faults and Host
Control) — the assembler must never emit one. This reserved space is the
landing zone for the proposed DSP extensions in §7 (non-normative).

**Notes:**
- `rs1`, `rs2` are **8-bit** global register addresses
  (`bank[2:0]` + `reg[4:0]`); `rd` is **5-bit** (bank implicit from the slot).
- `imm17` is signed, sign-extended to 32 bits → range **±65535**. All I-type
  immediates (including the logic ops) sign-extend.
- `shamt` in `SLLI`/`SRLI`/`SRAI` is `imm17[4:0]` (0–31); the assembler must
  emit 0 in `imm17[16:5]`.
- Register and immediate forms are **distinct opcodes** (no format bit).
- `SUB`, `MUL`, `MULH` have **no immediate form**
  (`SUBI x` = `ADDI -x`).

### 3.2 R-type format (register–register)

| [35:30]   | [29:25] | [24:16]  | [15:8] | [7:0]  |
|-----------|---------|----------|--------|--------|
| opcode(6) | rd(5)   | funct(9) | rs2(8) | rs1(8) |

- `funct(7)` refines the operation / reserves room for future 3-operand forms;
  the base ops are fully selected by `opcode`, so the assembler emits `0`.

### 3.3 I-type format (register–immediate)

| [35:30]   | [29:25] | [24:8]    | [7:0]  |
|-----------|---------|-----------|--------|
| opcode(6) | rd(5)   | imm17(17) | rs1(8) |

- `imm17` is signed, sign-extended to 32 bits → range **±65535**. The
  36-bit slot widens it from the 14 bits a 32-bit slot allowed, so every
  constant up to ±64 K is now a single instruction.

### 3.4 LUI format (U-type)

| [35:30]  | [29:25] | [24:20]   | [19:0]    |
|----------|---------|-----------|-----------|
| `010111` | rd(5)   | unused(5) | imm20(20) |

- `rd <- imm20 << 12` (low 12 bits zero).
- The `LUI` + `ADDI` pair still synthesises any 32-bit constant, and the
  usual carry fix-up is **gone**: the low 12 bits now travel in a 17-bit
  signed field, so they are always representable as a positive value and
  never borrow from the upper half.

### 3.5 INV_SQRT — deferred, not part of this revision

Opcode `010110` is **reserved**. A reciprocal-square-root approximation was
sketched in an earlier draft but never specified: operand domain, result
number format (integer vs Q-format fixed point), approximation precision and
the behaviour at `rs1 = 0` or on negative inputs were all left open, and the
kernels driving this design do not need it today. It is set aside rather than
half-specified.

Consequence for the pipeline: `INV_SQRT` was the only `W + 5` operation and
therefore the sole reason for an **EX5** stage. Without it the ALU slot is
four deep (`MUL`/`MULH` at `W + 4`). Whether EX5 survives is a question for
the synthesis pass that fixes the latencies (§4).

---

## 4. Latency Contract Summary (ALU Slot)

| Instruction              | Result available (VLIW words after issue) |
|--------------------------|--------------------------------------------|
| `ADD`/`SUB`/logic/`SLT*` | `rd` at W + 2                              |
| `LUI`                    | `rd` at W + 2                              |
| `SLL`/`SRL`/`SRA` (`*I`) | `rd` at W + 3                              |
| `MUL`/`MULH`             | `rd` at W + 4                              |

These are the `BRAM_OUT_REG = 0` baseline values and they are a **correctness
contract**: the core has no interlock (ARCHITECTURE.md §No Interlock), so a
consumer scheduled earlier reads the destination's previous content, silently.
Two writes to one register must also be ordered by the compiler — latencies
differ, so a `MUL` (W+4) issued before an `ADD` (W+2) lands *after* it.

---

## 5. Write-port scheduling (compiler obligation)

- Each ALU slot is the **single writer** of its own bank, so WAW hazards stay
  local to that bank and no write-port arbitration exists in hardware
  (ARCHITECTURE.md §No Interlock).
- **The slot's latencies differ, and its bank has one write port.** Two
  instructions issued at different cycles can therefore retire in the *same*
  cycle. Nothing detects it: with no interlock there is no delay line, no
  stall and no arbiter — one of the two writes is simply lost.

```asm
        MUL      b0r1, b0r2, b0r3   ; T   -> retires T+4
        SLL      b0r4, b0r5, b0r6   ; T+1 -> retires T+4   <-- collision
        ADD      b0r7, b0r8, b0r9   ; T+2 -> retires T+4   <-- collision
```

- **Rule (normative).** No two instructions issued into the same slot may
  retire in the same cycle. Since every latency is fixed and known at
  compile time, this is a pure scheduling obligation — the compiler computes
  `issue_cycle + latency` per instruction and keeps those values distinct
  within a slot. It costs no hardware, and it is the same division of labour
  as everywhere else in this core: the compiler owns what it can decide
  statically, and hardware owns only what it cannot (the bank-conflict
  freeze, LOAD_STORE.md §10.4, whose trigger is a runtime register value).
- The LS slot is exempt by construction: all of its results retire at the
  same distance, so its writes are serialised by issue order
  (LOAD_STORE.md §3.10).
- Cross-slot RAW — reading another slot's in-flight result — is the ordinary
  latency obligation of §4, not a structural one.

---

## 6. Pseudo-instructions and constant generation

| Pseudo        | Real instruction      | Meaning                    |
|---------------|-----------------------|----------------------------|
| `NOP`         | opcode `000000`       | empty slot (dedicated NOP) |
| `MOV rd, rs`  | `ADD rd, r0, rs`      | register copy (`XOR rd, rs, r0` is equivalent) |
| `NEG rd, rs`  | `SUB rd, r0, rs`      | negate                     |
| `NOT rd, rs`  | `XOR rd, rs, -1`      | bitwise not                |
| `LI rd, imm`  | `ADDI rd, r0, imm17`  | load small immediate (±65535) |

A dedicated `MOV` opcode would buy nothing here: the slot owns a full ALU, so
the copy costs one instruction either way. The **LS slot** is the exception —
it owns no ALU and therefore carries a real `MOV` (`LOAD_STORE.md` §3.9); the
control slot dropped its own for the same reason this table exists
(`CONTROL_UNIT.md` §3.7).

**32-bit constant generation (2 VLIW words):**

```
LUI  rd, imm20        # rd = imm20 << 12
ADDI rd, rd, lo12     # rd = rd + low 12 bits
```

Because `ADDI` carries a **17-bit** immediate, the low 12 bits can always be
added as a *positive* value 0–4095 — no RISC-V-style `%hi` carry adjustment is
needed when bit 11 of the low part is set. Constants that fit in ±65535 need
no pair at all: a single `ADDI rd, r0, imm17` covers them.

---

## 7. Proposed DSP extensions (non-normative)

> **Status: proposals only.** Nothing in this section is part of the ISA.
> These ideas are distilled from the author's 2013 `sasquatch` DSP ALU
> (`sasquatch/trunk/src/arch/processors/{alu_dsp, logic_unit}`), which
> implemented a `MUL → 64-bit accumulate → barrel-scale` pipeline with a
> subword-SIMD logic unit. The reserved opcode space `011000`–`111111`
> (40 entries, §3.1) is the landing zone if adopted.

- **P1 — Fused MAC (`MADD`/`MSUB`).** One-op multiply-accumulate; collapses
  the 2-op MAC inner loop and keeps 32×32→64 precision. **Blocking decision:**
  (a) hidden per-slot 64-bit accumulator (full precision, but new architectural
  state the host would have to inspect on a fault), or
  (b) accumulate into an RF register `rd += rs1*rs2` (no new state, but 32-bit
  accumulation or a register-pair convention). Decide
  before anything else in this list.
- **P2 — Post-accumulate scale/round shift (`SRAC*`-style).** Arithmetic
  right shift with rounding/clip of the (wide) accumulator back to 32 bits —
  the Q-format renormalize / int8 requantize step. Natural companion to P1.
- **P3 — Subword SIMD mode (byte/half).** 4×int8 / 2×int16 lanes per op
  (old `MODE_{BYTE,HALF,WORD}` field). Throughput ×4/×2 for quantized kernels;
  pairs with wide loads (see the wide-DPRAM idea in ARCHITECTURE.md §Memory
  Model discussion). Costs a mode field or per-width opcodes plus lane carry
  breaks.
- **P4 — Saturating arithmetic + `MIN`/`MAX`.** `MINU/MINS/MAXU/MAXS` and
  saturating add/sub. Cheap (compare + mux). `MAXS rd, x, r0` is a one-op
  ReLU.
- **P5 — Pack/unpack and lane extract.** `UPCKL/UPCKH` byte/half interleave
  and `rdsel`-style lane extract with sign/zero extension — the SIMD data
  reorganisation set needed once P3 exists.
- **P6 — Extended compares / rotates.** `SEQ`, `SGT*` (complement the `SLT*`
  family), `ROTL`/`ROTR`. Low value individually; batch with any of the above.
- **P7 — `MULHU`/`MULHSU`.** Unsigned / mixed high-multiply (RV32M has them,
  we only have signed `MULH`); needed for full-precision unsigned 64-bit
  products.

---

## 8. Parameters

No slot-local parameters. Latencies derive from the pipeline structure
(ARCHITECTURE.md §Pipeline) and are architectural (§4): retiming the
multiplier register depth for `fmax` changes the contract and
requires the kernels to be rebuilt.
