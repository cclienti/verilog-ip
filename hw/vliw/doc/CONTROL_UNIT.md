# VLIW Control Unit Specification

> **Status note — interrupts removed.** The core has no interrupt mechanism
> (ARCHITECTURE.md §Faults and Host Control): work is dispatched by polling
> between kernels, and a fault halts the core for the host to inspect. `ERET`
> is gone and `TRAP` is now a deliberate halt. Passages below that describe
> IRQ acceptance, saved-PC shadows or handler behaviour — notably the IRQ
> timelines of §4.4 and the IRQ priority in the §5 flush order — describe a
> mechanism that no longer exists; they are retained because the same
> reasoning applies to the branch and loop cases they share, and are marked
> for rewrite. The branch shadow is likewise **no longer squashed**: its
> words are architectural delay slots the compiler must fill.

## 1. Overview

The Control Unit is responsible for:

- Program Counter (PC) sequencing
- Conditional branches, jumps, calls and returns
- System / trap / interrupt return
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
| Read ports     | **2** | 7-bit addr (3-bit bank + 5-bit reg) | `rs1`/`rs2` for branches, JALR, LOOP, CMOV, integer ALU |
| Write port     | **1** | 5-bit addr, bank implicit from slot | `rd` for JAL/JALR/MOV/CMOV, integer ALU  |

Rationale for **2 read / 1 write**:

| Instruction class | rd  | rs1 | rs2       |
|-------------------|-----|-----|-----------|
| Branch (B-type)   | no  | yes | yes       |
| JAL               | yes | no  | no        |
| JALR              | yes | yes | no        |
| SYSTEM/LOOP       | no  | yes (LOOP only) | no  |
| MOV               | yes | yes | no        |
| MOVI              | yes | no  | no        |
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
the Control slot, plus the per-slot ports the ALU/LS slots require). Interrupt
context is spilled/filled in software through the Load/Store slot's existing
ports (ARCHITECTURE.md §Interrupts and Exceptions) — there are no dedicated
context-save ports.

---

## 3. Instruction Set

Control instructions are encoded in a **32-bit slot** with a single flat 6-bit
opcode:

```
[31:26]    [25:0]
opcode(6)  payload(26)
```

| Field     | Bits    | Description                                              |
|-----------|---------|----------------------------------------------------------|
| `opcode`  | [31:26] | 6-bit instruction selector (control-slot local space)    |
| `payload` | [25:0]  | 26 bits, layout is opcode-specific                       |

There is no format bit: register and immediate forms of an operation (e.g.
`MOV` / `MOVI`) are **distinct opcodes**.

**NOP** is encoded as `opcode = 000000`. It is the canonical no-operation and
the preferred form for an empty control slot; the assembler emits the all-zero
word `0x00000000` for unused control slots.

### 3.1 Encoding reference card

All instructions are 32 bits: `opcode[31:26] | payload[25:0]`.
`x` = don't-care, assembler emits `0`. All targets are signed VLIW-word offsets.

**Fixed field positions (where applicable):**

| Field        | Bits    | Width | Notes                                          |
|--------------|---------|-------|------------------------------------------------|
| `opcode`     | [31:26] | 6     | instruction selector                           |
| `rd`         | [25:21] | 5     | dest register, bank implicit from slot         |
| `rs1`        | [25:19] | 7     | source 1 (branches only)                       |
| `rs1`        | [20:14] | 7     | source 1 (JALR / LOOP / MOV / CMOV)            |
| `rs2`        | [18:12] | 7     | source 2 (branches only)                       |
| `rs_cond`    | [20:14] | 7     | condition register (CMOV / CMOVI)              |
| `rs_src`     | [13:7]  | 7     | source register (CMOV only)                    |
| `imm12`      | [11:0]  | 12    | signed immediate (JALR / MOVI / CMOVI)         |
| `end_off`    | [11:0]  | 12    | signed loop body offset (LOOP / LOOPI)         |
| `target(12)` | [11:0]  | 12    | signed branch offset                           |
| `count`      | [25:12] | 14    | unsigned iteration count (LOOPI only)          |
| `target(21)` | [20:0]  | 21    | signed jump offset (JAL only)                  |

