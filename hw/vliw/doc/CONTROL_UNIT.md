# VLIW Control Unit Specification

> **Status note — interrupts and traps removed.** The core neither takes
> interrupts nor traps (ARCHITECTURE.md §Faults and Host Control): work is
> dispatched by polling between kernels, and a fault **halts** the core for
> the host to inspect. `ERET` is gone, `TRAP` is a deliberate halt, and a
> reserved opcode halts with cause `ILLEGAL`. Nothing preempts a running
> kernel, so there is no saved PC, no handler and no resume — the only
> flushes left are the loop skip and `LCLR`.
>
> **Branch shadow.** Its words are **architectural delay slots** the compiler
> must fill (§5.1); they are not squashed. Inside a hardware loop this
> constrains where a redirect may sit — see the placement rule in §4.4.

## 1. Overview

The Control Unit is responsible for:

- Program Counter (PC) sequencing
- Conditional branches, jumps, calls and returns
- **Single-context zero-overhead hardware loop** for the innermost loop of
  tensor / DSP kernels (see §4)
- Writing the link register `rd` into the bank assigned to the Control slot
  (see `ABI.md` for the symbolic register naming conventions)
- A **lightweight integer ALU** (`ADD/SUB/ADDI`, `AND/OR/XOR/ANDI`, `SLT*`) for
  address, loop-counter and condition arithmetic — it offloads pointer/index
  math from the ALU slots and, in a hardware-loop body, uses the otherwise-idle
  control slot (see §3.9)

It is a single-issue slot: at most one control instruction executes per VLIW
word.

---

## 2. Register File Interface

The Control Unit is one of the four "issue slots". From its point of view the
register file exposes:

| Port           | Count | Width                               | Purpose                                    |
|----------------|-------|-------------------------------------|--------------------------------------------|
| Read ports     | **2** | 8-bit addr (3-bit bank + 5-bit reg) | `rs1`/`rs2` for branches, JALR, LOOP, CMOV, integer ALU |
| Write port     | **1** | 5-bit addr, bank implicit from slot | `rd` for JAL/JALR/CMOV, integer ALU      |

Rationale for **2 read / 1 write**:

| Instruction class | rd  | rs1 | rs2       |
|-------------------|-----|-----|-----------|
| Branch (B-type)   | no  | yes | yes       |
| JAL               | yes | no  | no        |
| JALR              | yes | yes | no        |
| SYSTEM/LOOP       | no  | yes (LOOP only) | no  |
| CMOV              | yes | yes (rs_cond) | yes (rs_src) |
| CMOVI             | yes | yes (rs_cond) | no  |
| Integer ALU R     | yes | yes | yes       |
| Integer ALU I     | yes | yes | no        |

Maximum simultaneous demand = 2 reads, 1 write — covered by the existing
port allocation. The worst cases are `CMOV` (reads `rs_cond` + `rs_src`) and the
integer ALU R-type (reads `rs1` + `rs2`); both fit the 2 read ports exactly, so
the integer ALU adds no new port pressure.
The two read ports of the control slot are **independent of** the read ports
of the ALU/LS slots. The exact port count of the shared register file is not
fixed by this document; the implementation lives in `../lib/vliwrf` and must
provide at least the per-slot ports summarized above (2 read + 1 write for
the Control slot, plus the per-slot ports the ALU/LS slots require). Nothing
preempts a kernel, so no context-save path and no dedicated ports for one
exist (ARCHITECTURE.md §Faults and Host Control).

---

## 3. Instruction Set

Control instructions are encoded in a **36-bit slot** with a single flat 6-bit
opcode:

```
[35:30]    [29:0]
opcode(6)  payload(30)
```

| Field     | Bits    | Description                                              |
|-----------|---------|----------------------------------------------------------|
| `opcode`  | [35:30] | 6-bit instruction selector (control-slot local space)    |
| `payload` | [29:0]  | 30 bits, layout is opcode-specific                       |

There is no format bit: register and immediate forms of an operation (e.g.
`CMOV` / `CMOVI`) are **distinct opcodes**.

**NOP** is encoded as `opcode = 000000`. It is the canonical no-operation and
the preferred form for an empty control slot; the assembler emits the all-zero
word `0x000000000` for unused control slots.

### 3.1 Encoding reference card

All instructions are 36 bits: `opcode[35:30] | payload[29:0]`.
`x` = don't-care, assembler emits `0`. All targets are signed VLIW-word offsets.

**Fixed field positions (where applicable):**

| Field        | Bits              | Width | Notes                                    |
|--------------|-------------------|-------|------------------------------------------|
| `opcode`     | [35:30]           | 6     | instruction selector                     |
| `rd`         | [29:25]           | 5     | dest register, bank implicit from slot   |
| `rs1`        | [7:0]             | 8     | source 1 — read rail 1 (all forms)       |
| `rs_cond`    | [7:0]             | 8     | condition register (CMOV / CMOVI) — rail 1 |
| `rs2`        | [15:8]            | 8     | source 2 (branches, R-type) — read rail 2 |
| `rs_src`     | [15:8]            | 8     | source register (CMOV only) — rail 2     |
| `imm17`      | [24:8]            | 17    | signed immediate (JALR / CMOVI / I-type) |
| `end_off`    | [23:8]            | 16    | signed loop body offset (LOOP / LOOPI)   |
| `target(14)` | [29:16]           | 14    | signed branch offset                     |
| `count`      | {[29:24], [7:0]}  | 14    | unsigned iteration count (LOOPI only)    |
| `target(25)` | [24:0]            | 25    | signed jump offset (JAL only)            |
| `trap_code`  | [29:0]            | 30    | software trap payload (TRAP only)        |

Both sources now sit on fixed **rails** — the two low bytes — for *every*
instruction including the branches, which a 32-bit slot could not afford
(they used to carry `rs1`/`rs2` at `[25:19]`/`[18:12]`, off the rails used
by `JALR`/`LOOP`/`CMOV`). Each read port therefore takes its address from
one constant slice, with no per-opcode multiplexer, the same discipline as
the ALU and LS slots.

Note: `imm17` and `end_off` both start at bit 8, so they share one
extraction alignment and differ only in where the sign bit sits (24 vs 23);
`count` is the only split field, reassembled by fixed wiring.

