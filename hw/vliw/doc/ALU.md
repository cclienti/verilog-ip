# VLIW ALU Slot Specification

## 1. Overview

The processor carries **two identical ALU slots** (ALU 0 and ALU 1). Each is
responsible for:

- Integer arithmetic (`ADD`, `SUB`), logic (`AND`, `OR`, `XOR`)
- Compares (`SLT`, `SLTU` — materialized 0/1 results)
- Barrel shifts (`SLL`, `SRL`, `SRA`)
- Multiplication (`MUL`, `MULH`)
- `INV_SQRT` (reciprocal square root approximation)
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
| Read ports  | **2** | 7-bit addr (3-bit bank + 5-bit reg) | `rs1`, `rs2`       |
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

ALU instructions are encoded in a **32-bit slot** with a single flat 6-bit
opcode, in the ALU slots' own opcode space (both slots decode the same space):

```
[31:26]    [25:0]
opcode(6)  payload(26)
```

There is no format bit: register and immediate forms of an operation (e.g.
`ADD` / `ADDI`) are **distinct opcodes**.

**NOP** is `opcode = 000000` (the canonical empty-slot encoding; the assembler
emits the all-zero word `0x00000000`).

### 3.1 Encoding reference card

**Fixed field positions (where applicable):**

| Field    | Bits    | Width | Notes                                    |
|----------|---------|-------|------------------------------------------|
| `opcode` | [31:26] | 6     | instruction selector                     |
| `rd`     | [25:21] | 5     | dest register, bank implicit from slot   |
| `rs1`    | [20:14] | 7     | source 1 (R-type and I-type)             |
| `rs2`    | [13:7]  | 7     | source 2 (R-type only)                   |
| `funct`  | [6:0]   | 7     | R-type extension field (assembler emits 0) |
| `imm14`  | [13:0]  | 14    | signed immediate (I-type)                |
| `imm20`  | [20:1]  | 20    | upper immediate (`LUI` only)             |

**Opcode map** — the single authoritative list of ALU-slot opcodes:

| Opcode   | Mnemonic   | Operands          | Description                                      | Layout |
|----------|------------|-------------------|--------------------------------------------------|--------|
| `000000` | `NOP`      | —                 | no operation                                     | §3     |
| `000001` | `ADD`      | `rd, rs1, rs2`    | `rd <- rs1 + rs2`                                | §3.2   |
| `000010` | `ADDI`     | `rd, rs1, imm14`  | `rd <- rs1 + sign_ext(imm14)`                    | §3.3   |
| `000011` | `SUB`      | `rd, rs1, rs2`    | `rd <- rs1 - rs2`                                | §3.2   |
| `000100` | `AND`      | `rd, rs1, rs2`    | `rd <- rs1 & rs2`                                | §3.2   |
| `000101` | `ANDI`     | `rd, rs1, imm14`  | `rd <- rs1 & sign_ext(imm14)`                    | §3.3   |
| `000110` | `OR`       | `rd, rs1, rs2`    | `rd <- rs1 \| rs2`                               | §3.2   |
| `000111` | `ORI`      | `rd, rs1, imm14`  | `rd <- rs1 \| sign_ext(imm14)`                   | §3.3   |
| `001000` | `XOR`      | `rd, rs1, rs2`    | `rd <- rs1 ^ rs2`                                | §3.2   |
| `001001` | `XORI`     | `rd, rs1, imm14`  | `rd <- rs1 ^ sign_ext(imm14)`                    | §3.3   |
| `001010` | `SLT`      | `rd, rs1, rs2`    | `rd <- (rs1 <  rs2) signed ? 1 : 0`              | §3.2   |
| `001011` | `SLTI`     | `rd, rs1, imm14`  | `rd <- (rs1 < sign_ext(imm14)) signed ? 1 : 0`   | §3.3   |
| `001100` | `SLTU`     | `rd, rs1, rs2`    | `rd <- (rs1 <  rs2) unsigned ? 1 : 0`            | §3.2   |
| `001101` | `SLTIU`    | `rd, rs1, imm14`  | `rd <- (rs1 < sign_ext(imm14)) unsigned ? 1 : 0` | §3.3   |
| `001110` | `SLL`      | `rd, rs1, rs2`    | `rd <- rs1 << rs2[4:0]`                          | §3.2   |
| `001111` | `SLLI`     | `rd, rs1, shamt`  | `rd <- rs1 << shamt`                             | §3.3   |
| `010000` | `SRL`      | `rd, rs1, rs2`    | `rd <- rs1 >> rs2[4:0]` (logical)                | §3.2   |
| `010001` | `SRLI`     | `rd, rs1, shamt`  | `rd <- rs1 >> shamt` (logical)                   | §3.3   |
| `010010` | `SRA`      | `rd, rs1, rs2`    | `rd <- rs1 >> rs2[4:0]` (arithmetic)             | §3.2   |
| `010011` | `SRAI`     | `rd, rs1, shamt`  | `rd <- rs1 >> shamt` (arithmetic)                | §3.3   |
| `010100` | `MUL`      | `rd, rs1, rs2`    | `rd <- (rs1 * rs2)[31:0]`                        | §3.2   |
| `010101` | `MULH`     | `rd, rs1, rs2`    | `rd <- (rs1 * rs2)[63:32]` (signed × signed)     | §3.2   |
| `010110` | `INV_SQRT` | `rd, rs1`         | `rd <- ≈ 1/sqrt(rs1)`                            | §3.5   |
| `010111` | `LUI`      | `rd, imm20`       | `rd <- imm20 << 12`                              | §3.4   |