Note: `imm12`, `end_off`, and branch `target` all occupy `[11:0]` —
a single sign-extend extraction circuit covers all three.

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
| `001000` | `JALR`   | `rd, rs1, imm12`      | jump to `rs1 + imm12`; `rd = PC + 1`             | §3.4   |
| `001001` | `TRAP`   | `trap_code`           | halt the core, cause `SOFTWARE`, `trap_code` latched for the host | §3.6   |
| `001011` | `LOOP`   | `rs1, end_off`        | arm hardware loop, count from `rs1`              | §3.5   |
| `001100` | `LCLR`   | —                     | abort the active hardware loop                   | §3.5   |
| `001101` | `MOV`    | `rd, rs`              | `rd <- rs`                                       | §3.7   |
| `001110` | `CMOV`   | `rd, rs_cond, rs_src` | if `rs_cond != 0`: `rd <- rs_src`                | §3.8   |
| `001111` | `LOOPI`  | `count, end_off`      | arm hardware loop, immediate count               | §3.5   |
| `010000` | `MOVI`   | `rd, imm12`           | `rd <- sign_ext(imm12)`                          | §3.7   |
| `010001` | `CMOVI`  | `rd, rs_cond, imm12`  | if `rs_cond != 0`: `rd <- sign_ext(imm12)`       | §3.8   |
| `010010` | `ADD`    | `rd, rs1, rs2`        | `rd <- rs1 + rs2`                                | §3.9   |
| `010011` | `SUB`    | `rd, rs1, rs2`        | `rd <- rs1 - rs2`                                | §3.9   |
| `010100` | `ADDI`   | `rd, rs1, imm12`      | `rd <- rs1 + sign_ext(imm12)`                    | §3.9   |
| `010101` | `AND`    | `rd, rs1, rs2`        | `rd <- rs1 & rs2`                                | §3.9   |
| `010110` | `OR`     | `rd, rs1, rs2`        | `rd <- rs1 \| rs2`                               | §3.9   |
| `010111` | `XOR`    | `rd, rs1, rs2`        | `rd <- rs1 ^ rs2`                                | §3.9   |
| `011000` | `ANDI`   | `rd, rs1, imm12`      | `rd <- rs1 & sign_ext(imm12)`                    | §3.9   |
| `011001` | `SLT`    | `rd, rs1, rs2`        | `rd <- (rs1 <  rs2) signed ? 1 : 0`              | §3.9   |
| `011010` | `SLTU`   | `rd, rs1, rs2`        | `rd <- (rs1 <  rs2) unsigned ? 1 : 0`            | §3.9   |
| `011011` | `SLTI`   | `rd, rs1, imm12`      | `rd <- (rs1 < sign_ext(imm12)) signed ? 1 : 0`   | §3.9   |
| `011100` | `SLTIU`  | `rd, rs1, imm12`      | `rd <- (rs1 < sign_ext(imm12)) unsigned ? 1 : 0` | §3.9   |

Reserved: opcode `001010` (formerly `ERET`) and `011101`–`111111` (36
entries in total). Executing a reserved opcode
raises an **illegal-instruction trap** (same entry path as `TRAP`; `trap_code`
in `ABI.md`) — the assembler must never emit one.

**Notes:**
- `rs1`, `rs2`, `rs`, `rs_cond`, `rs_src` are **7-bit** global register
  addresses (`bank[2:0]` + `reg[4:0]`).
- `rd` is **5-bit** (bank implicit from the slot).
- `imm12`, `end_off`, and branch `target` are all at `[11:0]`, signed,
  sign-extended to 32 bits by a single shared circuit.