**Opcode map** — the single authoritative list of control-slot opcodes
(operands in source-to-destination order; full bit layouts in §3.2–§3.8):

| Opcode   | Mnemonic | Operands              | Description                                      | Layout |
|----------|----------|-----------------------|--------------------------------------------------|--------|
| `000000` | `NOP`    | —                     | no operation                                     | §3     |
| `000001` | `BEQ`    | `rs1, rs2, target`    | branch if `rs1 == rs2`                           | §3.2   |
| `000010` | `BNE`    | `rs1, rs2, target`    | branch if `rs1 != rs2`                           | §3.2   |
| `000011` | `BLT`    | `rs1, rs2, target`    | branch if `rs1 <  rs2` (signed)                  | §3.2   |
| `000100` | `BGE`    | `rs1, rs2, target`    | branch if `rs1 >= rs2` (signed)                  | §3.2   |
| `000101` | `BLTU`   | `rs1, rs2, target`    | branch if `rs1 <  rs2` (unsigned)                | §3.2   |
| `000110` | `BGEU`   | `rs1, rs2, target`    | branch if `rs1 >= rs2` (unsigned)                | §3.2   |
| `000111` | `JAL`    | `rd, target`          | jump and link; `rd = PC + 1`                     | §3.3   |
| `001000` | `JALR`   | `rd, rs1, imm17`      | jump to `rs1 + imm17`; `rd = PC + 1`             | §3.4   |
| `001001` | `TRAP`   | `trap_code`           | halt the core, cause `SOFTWARE`, `trap_code` latched for the host | §3.6   |
| `001011` | `LOOP`   | `rs1, end_off`        | arm hardware loop, count from `rs1`              | §3.5   |
| `001100` | `LCLR`   | —                     | abort the active hardware loop                   | §3.5   |
| `001110` | `CMOV`   | `rd, rs_cond, rs_src` | if `rs_cond != 0`: `rd <- rs_src`                | §3.8   |
| `001111` | `LOOPI`  | `count, end_off`      | arm hardware loop, immediate count               | §3.5   |
| `010001` | `CMOVI`  | `rd, rs_cond, imm17`  | if `rs_cond != 0`: `rd <- sign_ext(imm17)`       | §3.8   |
| `010010` | `ADD`    | `rd, rs1, rs2`        | `rd <- rs1 + rs2`                                | §3.9   |
| `010011` | `SUB`    | `rd, rs1, rs2`        | `rd <- rs1 - rs2`                                | §3.9   |
| `010100` | `ADDI`   | `rd, rs1, imm17`      | `rd <- rs1 + sign_ext(imm17)`                    | §3.9   |
| `010101` | `AND`    | `rd, rs1, rs2`        | `rd <- rs1 & rs2`                                | §3.9   |
| `010110` | `OR`     | `rd, rs1, rs2`        | `rd <- rs1 \| rs2`                               | §3.9   |
| `010111` | `XOR`    | `rd, rs1, rs2`        | `rd <- rs1 ^ rs2`                                | §3.9   |
| `011000` | `ANDI`   | `rd, rs1, imm17`      | `rd <- rs1 & sign_ext(imm17)`                    | §3.9   |
| `011001` | `SLT`    | `rd, rs1, rs2`        | `rd <- (rs1 <  rs2) signed ? 1 : 0`              | §3.9   |
| `011010` | `SLTU`   | `rd, rs1, rs2`        | `rd <- (rs1 <  rs2) unsigned ? 1 : 0`            | §3.9   |
| `011011` | `SLTI`   | `rd, rs1, imm17`      | `rd <- (rs1 < sign_ext(imm17)) signed ? 1 : 0`   | §3.9   |
| `011100` | `SLTIU`  | `rd, rs1, imm17`      | `rd <- (rs1 < sign_ext(imm17)) unsigned ? 1 : 0` | §3.9   |

Reserved: opcodes `001010` (formerly `ERET`), `001101` and `010000` (formerly
`MOV` and `MOVI`, now pseudo-instructions — §3.7), and `011101`–`111111` (38
entries in total). Executing a reserved opcode
**halts the core** with cause `ILLEGAL` (ARCHITECTURE.md §Faults and Host
Control) — the assembler must never emit one.

**Notes:**
- `rs1`, `rs2`, `rs`, `rs_cond`, `rs_src` are **8-bit** global register
  addresses (`bank[2:0]` + `reg[4:0]`).
- `rd` is **5-bit** (bank implicit from the slot).
- `imm17` and `end_off` both start at bit 8, signed, sign-extended to 32
  bits by one shared alignment; the branch `target` sits at `[29:16]`
  because a branch spends both read rails on `rs1`/`rs2`.
- `count(14)` in `LOOPI` is **unsigned**, range 0–16383 (0 = skip loop).
- Branch `target(14)` → **±8191 VLIW words**.
- JAL `target(25)` → **±16M VLIW words**.
- JALR offset `imm17` → **±65535** words from `rs1`.
- `end_off(16)` → loop body up to **32767 VLIW words**.
- `trap_code(30)` allocation defined in `ABI.md`.
- Register and immediate forms are **distinct opcodes** (no format bit):
  `LOOP`/`LOOPI`, `CMOV`/`CMOVI`.
- Branches have **no link register** — use `JAL` for branch-and-link.
- All PC arithmetic (`PC + 1`, branch/jump targets, `rs1 + imm17`) is performed
  **modulo `2^IMEM_DEPTH_LOG2`** — targets are truncated to the PC width.
- The control-slot **integer ALU** (`ADD`…`SLTIU`) writes `rd` into the control
  bank and reuses the 2-read/1-write ports; it is a simple fast unit (no
  multiply, no shift) — see §3.9.

### 3.2 Branch format

| [35:30]   | [29:16]    | [15:8] | [7:0]  |
|-----------|------------|--------|--------|
| opcode(6) | target(14) | rs2(8) | rs1(8) |

- `target`: signed 14-bit VLIW-word offset → range **±8191 VLIW words**
- Shadow = `BRANCH_SHADOW` VLIW words of **architectural delay slots**: they
  execute whether or not the branch is taken, and the compiler must fill them
  — with `NOP`s if it has nothing to hoist (see §5.1). Its exact size is not
  yet finalized (see §8), and fixing it is an ISA decision.