Reserved: opcodes `011000`–`111111` (40 entries). Executing a reserved opcode
raises an **illegal-instruction trap** (same entry path as `TRAP`; `trap_code`
in `ABI.md`) — the assembler must never emit one. This reserved space is the
landing zone for the proposed DSP extensions in §7 (non-normative).

**Notes:**
- `rs1`, `rs2` are **7-bit** global register addresses
  (`bank[2:0]` + `reg[4:0]`); `rd` is **5-bit** (bank implicit from the slot).
- `imm14` is signed, sign-extended to 32 bits → range **±8191**. All I-type
  immediates (including the logic ops) sign-extend.
- `shamt` in `SLLI`/`SRLI`/`SRAI` is `imm14[4:0]` (0–31); the assembler must
  emit 0 in `imm14[13:5]`.
- Register and immediate forms are **distinct opcodes** (no format bit).
- `SUB`, `MUL`, `MULH`, `INV_SQRT` have **no immediate form**
  (`SUBI x` = `ADDI -x`).

### 3.2 R-type format (register–register)

| [31:26]   | [25:21] | [20:14] | [13:7] | [6:0]    |
|-----------|---------|---------|--------|----------|
| opcode(6) | rd(5)   | rs1(7)  | rs2(7) | funct(7) |

- `funct(7)` refines the operation / reserves room for future 3-operand forms;
  the base ops are fully selected by `opcode`, so the assembler emits `0`.

### 3.3 I-type format (register–immediate)

| [31:26]   | [25:21] | [20:14] | [13:0]    |
|-----------|---------|---------|-----------|
| opcode(6) | rd(5)   | rs1(7)  | imm14(14) |

- `imm14` is signed, sign-extended to 32 bits → range **±8191**.

### 3.4 LUI format (U-type)

| [31:26]  | [25:21] | [20:1]    | [0]       |
|----------|---------|-----------|-----------|
| `010111` | rd(5)   | imm20(20) | unused(1) |

- `rd <- imm20 << 12` (low 12 bits zero).

### 3.5 INV_SQRT

| [31:26]  | [25:21] | [20:14] | [13:0]      |
|----------|---------|---------|-------------|
| `010110` | rd(5)   | rs1(7)  | unused(14)  |

- `rd <- ≈ 1/sqrt(rs1)`; latency 5 — the deepest operation, and therefore
  the widest gap the compiler must leave before a consumer.
- **Open item:** the operand domain and result number format (integer vs
  Q-format fixed point), the approximation precision, and the behaviour for
  `rs1 = 0` / negative inputs are **not yet specified**. They must be pinned
  down (together with `ABI.md`) before ISS/RTL implementation.

---

## 4. Latency Contract Summary (ALU Slot)

| Instruction              | Result available (VLIW words after issue) |
|--------------------------|--------------------------------------------|
| `ADD`/`SUB`/logic/`SLT*` | `rd` at W + 2                              |
| `LUI`                    | `rd` at W + 2                              |
| `SLL`/`SRL`/`SRA` (`*I`) | `rd` at W + 3                              |
| `MUL`/`MULH`             | `rd` at W + 4                              |
| `INV_SQRT`               | `rd` at W + 5                              |

These are the `BRAM_OUT_REG = 0` baseline values and they are a **correctness
contract**: the core has no interlock (ARCHITECTURE.md §No Interlock), so a
consumer scheduled earlier reads the destination's previous content, silently.
Two writes to one register must also be ordered by the compiler — latencies
differ, so a `MUL` (W+4) issued before an `ADD` (W+2) lands *after* it.

---

## 5. Scoreboard Interaction

- Each ALU slot is the **single writer** of its own bank, so WAW hazards and
  write-port structural conflicts stay local to that bank
  (ARCHITECTURE.md §Scoreboard).
- **Structural conflicts are real** in this slot because latencies differ:
  e.g. `INV_SQRT` issued at W (retires W + 5) and a shift issued at W + 2
  (retires W + 5) would land on the bank's single write port in the same
  cycle. The per-bank `wbres` delay line detects this at issue and stalls the
  younger op — no compiler action required for correctness.
- Cross-bank RAW (an ALU op reading another slot's in-flight result) is covered
  by the `busy` bits, as for every slot.

---

## 6. Pseudo-instructions and constant generation

| Pseudo        | Real instruction      | Meaning                    |
|---------------|-----------------------|----------------------------|
| `NOP`         | opcode `000000`       | empty slot (dedicated NOP) |
| `MOV rd, rs`  | `ADD rd, r0, rs`      | register copy              |
| `NEG rd, rs`  | `SUB rd, r0, rs`      | negate                     |
| `NOT rd, rs`  | `XOR rd, rs, -1`      | bitwise not                |
| `LI rd, imm`  | `ADDI rd, r0, imm14`  | load small immediate (±8191) |

**32-bit constant generation (2 VLIW words):**

```
LUI  rd, imm20        # rd = imm20 << 12
ADDI rd, rd, imm12    # rd = rd + low 12 bits
```

Because `ADDI` carries a **14-bit** immediate, the low 12 bits can always be
added as a *positive* value 0–4095 — no RISC-V-style `%hi` carry adjustment is
needed when bit 11 of the low part is set.

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
multiplier or `INV_SQRT` register depth for `fmax` changes the contract and
requires the kernels to be rebuilt.