- `count(14)` in `LOOPI` is **unsigned**, range 0–16383 (0 = skip loop).
- Branch `target(12)` → **±2048 VLIW words**.
- JAL `target(21)` → **±1M VLIW words**.
- JALR offset `imm12` → **±2047** words from `rs1`.
- `end_off(12)` → loop body up to **2047 VLIW words**.
- `trap_code(26)` allocation defined in `ABI.md`.
- Register and immediate forms are **distinct opcodes** (no format bit):
  `LOOP`/`LOOPI`, `MOV`/`MOVI`, `CMOV`/`CMOVI`.
- Branches have **no link register** — use `JAL` for branch-and-link.
- All PC arithmetic (`PC + 1`, branch/jump targets, `rs1 + imm12`) is performed
  **modulo `2^IMEM_DEPTH_LOG2`** — targets are truncated to the PC width.
- The control-slot **integer ALU** (`ADD`…`SLTIU`) writes `rd` into the control
  bank and reuses the 2-read/1-write ports; it is a simple fast unit (no
  multiply, no shift) — see §3.9.

### 3.2 Branch format

| [31:26]   | [25:19] | [18:12] | [11:0]     |
|-----------|---------|---------|------------|
| opcode(6) | rs1(7)  | rs2(7)  | target(12) |

- `target`: signed 12-bit VLIW-word offset → range **±2048 VLIW words**
- Shadow = `BRANCH_SHADOW` VLIW words, **hardware-squashed** — no `NOP` padding
  is emitted; hoisting fall-through work into it is a performance optimization
  only, never a correctness requirement (see §5.1). Its exact size is not yet
  finalized (see §8).
- No link register. Use `JAL` for branch-and-link.
- For longer-range conditional branches: load target into a register and use
  a conditional skip + `JAL` pattern (compiler responsibility).

### 3.3 JAL format

| [31:26]   | [25:21] | [20:0]     |
|-----------|---------|------------|
| `000111`  | rd(5)   | target(21) |

- `target`: signed 21-bit VLIW-word offset → **±1M VLIW words**
- `rd = PC + 1` (link register; use `r0` to discard)

### 3.4 JALR format

| [31:26]   | [25:21] | [20:14] | [13:12]   | [11:0]    |
|-----------|---------|---------|-----------|-----------|
| `001000`  | rd(5)   | rs1(7)  | unused(2) | imm12(12) |

- `PC = rs1 + sign_ext(imm12)`
- `rd = PC + 1` (use `r0` to discard)


### 3.5 LOOP / LOOPI format

`LOOP` (register count) and `LOOPI` (immediate count) are distinct opcodes.

Register form (`LOOP`, opcode `001011`):

| [31:26]   | [25:21]   | [20:14] | [13:12]   | [11:0]      |
|-----------|-----------|---------|-----------|-------------|
| `001011`  | unused(5) | rs1(7)  | unused(2) | end_off(12) |

Immediate form (`LOOPI`, opcode `001111`):

| [31:26]   | [25:12]   | [11:0]      |
|-----------|-----------|-------------|
| `001111`  | count(14) | end_off(12) |

- `end_off` is a signed 12-bit VLIW-word offset from the `LOOP` instruction to the last instruction of the loop body (inclusive).
- `count(14)` in `LOOPI` is unsigned, range 0–16383; `count = 0` skips the loop body (0 iterations).
- See §4 for full hardware loop semantics.

---

### 3.6 TRAP format

| [31:26]   | [25:0]        |
|-----------|---------------|
| `001001`  | trap_code(26) |

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

### 3.7 MOV / MOVI format

Register form (`MOV`, opcode `001101`):

| [31:26]   | [25:21] | [20:14] | [13:0]     |
|-----------|---------|---------|------------|
| `001101`  | rd(5)   | rs(7)   | unused(14) |

Immediate form (`MOVI`, opcode `010000`):

| [31:26]   | [25:21] | [20:12]   | [11:0]    |
|-----------|---------|-----------|-----------|
| `010000`  | rd(5)   | unused(9) | imm12(12) |