- No link register. Use `JAL` for branch-and-link.
- For longer-range conditional branches: load target into a register and use
  a conditional skip + `JAL` pattern (compiler responsibility).

### 3.3 JAL format

| [35:30]   | [29:25] | [24:0]     |
|-----------|---------|------------|
| `000111`  | rd(5)   | target(25) |

- `target`: signed 25-bit VLIW-word offset → **±16M VLIW words**
- `rd = PC + 1` (link register; use `r0` to discard)

### 3.4 JALR format

| [35:30]   | [29:25] | [24:8]    | [7:0]  |
|-----------|---------|-----------|--------|
| `001000`  | rd(5)   | imm17(17) | rs1(8) |

- `PC = rs1 + sign_ext(imm17)`
- `rd = PC + 1` (use `r0` to discard)


### 3.5 LOOP / LOOPI format

`LOOP` (register count) and `LOOPI` (immediate count) are distinct opcodes.

Register form (`LOOP`, opcode `001011`):

| [35:30]   | [29:24]   | [23:8]      | [7:0]  |
|-----------|-----------|-------------|--------|
| `001011`  | unused(6) | end_off(16) | rs1(8) |

Immediate form (`LOOPI`, opcode `001111`):

| [35:30]   | [29:24]      | [23:8]      | [7:0]       |
|-----------|--------------|-------------|-------------|
| `001111`  | count[13:8]  | end_off(16) | count[7:0]  |

- `end_off` sits at the same bits in both forms; `count` is split around it
  so that the loop-body offset keeps a single extraction path. Reassembly
  is fixed wiring and costs nothing at run time.
- `end_off` is a signed 16-bit VLIW-word offset from the `LOOP` instruction to the last instruction of the loop body (inclusive).
- `count(14)` in `LOOPI` is unsigned, range 0–16383; `count = 0` skips the loop body (0 iterations).
- See §4 for full hardware loop semantics.

---

### 3.6 TRAP format

| [35:30]   | [29:0]        |
|-----------|---------------|
| `001001`  | trap_code(30) |

- `trap_code` allocation defined in `ABI.md`.
- **`TRAP` halts the core.** It is not a call: there is no handler and no
  resume. The core stops fetching, latches cause `SOFTWARE` together with
  `trap_code` and the bundle's PC, and raises `faulted` in the status word the
  NI reads (ARCHITECTURE.md §Faults and Host Control). Its uses are assertions
  and breakpoints — a kernel that reaches an impossible state stops where the
  host can see it, rather than continuing silently.
- Earlier in-flight results retire normally, so the register file the host
  inspects is the one the faulting bundle saw.

---

### 3.7 Register move — pseudo-instructions

The control slot has **no `MOV` / `MOVI` opcode**. Its integer ALU (§3.9)
already produces both, exactly and at the same cost:

| Pseudo          | Expansion             | Meaning                    |
|-----------------|-----------------------|----------------------------|
| `MOV  rd, rs`   | `ADD  rd, r0, rs`     | register copy              |
| `MOVI rd, imm`  | `ADDI rd, r0, imm17`  | load immediate (±65535)    |

`XOR rd, rs, r0` is an equally valid expansion of the register form; the
assembler emits the `ADD` variant for consistency with the ALU slots
(`ALU.md` §6).

Earlier revisions did carry real `MOV` (`001101`) and `MOVI` (`010000`)
opcodes. They predate the control-slot integer ALU and became redundant when
it was added — and they were also **slower**, retiring at `W + 2` against the
integer ALU's `W + 1`, so the pseudo-instruction strictly dominated the
instruction it replaced. Both code points are now reserved.

Note that the LS slot keeps a **real** `MOV` (`LOAD_STORE.md` §3.9): it owns
no ALU, so it has nothing to synthesise the move from.

### 3.8 CMOV / CMOVI format

Register form (`CMOV`, opcode `001110`):

| [35:30]   | [29:25] | [24:16]    | [15:8]     | [7:0]      |
|-----------|---------|------------|------------|------------|
| `001110`  | rd(5)   | unused(9)  | rs_src(8)  | rs_cond(8) |

Immediate form (`CMOVI`, opcode `010001`):

| [35:30]   | [29:25] | [24:8]    | [7:0]       |
|-----------|---------|-----------|-------------|
| `010001`  | rd(5)   | imm17(17) | rs_cond(8)  |

- if `rs_cond != 0`: `rd <- rs_src` (or `sign_ext(imm17)`)
- if `rs_cond == 0`: `rd` is **not written** — retains its previous value
- Condition is evaluated in EX1; write-enable to the register file is gated
  by the condition result — one AND gate, no extra pipeline stage
- Latency: 2 cycles
- `rd`, `rs_cond`, `rs_src` follow the same bank rules as MOV
- **Scoreboard**: `rd`'s `busy` / `wbres` reservation is made at issue and
  released on its scheduled write-back cycle **whether or not** the condition
  fires — a suppressed write only masks the write-enable, so `rd` never gets
  stuck busy and a waiting reader observes the retained value.

### 3.9 Integer ALU operations (address / counter / condition)

The control slot carries a **lightweight integer ALU** so pointer, loop-counter
and condition arithmetic can run here instead of stealing an ALU slot — in a
hardware-loop inner body the control slot is otherwise idle, so this work is
effectively free. It is deliberately **simple and fast**: `ADD/SUB/ADDI`,
`AND/OR/XOR/ANDI`, and `SLT/SLTU/SLTI/SLTIU` — **no multiply, no shift** (those
stay in the ALU slots, ARCHITECTURE.md §ALU Slot).

Register form (`ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLT`, `SLTU`):

| [35:30]   | [29:25] | [24:16]   | [15:8] | [7:0]  |
|-----------|---------|-----------|--------|--------|
| opcode(6) | rd(5)   | unused(9) | rs2(8) | rs1(8) |

Immediate form (`ADDI`, `ANDI`, `SLTI`, `SLTIU`):

| [35:30]   | [29:25] | [24:8]    | [7:0]  |
|-----------|---------|-----------|--------|
| opcode(6) | rd(5)   | imm17(17) | rs1(8) |