- `rd` is in the Control slot's own bank (bank implicit from slot)
- `rs` is a full 7-bit global address (any bank)
- `MOVI` sign-extends the 12-bit immediate to 32 bits

### 3.8 CMOV / CMOVI format

Register form (`CMOV`, opcode `001110`):

| [31:26]   | [25:21] | [20:14]    | [13:7]    | [6:0]     |
|-----------|---------|------------|-----------|-----------|
| `001110`  | rd(5)   | rs_cond(7) | rs_src(7) | unused(7) |

Immediate form (`CMOVI`, opcode `010001`):

| [31:26]   | [25:21] | [20:14]    | [13:12]   | [11:0]    |
|-----------|---------|------------|-----------|-----------|
| `010001`  | rd(5)   | rs_cond(7) | unused(2) | imm12(12) |

- if `rs_cond != 0`: `rd <- rs_src` (or `sign_ext(imm12)`)
- if `rs_cond == 0`: `rd` is **not written** — retains its previous value
- Condition is evaluated in EX1; write-enable to the register file is gated
  by the condition result — one AND gate, no extra pipeline stage
- Latency: 2 cycles (same as MOV)
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

| [31:26]   | [25:21] | [20:14] | [13:7] | [6:0]     |
|-----------|---------|---------|--------|-----------|
| opcode(6) | rd(5)   | rs1(7)  | rs2(7) | unused(7) |

Immediate form (`ADDI`, `ANDI`, `SLTI`, `SLTIU`):

| [31:26]   | [25:21] | [20:14] | [13:12]   | [11:0]    |
|-----------|---------|---------|-----------|-----------|
| opcode(6) | rd(5)   | rs1(7)  | unused(2) | imm12(12) |

- `rd` is written into the **control bank** (bank 3, implicit); `rs1`/`rs2` are
  7-bit global reads (any bank), so operands may come from any slot's bank.
- `imm12` is signed and shares the `[11:0]` sign-extend circuit with the other
  control-slot immediates (§3.1); range **±2047**.
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

If a trap/IRQ is accepted in the **same cycle**, the arm still commits but the
trap's flush reloads the speculative copies from the committed ones (§4.4),
undoing the in-flight credit — the credited iteration is itself squashed. See
the third illustration in §4.4 and ARCHITECTURE.md §Interrupts and Exceptions.

- Exactly **one** copy of the body is in flight at arm time (fetch was purely
  sequential), so the decrement is always by one.
- Cost: a ≤ `BRANCH_SHADOW`-cycle bubble **once per loop entry**, and only for
  short bodies; a body longer than the front end arms with zero cost, and the
  **steady state is unaffected in all cases** — even a 1-word body back-edges
  every cycle with zero overhead (illustrated in §9).
- Rationale: the alternative — a minimum body length with assembler `NOP`
  padding — would make correctness depend on inserted NOPs and freeze the
  front-end depth (`BRAM_OUT_REG`, ARCHITECTURE.md §Memory Model) into
  binaries, exactly what the hardware-squash model exists to avoid (§5.1).
  Correctness stays in hardware; NOPs remain performance-only.

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

#### Committed vs. speculative loop state

The back-edge mutates the count and active flag at **fetch time** — before the
fetched iteration has executed. Fetch is speculative with respect to squash (a
taken branch in the body, an IRQ): decrements made for iterations that are
later squashed and refetched must not stick, or the loop silently runs short.
The loop state is therefore split:

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

**Reload rule (any flush).** Every `flush` — taken branch / jump, `TRAP` /
IRQ, loop-skip, catch-up-under-trap (§4.3), `LCLR` with an active loop (§4.5)
— reloads the speculative copies from the committed ones:

```
loop_count_spec  <- loop_count
loop_active_spec <- loop_active
```

This is exact: at flush time nothing younger than EX1 survives, so the
committed values are precisely the state at the resume point; refetched
iterations then re-decrement the speculative copy legitimately. MMIO reads
(`LOOP_COUNT`, `LOOP_ACTIVE`) return the **committed** copies, so an ISR
always saves and restores values consistent with `IRQ_SAVED_PC`.

#### Pipeline-state illustrations

**IRQ in the middle of a 1-word-body loop** (`loop_start = loop_end = S`,
`N = 10`; `S(k)` denotes iteration `k`):

```
             EX1     RR      ID      IF    | count_spec | count (committed)
cycle T:     S(5)    S(6)    S(7)    S(8)  |     3      |   6     IRQ accepted
  1. S(5) retires and commits:   count 6 -> 5
  2. S(6), S(7), S(8) squashed   (same flush as a taken branch)
  3. reload:  count_spec <- count = 5
  4. IRQ_SAVED_PC <- loop_start  (back-edge next-PC of S(5))

ISR reads LOOP_COUNT = 5         ; "iterations 6..10 remain" — consistent
ERET -> refetch S ; iterations 6..10 run.

Without the committed copy, count_spec = 3 would survive the flush: the
refetched loop would back-edge only 3 more times and iterations 9 and 10
would be silently lost.
```

**Taken early-exit branch at `loop_end`** (body `S..E`, `BNEZ` in the last
body word, taken during iteration `k`):

```
             EX1     RR        ID          IF        | count_spec | count
cycle T:     E(k)    S(k+1)    S+1(k+1)    S+2(k+1)  |   c - 1    |   c
  1. BNEZ in E(k) resolves TAKEN — redirect wins over the back-edge (§4.10)
  2. committed count NOT decremented (E retired with a taken redirect)
  3. wrapped words of iteration k+1 squashed; reload: count_spec <- c
  4. PC <- branch target (where the compiler placed LCLR, §4.7)
```

**IRQ in the same cycle `LOOPI` reaches EX1** (1-word body `S = W+1`,
short-body catch-up, §4.3):

```
             EX1      RR      ID      IF   | count_spec | count
cycle T:     LOOPI    S(1)    W+2     W+3  |     —      |   —
  1. arm commits:      loop_active <- 1, start = end = S, count <- N
  2. catch-up credit:  count_spec <- N - 1   (iteration 1 is in flight ...)
  3. IRQ flush (priority 1) squashes S(1), W+2, W+3   (... and now it is dead)
  4. reload:  count_spec <- count = N        — the credit is undone
  5. IRQ_SAVED_PC <- loop_start = S

ISR reads LOOP_COUNT = N ; ERET -> S ; all N iterations run.
(An implementation MAY instead defer IRQ acceptance by one cycle when EX1
holds a LOOP/LOOPI — the two behaviours are architecturally
indistinguishable. See ARCHITECTURE.md §Interrupts and Exceptions.)
```

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

The loop comparator only fires when the program is about to step past
`loop_end`. Therefore:

- Calls (`JAL`/`JALR`) into a function and back: **safe** — the function
  runs at unrelated addresses; on return, the body resumes normally.
- Branches inside the body that stay within `[loop_start, loop_end]`: **safe**
  by construction.
- Any control transfer **out of the body** that is not via the natural
  back-edge: must be preceded by `LCLR`. The compiler is responsible.

### 4.8 Interaction with interrupts

The loop context is **not auto-saved** on `TRAP`. Two cases:

1. **ISR does not use the hardware loop** → no action required. `ERET`
   returns to the body and the loop continues unaffected.
2. **ISR wants to use the hardware loop** → it must save and restore the
   context manually via the memory-mapped registers below, before issuing
   any `LOOP`/`LOOPI`.

#### Memory-mapped loop registers (top of DMEM address space)

The loop-context subset is shown here for the save/restore sequence; the
authoritative data-memory map (loop **and** IRQ registers) is `LOAD_STORE.md`
§4.2.

| Offset from top | Name           | Width             | Access | Description           |
|-----------------|----------------|-------------------|--------|-----------------------|
| -9              | `LOOP_ACTIVE`  | 1                 | RW     | `loop_active` flag    |
| -8              | `LOOP_START`   | `IMEM_DEPTH_LOG2` | RW     | `loop_start`          |
| -7              | `LOOP_END`     | `IMEM_DEPTH_LOG2` | RW     | `loop_end`            |
| -6              | `LOOP_COUNT`   | 32                | RW     | `loop_count`          |