- `rd` is written into the **control bank** (bank 4, implicit); `rs1`/`rs2` are
  8-bit global reads (any bank), so operands may come from any slot's bank.
- `imm17` is signed and shares the bit-8 sign-extend alignment with the other
  control-slot immediates (§3.1); range **±65535**.
- `SLT*` write `1`/`0` and thus **materialize a condition for `CMOV`/`CMOVI`**
  without borrowing an ALU slot.
- `ANDI`/`AND` give **power-of-2 circular addressing** for free:
  `ptr <- (ptr + step) & mask` — no dedicated modulo hardware.
- **Latency (design intent): `rd` at W + 1** — produced in EX1 on the same fast
  path as the `JAL`/`JALR` link, one cycle earlier than the ALU slots' `ADD`
  (W + 2). This keeps a loop-carried pointer/counter recurrence at **1
  cycle/iteration**. Like `BRANCH_SHADOW`, this latency is advisory (the
  the compiler must respect the real latency); if timing closure forces W + 2, the
  recurrence is 2 and must be hidden by software pipelining.
- Only one control instruction issues per VLIW word, so a bundle cannot both
  branch and do integer arithmetic in the control slot. Inner (hardware) loops
  do not branch, so the slot is free there; outer loops have ALU slack.

---

## 4. Hardware Loop

### 4.1 Goals and scope

Zero-overhead **innermost** loop for tensor / DSP kernels: no test, no
decrement, no branch shadow inside the loop body. Outer loops use ordinary
`BNEZ`-style code with the standard branch shadow (`BRANCH_SHADOW`) — outer-loop
overhead is amortized over many inner iterations, so it does not need
hardware support.

There is **exactly one** hardware loop context. It is not nested.

### 4.2 Loop Context

The Control Unit owns one set of state:

| Field         | Width                | Description                              |
|---------------|----------------------|------------------------------------------|
| `loop_active` | 1                    | A loop is currently armed                |
| `loop_start`  | `IMEM_DEPTH_LOG2`    | First VLIW word of the body              |
| `loop_end`    | `IMEM_DEPTH_LOG2`    | Last VLIW word of the body               |
| `loop_count`  | 32                   | Remaining iterations (down-counter)      |

Total: ~90 FFs. One comparator drives the back-edge.

### 4.3 LOOP / LOOPI — arm the loop

`LOOP rs1, end_off` — iteration count comes from register `rs1`
`LOOPI count, end_off` — iteration count is a 14-bit unsigned immediate (`count` at [25:12])

Payload encoding: see §3.5 for the full bit layout of both forms.

Semantics (executed at PC = `Wloop`):

```
if (count == 0) {
    // empty loop: cancel any active loop, skip the body, do not arm
    loop_active <- 0
    PC          <- Wloop + end_off + 1
} else {
    loop_start  <- Wloop + 1
    loop_end    <- Wloop + end_off
    loop_count  <- count
    loop_active <- 1
    PC          <- Wloop + 1     // fall through
}
```

These writes happen at EX1 and initialise **both** the committed and
speculative copies of `loop_active` / `loop_count` (§4.4); the catch-up below
may then adjust the speculative copies only.

- `end_off` is a signed 12-bit VLIW-word offset from the `LOOP` instruction
  to the **last** word of the loop body → bodies up to 2047 VLIW words.
- `LOOP` (register form) reads `rs1` through control-slot read port 0.
- **No branch shadow**: arming the loop does not redirect the PC (the skip
  path with `count == 0` does carry a `BRANCH_SHADOW`-word shadow).
- Issuing a new `LOOP`/`LOOPI` **always overwrites** the loop context,
  regardless of whether the new loop is taken or skipped. This means:
   - **Cancel + re-arm** is just a fresh `LOOP`/`LOOPI`.
   - **Cancel without re-arming** is `LCLR` — equivalent to `LOOPI 0, 0`
     but preferred for readability.
   - Inner loops can be re-armed every outer iteration without any explicit
     clear in between.

**Short-body arming catch-up.** The loop context is written when
`LOOP`/`LOOPI` reaches EX1, but the back-edge comparator (§4.4) watches
`next_pc` at the **front end** — and by arm time the front end has already
fetched the next `BRANCH_SHADOW` sequential words. If the body is not longer
than the front end (`end_off ≤ BRANCH_SHADOW`), the first
`next_pc == loop_end + 1` transition passes **before** `loop_active` is set,
and the first back-edge would be silently missed. The hardware therefore
performs a **catch-up** at arm time (`count > 0`, after arming):

```
if (fetch_pc > loop_end) {            // front end already fetched past the body
    if (count == 1) {
        loop_active_spec <- 0         // in-flight fall-through is the correct path
                                      // (committed copies retire normally, §4.4)
    } else {
        flush in-flight words with pc > loop_end   // reuses the branch flush (§5.1)
        loop_count_spec <- count - 1  // credit: iteration 1 is already in flight
                                      // (committed count stays N, §4.4)
        PC              <- loop_start // refetch from iteration 2
    }
}
```

Nothing can preempt the arm: there are no interrupts, and a fault halts the
core outright rather than flushing and resuming (ARCHITECTURE.md §Faults and
Host Control). The only flushes are the ones listed in the reload rule below.

- Exactly **one** copy of the body is in flight at arm time (fetch was purely
  sequential), so the decrement is always by one.
- Cost: a ≤ `BRANCH_SHADOW`-cycle bubble **once per loop entry**, and only for
  short bodies; a body longer than the front end arms with zero cost, and the
  **steady state is unaffected in all cases** — even a 1-word body back-edges
  every cycle with zero overhead (illustrated in §9).
- Rationale: the alternative — a minimum body length with assembler `NOP`
  padding — would make correctness depend on inserted NOPs and freeze the
  front-end depth (`BRAM_OUT_REG`, ARCHITECTURE.md §Memory Model) into
  binaries. With the shadow exposed (§5.1) the compiler already emits explicit
  padding after a branch; keeping the catch-up in hardware avoids extending
  that obligation to the *loop body*, whose minimum length would otherwise be
  a front-end parameter.

### 4.4 Implicit back-edge — end-of-loop

There is **no explicit end-of-loop instruction in the body**. Each cycle the
hardware tests, on the next-PC datapath (using the **speculative** copies of
the loop state — see below):

```
back_edge = loop_active_spec && (next_pc == loop_end + 1)

if (back_edge) {
    if (loop_count_spec > 1) {
        loop_count_spec <- loop_count_spec - 1
        PC              <- loop_start        // zero-overhead back-jump
    } else {
        loop_active_spec <- 0                // loop done
        PC               <- loop_end + 1     // fall through
    }
}
```

Because the test is performed on `next_pc` (one cycle ahead of fetch), the
back-edge does **not** incur a branch shadow.

**The comparator is an equality test (normative).** It compares `next_pc`
against the single value `loop_end + 1`. It must **not** be a range test
(`next_pc > loop_end`, or a membership test on `[loop_start, loop_end]`).
The consequence is that the loop is oblivious to where the PC has been:
control may leave the body and re-enter it freely, and the loop stays armed
with its count untouched, because nothing fires until the program is about
to step past `loop_end`.

```asm
        LOOPI  10, end_off        ; loop_start = S, loop_end = E
S:      LW     r10, 0(r20)
        BEQZ   r11, special       ; rare case handled out of line
        ADD    r13, r13, r10      ; delay slots 1..3 (§5.1)
        ADDI   r20, r20, 4
        SW     r13, 0(r22)
back:   ...                       ; re-entry point, still inside the body
E:      ADDI   r21, r21, 4        ; loop_end
        ; back-edge fires on next_pc == E + 1

special:                          ; outside [loop_start, loop_end]
        ...                       ; arbitrary work, may itself branch
        JAL    r0, back           ; return into the body — loop still armed
```

A range comparator would break this twice over: it would fire the moment the
PC left `[loop_start, loop_end]`, and it would fire again on re-entry. With
the equality test, `special` may sit anywhere in IMEM and be of any length.

#### Committed vs. speculative loop state

The back-edge mutates the count and active flag at **fetch time** — before the
fetched iteration has executed. Fetch is still speculative with respect to the
remaining flushes — `LCLR` on an active loop (§4.5) and the short-body catch-up
(§4.3): decrements made for iterations that are later discarded and refetched
must not stick, or the loop silently runs short. A taken branch in the body is
**no longer** one of those cases — its shadow words execute as delay slots
(§5.1). The loop state is therefore split:

| Copy                                          | Lives at  | Mutated by                                   | Read by                          |
|-----------------------------------------------|-----------|----------------------------------------------|----------------------------------|
| `loop_count` / `loop_active` (**committed**)  | EX1       | arm / `LCLR` (EX1), commit rule below        | MMIO `LOOP_*` (§4.8), flush reload |
| `loop_count_spec` / `loop_active_spec` (**speculative**) | front end | back-edge/exit (above), arm, catch-up credit (§4.3) | back-edge comparator |

(`loop_start` / `loop_end` are written only at arm — commit time — and need no
second copy.)

**Commit rule (EX1).** The committed copies advance when a loop-body end word
actually retires:

```
// EX1 retirement
if (retires && bundle.pc == loop_end && loop_active && !redirect_taken) {
    if (loop_count > 1)  loop_count <- loop_count - 1
    else                 { loop_active <- 0; loop_count <- 0 }   // loop done
}
// '!redirect_taken': a taken branch at loop_end wins over the back-edge and
// must not decrement (§4.10) — mirroring the front-end rule, which only
// fires when the next PC is the sequential loop_end + 1.
```

**Reload rule (any flush).** Every `flush` — taken branch / jump, loop-skip,
`LCLR` with an active loop (§4.5) — reloads the speculative copies from the
committed ones. A fault is not in this list: it stops the core, and the
committed copies are what the host then reads.

```
loop_count_spec  <- loop_count
loop_active_spec <- loop_active
```

This is exact: at flush time nothing younger than EX1 survives, so the
committed values are precisely the state at the resume point; refetched
iterations then re-decrement the speculative copy legitimately. MMIO reads
(`LOOP_COUNT`, `LOOP_ACTIVE`) return the **committed** copies, so a host
reading a halted core sees loop state consistent with `FAULT_PC`.

#### Redirect placement near `loop_end` (normative)

A PC-redirecting instruction — taken branch, `JAL`, `JALR` — must **not** be
placed in the last `BRANCH_SHADOW` words of a loop body.

The reason is that the back-edge is computed at fetch. By the time such a
redirect resolves in EX1, the words sitting in IF/ID/RR are no longer the
instructions that follow it in memory: they are the **first words of the next
iteration**, already refetched from `loop_start`. Under §5.1 those words
execute, so an exit branch at `loop_end` silently runs a partial extra
iteration.

This is a correctness matter, not a cost one. Below, the two `LW`s that become
the delay slots would re-read with `r20` already advanced — past the end of the
array on the final iteration, which raises `OOB` and halts the core:

```asm
        LOOPI  10, end_off
S:      LW     r10, 0(r20)        ; ┐
        LW     r11, 0(r21)        ; │ these three are the delay slots
        MUL    r12, r10, r11      ; ┘ of a branch placed at E
        ADD    r13, r13, r12
        ADDI   r20, r20, 4
E:      BNEZ   r14, exit          ; ILLEGAL — redirect at loop_end
```

The fix is to hoist the test so the delay slots are ordinary body work:

```asm
        LOOPI  10, end_off
S:      LW     r10, 0(r20)
        LW     r11, 0(r21)
        MUL    r12, r10, r11
        BNEZ   r14, exit          ; at loop_end - BRANCH_SHADOW
        ADD    r13, r13, r12      ; delay slot 1 — real body work
        ADDI   r20, r20, 4        ; delay slot 2 — real body work
E:      ADDI   r21, r21, 4        ; delay slot 3 — real body work = loop_end
exit:   SW     r13, 0(r22)
```

No `NOP`, no wasted cycle, and the exit is clean: the exiting iteration
executes in full, exactly as a non-exiting one would. The obligation on the
compiler is that the exit condition be available `BRANCH_SHADOW` words before
`loop_end` — normally the case, since it comes from an `SLT*` or a counter
computed earlier in the body.