Save/restore sequence in an ISR that wants to use the loop:

```
; save
LW   r1, LOOP_ACTIVE
LW   r2, LOOP_START
LW   r3, LOOP_END
LW   r4, LOOP_COUNT
... ISR work, may use LOOP/LOOPI freely ...
; restore
SW   r4, LOOP_COUNT
SW   r3, LOOP_END
SW   r2, LOOP_START
SW   r1, LOOP_ACTIVE         ; write last so back-edge re-arms cleanly
ERET
```

### 4.9 Design choices dropped vs. earlier drafts

For reference, this single-context design **deliberately omits**:

- Loop stack and `lsp`
- Nesting level field (`lvl`)
- `LEND` explicit marker; `BREAK`, `CONTINUE`, `LDROP` as primitive opcodes
- `LOOP_DEPTH` parameter
- Loop overflow / underflow / level-mismatch traps
- Automatic save/restore of the loop context on TRAP

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
            seq  br  jal jalr loop_back  trap/eret
                                 (or loop_skip on LOOP with count==0)
```

Priority of next-PC selection (highest first):

1. `TRAP` (synchronous or external IRQ)
2. `ERET`
3. Taken branch / `JAL` / `JALR`
4. **Loop back-edge** (`loop_active && next_pc == loop_end + 1`)
5. **Loop skip / short-body catch-up** (`LOOP`/`LOOPI` with `count == 0`, or
   armed with the front end already past `loop_end` — §4.3)
6. Sequential `PC + 1`

On an **asynchronous IRQ**, the PC saved in `IRQ_SAVED_PC` is this same next-PC
selection with the trap override (1–2) removed — priorities 3–6 — so a
coincident taken branch, jump, or loop back-edge resumes at its resolved target,
not the sequential PC. See ARCHITECTURE.md §Interrupts and Exceptions (Entry
point and saved PC).

The back-edge is computed on `next_pc` one cycle ahead of fetch and therefore
incurs **no shadow**. Branches, `JAL`, `JALR`, `TRAP`, `ERET`, the loop skip
and the short-body catch-up (§4.3) all resolve in EX1; their `BRANCH_SHADOW`
younger slots are **hardware-squashed** (§5.1), so the compiler fills the
shadow only for performance.

### 5.1 Branch shadow and hardware squash

Any control instruction that redirects the PC resolves in **EX1**. By then the
front end has already fetched the next `BRANCH_SHADOW` VLIW words (in IF/ID/RR);
on a taken redirect those words are on the wrong path.

The hardware **squashes** them. On a taken branch / `JAL` / `JALR` / `TRAP` /
`ERET` / loop-skip / `LCLR` with an active loop (§4.5) — and, selectively, on
the short-body loop catch-up (§4.3, which flushes only the words beyond
`loop_end`) — EX1 asserts a `flush` that

- forces the `BRANCH_SHADOW` younger in-flight slots to `NOP`,
- masks their register-file write-enables,
- thereby suppresses their data-memory / MMIO accesses and any loop-context or
  trap side effect — squashed slots reach EX1 as `NOP`s, so **no architectural
  side effect of any kind survives**, not only register writes — and
- reloads the speculative loop state from the committed copies (§4.4).

Consequently the shadow needs **no compiler action for correctness** — and,
unlike a delay-slot ISA, **no `NOP` padding either**. The hardware inserts the
bubble automatically on a taken redirect; the assembler does not pad after a
branch. `BRANCH_SHADOW` is therefore purely a **scheduler cost-model number**,
not an architectural delay slot. The only thing the scheduler can do with it is
*performance*:

- On a **not-taken** conditional branch the shadow slots are the real
  fall-through path (never squashed), so hoisting independent fall-through work
  into them hides the bubble for free.
- On **unconditional** transfers (`J`/`JAL`/`JALR`/`TRAP`/`ERET`) and **taken**
  branches the shadow is always squashed — nothing the compiler places there
  survives, so those cycles are simply the taken-branch penalty. This is why hot
  inner loops use the hardware loop (§4): no branch, no shadow.

A mis-scheduled (or unfilled) shadow costs cycles, never correctness — mirroring
the data-hazard scoreboard (see ARCHITECTURE.md §Scoreboard): NOPs are a
performance concern only, for both data and control hazards.

**Scoreboard interaction.** Squashed slots must leave no stale scoreboard
reservations observable by the correct path. The reservation-cancellation
contract, the full redirect timeline, and its two admissible implementations —
the **registered flush** (default, `fmax`-friendly: wrong-path entries cleared
one cycle later, provably before the refetched path can reach RR) and the
**same-cycle inhibit** (optional, at the cost of an EX1→RR combinational
arc) — are specified in **`SCOREBOARD.md`** §6, the authoritative reference.
Neither variant needs rollback / unreserve machinery.

**No squash needed for:** the **loop back-edge** (resolved one cycle ahead on
`next_pc`, §4.4 — no shadow). `LCLR` *does* flush, but only when a loop is
active (§4.5).

**Cost.** A `flush` control signal plus per-slot NOP-force muxes and
write-enable masks — a handful of gates, reusing the same front-end control as
the lock-step stall (stall = *freeze* the front-end registers; flush = *force
them to NOP*). Scoreboard-side cost of the two flush variants: `SCOREBOARD.md`
§8.

**Implementation shortcut (optional).** A first FPGA bring-up MAY skip the
squash hardware entirely and instead require the assembler to pad
`BRANCH_SHADOW` `NOP`s after every control transfer. This is an *implementation*
restriction, not an ISA change: a later squashing core runs that padded code
unchanged (the `NOP`s are simply redundant). The trade-off is that padding
freezes `BRANCH_SHADOW` into the binary and makes not-taken branches pay the
bubble too, so it is a temporary crutch — the architectural contract remains
hardware squash.

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
| `MOV`/`MOVI`     | `rd` at W + 2                             | 0           |
| `CMOV`/`CMOVI`   | `rd` at W + 2 (if written)               | 0           |
| Integer ALU (`ADD`…`SLTIU`) | `rd` at W + 1 (design intent, §3.9) | 0     |
| `TRAP`/`ERET`    | —                                         | `BRANCH_SHADOW` |

Every `BRANCH_SHADOW` entry above is **hardware-squashed** (§5.1): the compiler
fills the shadow slots for performance, but an empty or mis-scheduled shadow
costs cycles, never correctness.

---

## 7. Pseudo-instructions

| Pseudo                       | Expansion                  | Notes                              |
|------------------------------|----------------------------|------------------------------------|
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
| `BRANCH_SHADOW` | 3 (TBD) | VLIW words of taken-branch bubble, **hardware-squashed** (§5.1) — a scheduler cost-model number, not a delay slot; no `NOP` padding is emitted. Derived from pipeline depth (IF/ID/RR + branch resolves in EX1) and therefore from the BRAM fetch output-register choice (`BRAM_OUT_REG`, ARCHITECTURE.md §Memory Model) — a 2-cycle fetch grows the shadow by one; exact value **not yet finalized**. |

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
    BNEZ  r2, mid                  ; taken  -> 3-word shadow squashed (HW bubble)
                                   ; !taken -> falls straight into the code below,
                                   ;           which fills the shadow for free
    ADDI  r1, r1, -1
    BNEZ  r1, outer                ; same: no NOP padding — HW bubbles on the
                                   ; taken back-edge, fall-through fills it
```

Note there is **no `NOP` padding** after the branches: the shadow is
hardware-squashed on a taken redirect (§5.1), so the assembler emits nothing for
it. On the not-taken exit path the following instructions occupy the shadow and
execute usefully.

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