The rule constrains where a redirect **sits**, not where one may **land**: a
jump back into the body may target any word, including the last ones (§4.4
equality comparator, §4.7).

#### Pipeline-state illustrations

### 4.5 LCLR — abort the active loop

```
LCLR (EX1) ->  loop_active <- 0 ; loop_active_spec <- 0
               if (a loop was active) {
                   flush younger in-flight words    // they may have wrapped
                   refetch from PC + 1              // <= BRANCH_SHADOW bubble
               } else {
                   PC <- PC + 1                     // no flush, no bubble
               }
```

`LCLR` is used **before any control-flow transfer that takes the program
outside `[loop_start, loop_end]`** (early return, goto, longjmp,
multi-target branch). Without it, the dormant comparator could fire
spuriously if the program later happens to execute address `loop_end + 1`
while `loop_active` is still set.

**Why the flush?** `LCLR` clears the context at EX1, but the front end runs
`BRANCH_SHADOW` words ahead on the *speculative* context (§4.4): if `LCLR`
sits within `BRANCH_SHADOW` words of `loop_end`, fetch may already have taken
the back-edge and be streaming the next — now cancelled — iteration. Flushing
the younger words and refetching from `LCLR + 1` discards them and reloads the
speculative copies. With **no active loop** there is nothing to protect: no
flush, no bubble. `LCLR` sits on cold early-exit paths, so the one-time bubble
is negligible; it is typically followed by a `J`/`JAL`/branch carrying its own
`BRANCH_SHADOW` shadow.

### 4.6 Early exit and `continue`

Loop control-flow pseudo-instructions (`BREAK`, `REPEAT`, `REPEATR`) are
defined once in the master [Pseudo-instructions](#7-pseudo-instructions) table.

Note on `continue`-like behavior: the natural way to skip to the next
iteration is to jump to `loop_end + 1` — the back-edge comparator then fires,
decrements `loop_count`, and re-enters at `loop_start`. Jumping directly to
`loop_start` mid-body re-runs the **same** iteration (no decrement) and is
generally not what is wanted.

### 4.7 Interaction with arbitrary control flow

The loop comparator is an equality test on `loop_end + 1` (§4.4) and fires only
when the program is about to step past `loop_end`. It never inspects where the
PC currently is, so leaving the body is not in itself an event. Therefore:

- Branches inside the body that stay within `[loop_start, loop_end]`: **safe**
  by construction.
- Control transfer **out of the body that returns into it** — a call
  (`JAL`/`JALR`) to a function, an out-of-line slow path, a jump to a patch
  region: **safe, and needs no `LCLR`**. The loop stays armed with its count
  untouched for as long as the excursion lasts, however long that is and
  wherever it runs. This is the property the equality comparator exists to
  provide.
- Control transfer out of the body that **does not** return — abandoning the
  loop — must be preceded by `LCLR` (§4.5). Otherwise the loop remains armed
  and its comparator fires later, if and when the program happens to step onto
  `loop_end + 1` from unrelated code.
- Where a redirect may be **placed** is constrained near `loop_end` (§4.4,
  redirect placement rule); where it may **land** is not.

### 4.8 Loop context and the host

There are no interrupts and no trap handlers, so nothing can preempt a
running loop: the context needs no save/restore path and none is provided.
It is exposed to software only through the memory-mapped registers below,
for two uses — a kernel that wants to reprogram the loop explicitly, and a
host reading the state of a **halted** core after a fault.

#### Memory-mapped loop registers (top of DMEM address space)

The loop-context subset is shown here; the authoritative data-memory map is
`LOAD_STORE.md` §4.2.

| Offset from top | Name           | Width             | Access | Description           |
|-----------------|----------------|-------------------|--------|-----------------------|
| -9              | `LOOP_ACTIVE`  | 1                 | RW     | `loop_active` flag    |
| -8              | `LOOP_START`   | `IMEM_DEPTH_LOG2` | RW     | `loop_start`          |
| -7              | `LOOP_END`     | `IMEM_DEPTH_LOG2` | RW     | `loop_end`            |
| -6              | `LOOP_COUNT`   | 32                | RW     | `loop_count`          |

These access the **committed** loop state (§4.4). When a kernel writes them
to arm a loop by hand, `LOOP_ACTIVE` must be written **last**, so the
back-edge re-arms only once the other three are in place.

### 4.9 Design choices dropped vs. earlier drafts

For reference, this single-context design **deliberately omits**:

- Loop stack and `lsp`
- Nesting level field (`lvl`)
- `LEND` explicit marker; `BREAK`, `CONTINUE`, `LDROP` as primitive opcodes
- `LOOP_DEPTH` parameter
- Loop overflow / underflow / level-mismatch faults
- Automatic save/restore of the loop context (nothing preempts a loop)

Outer loops use plain `BNEZ` and pay the standard `BRANCH_SHADOW` branch
shadow. This overhead is amortized over the inner loop's iterations and is
negligible in practice.

### 4.10 Edge cases

- **Branch at `loop_end`**: if a taken branch (or `JAL`/`JALR`) sits in the
  last word of the loop body, the branch redirect wins over the back-edge:
  the branch is taken, `loop_count` is **not** decremented, and `loop_active`
  is unchanged. A not-taken branch lets the back-edge fire normally. This is
  a consequence of the next-PC priority list in §5. The committed count is
  protected by the `!redirect_taken` term of the commit rule, and any
  speculative wrap fetched behind the taken branch is undone by the flush
  reload (§4.4, second illustration).
- **`LCLR` within `BRANCH_SHADOW` words of `loop_end`**: fetch may already
  have wrapped on the speculative context; `LCLR`'s flush (§4.5) squashes the
  wrapped words — correct by construction, at the cost of its one-time
  bubble.
- **`LCLR` then immediate use of `loop_active`**: software inspecting
  `LOOP_ACTIVE` via MMIO right after `LCLR` sees the cleared value on the
  next load (no special forwarding needed; the MMIO read is itself a regular
  Load with the standard 2-cycle latency).
- **`LOOP` with `end_off ≤ 0`**: reserved (illegal). Behavior is
  implementation-defined; the assembler must reject it.
- **`LOOP` arming a body of length 1** (`end_off = 1`): legal; the single
  body word is both `loop_start` and `loop_end`. Entry goes through the
  arm-time catch-up (§4.3): iteration 1 is already in flight, the over-fetched
  fall-through words are flushed, and fetch restarts at `loop_start` with
  `loop_count - 1`; thereafter the back-edge fires every cycle with zero
  overhead.

---

## 5. PC Datapath

```
                +--------------+
                |   PC reg     |<---------+
                +------+-------+          |
                       | +1               |  next_pc mux
                       v                  |
        +------------------------+        |
        |   next_pc selector     |--------+
        +------------------------+
              ^   ^   ^   ^   ^   ^
              |   |   |   |   |   |
            seq  br  jal jalr loop_back
                                 (or loop_skip on LOOP with count==0)
```

Priority of next-PC selection (highest first):

1. Taken branch / `JAL` / `JALR`
2. **Loop back-edge** (`loop_active && next_pc == loop_end + 1`)
3. **Loop skip / short-body catch-up** (`LOOP`/`LOOPI` with `count == 0`, or
   armed with the front end already past `loop_end` — §4.3)
4. Sequential `PC + 1`

There is no override above these: `TRAP` and a fault do not select a next PC,
they **stop fetching** (ARCHITECTURE.md §Faults and Host Control).

The back-edge is computed on `next_pc` one cycle ahead of fetch and therefore
incurs **no shadow**. Branches, `JAL`, `JALR`, the loop skip
and the short-body catch-up (§4.3) all resolve in EX1; the `BRANCH_SHADOW`
words already fetched behind them are **architectural delay slots** that
execute (§5.1), so the compiler must fill them.

### 5.1 Branch shadow — architectural delay slots

Any control instruction that redirects the PC resolves in **EX1**. By then the
front end has already fetched the next `BRANCH_SHADOW` VLIW words (in IF/ID/RR).

Those words are **architectural delay slots**: they execute, unconditionally,
whether or not the redirect is taken. The hardware does not squash them and
inserts no bubble — the redirect only changes what is fetched *after* them.

Consequently the shadow is a **correctness obligation on the compiler**, not a
cost-model number:

- The compiler must fill every shadow slot, with explicit `NOP`s when it has
  no useful work to hoist. An unfilled shadow does not cost cycles, it
  executes whatever the assembler happened to place next.
- Work placed in the shadow of a **conditional** branch runs on both paths.
  That is exploitable — the fall-through prologue and the target prologue
  often share it — but it is the compiler's job to prove the work is safe on
  both.
- Work placed in the shadow of an **unconditional** transfer (`J`/`JAL`/
  `JALR`) always runs, so those slots are free scheduling space rather than a
  taken-branch penalty.

`BRANCH_SHADOW` is therefore **architectural**: it is baked into every binary,
and it cannot be a synthesis-time consequence of front-end depth. Changing
`BRAM_OUT_REG` (ARCHITECTURE.md §Memory Model) changes the fetch depth and so
would change the number of delay slots — which means the ISA must **fix**
`BRANCH_SHADOW` and the implementation must match it, not the reverse. Its
value is not yet finalized (§8); freezing it is now an ISA decision, not a
tuning knob.

Hot inner loops avoid the question entirely by using the hardware loop (§4):
the back-edge is computed at fetch and carries no shadow at all.

**No scoreboard interaction.** With the shadow executed rather than squashed
there is no wrong path after a branch, and with no interlock there are no
reservations to cancel. The squashed-reservation contract of `SCOREBOARD.md`
§6 applies to neither mechanism and is retained there as design rationale
only.

**No squash needed for:** the **loop back-edge** (resolved one cycle ahead on
`next_pc`, §4.4 — no shadow). `LCLR` *does* flush, but only when a loop is
active (§4.5).

**Cost.** Nothing on the branch path: with the shadow executed there are no
NOP-force muxes and no write-enable masks for a redirect. The `flush` signal
survives only for the loop cases above, where it reuses the same front-end
control as the lock-step stall (stall = *freeze* the front-end registers;
flush = *force them to NOP*).

---

## 6. Latency Contract Summary (Control Slot)

| Instruction      | Result available (VLIW words after issue) | Shadow      |
|------------------|-------------------------------------------|-------------|
| `BEQ`…`BGEU`     | —                                         | `BRANCH_SHADOW` |
| `JAL`            | `rd` at W + 1                             | `BRANCH_SHADOW` |
| `JALR`           | `rd` at W + 1                             | `BRANCH_SHADOW` |
| `LOOP`/`LOOPI`, count > 0 | —                                | 0 (short body: one-time catch-up, §4.3) |
| `LOOP`/`LOOPI`, count = 0 (skip) | —                         | `BRANCH_SHADOW` |
| Loop back-edge   | —                                         | 0           |
| `LCLR`           | —                                         | 0 (no loop) / ≤ `BRANCH_SHADOW` (active loop, §4.5) |
| `CMOV`/`CMOVI`   | `rd` at W + 2 (if written)               | 0           |
| Integer ALU (`ADD`…`SLTIU`) | `rd` at W + 1 (design intent, §3.9) | 0     |
| `TRAP`           | — (halts; fetch stops)                    | n/a         |

Every `BRANCH_SHADOW` entry above is a run of **architectural delay slots**
(§5.1): those words execute, so the compiler must fill them — with `NOP`s if
it has nothing to hoist. An unfilled shadow is a correctness bug, not a lost
optimization.

---

## 7. Pseudo-instructions

| Pseudo                       | Expansion                  | Notes                              |
|------------------------------|----------------------------|------------------------------------|
| `MOV  rd, rs`                | `ADD  rd, r0, rs`          | register copy (§3.7)               |
| `MOVI rd, imm`               | `ADDI rd, r0, imm17`       | load immediate (§3.7)              |
| `J target`                   | `JAL r0, target`           | unconditional jump                 |
| `CALL target`                | `JAL ra, target`           | subroutine call                    |
| `RET`                        | `JALR r0, ra, 0`           | return                             |
| `BEQZ rs, t`                 | `BEQ  rs, r0, t`           | branch if `rs == 0`                |
| `BNEZ rs, t`                 | `BNE  rs, r0, t`           | branch if `rs != 0`                |
| `BGT  rs1, rs2, t`           | `BLT  rs2, rs1, t`         | branch if `rs1 >  rs2` (signed)    |
| `BGTU rs1, rs2, t`           | `BLTU rs2, rs1, t`         | branch if `rs1 >  rs2` (unsigned)  |
| `BLE  rs1, rs2, t`           | `BGE  rs2, rs1, t`         | branch if `rs1 <= rs2` (signed)    |
| `BLEU rs1, rs2, t`           | `BGEU rs2, rs1, t`         | branch if `rs1 <= rs2` (unsigned)  |
| `BLTZ rs, t`                 | `BLT  rs, r0, t`           | branch if `rs <  0`                |
| `BGTZ rs, t`                 | `BLT  r0, rs, t`           | branch if `rs >  0`                |
| `BLEZ rs, t`                 | `BGE  r0, rs, t`           | branch if `rs <= 0`                |
| `BGEZ rs, t`                 | `BGE  rs, r0, t`           | branch if `rs >= 0`                |
| `BREAK end_label`            | `LCLR`; `J end_label`      | early exit from active HW loop     |
| `REPEAT n, body_words`       | `LOOPI n, body_words`      | inner tensor loop                  |
| `REPEATR rs, body_words`     | `LOOP rs, body_words`      | inner tensor loop, runtime count   |

---

## 8. Parameters

| Parameter       | Default | Description                          |
|-----------------|---------|--------------------------------------|
| `LOOP_CNT_W`    | 32      | Iteration counter width              |
| `BRANCH_SHADOW` | 3 (TBD) | VLIW words of **architectural delay slots** after any EX1-resolved redirect (§5.1) — they execute, and the compiler must fill them. Because it is architectural it is baked into binaries, so it cannot follow the fetch depth: the BRAM output-register choice (`BRAM_OUT_REG`, ARCHITECTURE.md §Memory Model) must be **fixed to match** the chosen value, not the reverse. Exact value **not yet finalized** — freezing it is an ISA decision. |

---

## 9. Example: 3-deep nested tensor loop

Only the **inner** loop uses the hardware loop. Outer loops use ordinary
`BNEZ`-style code; their 3-word branch shadows are amortized over the inner
iterations.

```asm
    LI    r1, N_OUT
outer:
    LI    r2, N_MID
mid:
    REPEATR r3, end_i - start_i    ; <- arms the HW loop with N_INN iter
start_i:
    ; ---- inner body: ONE VLIW word = 1 LS + 2 ALU + 1 ctl slot ----
    LW    r10, (r20)               ; LS slot
    MUL   r11, r10, r12            ; ALU slot 0
    ADD   r13, r13, r11            ; ALU slot 1
    ADDI  r20, r20, 4              ; control slot (integer ALU, §3.9)
end_i:
    ; ---- end of inner body (back-edge fires here, zero overhead) ----

    ADDI  r2, r2, -1
    BNEZ  r2, mid                  ; 3 delay slots follow — they execute on
    ADDI  r1, r1, -1               ;   BOTH paths (§5.1)
    NOP                            ; delay slot 2 (nothing safe to hoist here)
    NOP                            ; delay slot 3
    BNEZ  r1, outer                ; same: 3 delay slots below
    NOP
    NOP
    NOP
```

Note the explicit padding after each branch: the shadow words are
**architectural delay slots** (§5.1) and execute whether or not the branch is
taken, so the compiler must place something valid there. Here `ADDI r1, r1, -1`
is hoisted into the first slot of the inner branch — it is correct on both
paths — and the rest is padded.

Zero overhead in the **innermost** body (no compare, no decrement, no branch
shadow). The outer loops pay only the taken-branch bubble per iteration —
negligible compared to the hot inner work.

### What the hardware does at `REPEATR` (1-word body, arm-time catch-up)

The inner body above is a **single VLIW word** (`LS: LW`, `ALU0: MUL`,
`ALU1: ADD`, `CTRL: ADDI` — the pointer bump rides the control slot's integer
ALU, §3.9), so `end_off = 1 ≤ BRANCH_SHADOW` and loop entry goes through the
arm-time catch-up (§4.3):

```asm
    REPEATR r3, 1              ; arm: loop_start = loop_end = start_i
start_i:
    { LW r10,(r20) | MUL r11,r10,r12 | ADD r13,r13,r11 | ADDI r20,r20,4 }
after:
    SW    r13, (r21)           ; first word after the loop
```

```
fetch stream:   REPEATR, start_i, after, after+1      ; sequential over-fetch
                                                      ; (trigger next_pc ==
                                                      ;  loop_end+1 passes here,
                                                      ;  comparator not yet armed)
REPEATR @ EX1:  arm; fetch_pc already > loop_end  ->  catch-up:
                  flush 'after', 'after+1'            ; wrong path for iter >= 2
                  loop_count <- r3 - 1                ; iteration 1 is in flight
                  PC <- start_i                       ; refetch iteration 2
steady state:   start_i, start_i, start_i, ...        ; back-edge fires every
                                                      ; cycle - zero overhead
last iteration: falls through; 'after' is refetched and executes
```

The catch-up bubble (≤ `BRANCH_SHADOW` cycles) is paid **once per loop
entry** and amortized over the `r3` iterations. A body longer than
`BRANCH_SHADOW` words pays nothing at all — the first natural
`next_pc == loop_end + 1` transition then arrives after the arm, and no flush
occurs. Note the loop-carried recurrence `ADDI r20 -> LW (r20)` sustains 1
cycle/iteration because the control-slot integer ALU produces `r20` at W + 1
(§3.9).

**Scope of this example.** The body issues **one memory operation per cycle**
— the LS slot's limit (one port, LOAD_STORE.md §6). It therefore models
kernels with *one streamed operand*, a *register-resident* second operand
(`r12` is invariant here) and *register accumulation* (`r13`), with the result
stored once after the loop. Kernels that need two memory operations per
element (two streamed inputs, or a load **and** a store per iteration) are
limited to one element every two cycles by memory bandwidth, regardless of
slot count — see LOAD_STORE.md §6 for the bandwidth options.
