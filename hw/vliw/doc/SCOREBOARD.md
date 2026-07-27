# VLIW Scoreboard Specification

## 1. Overview

The scoreboard is the hardware **interlock** that guarantees data-hazard
correctness. Its contract:

- **NOPs are a performance concern only** (Hexagon-style): a compiler
  scheduling mistake produces a stall, never silent corruption.
- **The ISA is decoupled from the pipeline**: instruction latencies and
  pipeline depth (including the `BRAM_OUT_REG` choices, ARCHITECTURE.md
  §Memory Model) can change without breaking binaries — the latency tables in
  the slot documents are advisory scheduling guides.
- Issue is **in-order and lock-step**; there is no renaming, no CAM, no
  Tomasulo tags, no reorder buffer.

This document owns: the scoreboard state, the issue checks, the stall rules,
and the **interaction with control flow** — branches taken and not-taken,
jumps, traps, the hardware-loop back-edge, and interrupts (§6). The `flush`
mechanism itself (shadow squash, front-end control) is owned by
CONTROL_UNIT.md §5.

---

## 2. Structural Foundation

The register file is **write-local / read-global** (ARCHITECTURE.md §Register
File): each slot writes only its own bank, any slot reads any bank. This
asymmetry maps directly onto the scoreboard:

- **WAW hazards and write-port conflicts are local to a bank** — only that
  bank's owning slot ever writes it (one write port per bank, four total).
- **Only RAW hazards cross banks** — because any slot can read any bank.

Everything below follows from this single-writer-per-bank property; it is the
reason the scoreboard is a few hundred flip-flops instead of an out-of-order
machine.

---

## 3. Architectural State

For each bank `b` (4 banks × 32 registers):

| Structure          | Size                    | Purpose                                     |
|--------------------|-------------------------|---------------------------------------------|
| `busy_b[r]`        | 32 bits per bank        | a write to register `r` is in flight        |
| `wbres_b[0..LMAX]` | `LMAX`+1 bits per bank  | write-port reservations for future cycles   |

- **`busy_b[r]`** — set when an instruction that writes `(b, r)` issues,
  cleared when the write retires. An optional refinement `ready_at_b[r]`
  records the cycle the value becomes readable, enabling early (bypassed)
  issue.
- **`wbres_b`** — a shift-register delay line. Results retire at different
  stages (ADD/LOAD @ EX2, shift @ EX3, MUL/MULH @ EX4, INV_SQRT @ EX5), so two
  ops issued by the **same** slot at different cycles can land on that bank's
  single write port in the **same** cycle. `wbres_b` counts reservations per
  future cycle against the bank's write-port count (1) to catch this
  structural collision (concrete example in ALU.md §5).

`LMAX` is the deepest write-back latency (**5**, for `INV_SQRT`).

**Reservation lifecycle.** A reservation is made **at issue** (the RR stage)
and released **at its scheduled write-back cycle, unconditionally** — release
never depends on run-time data. In particular a `CMOV`/`CMOVI` whose condition
is false releases on schedule even though the write-enable is masked
(CONTROL_UNIT.md §3.8), so a register can never get stuck busy.

---

## 4. Issue Check (combinational, all-or-nothing)

The whole bundle (up to 4 ops) issues only if **no** op raises a hazard — a
single verdict for the entire packet.

- For each **source** `(bank, reg)` global read: **RAW stall** if
  `busy_bank[reg]` and the value is not yet readable/forwardable this cycle.
  This is the only wide network — up to ~8 read operands (2 per ALU, up to 2
  for LS, 2 for CTRL) muxed across the banks into comparators. It mirrors the
  RF read crossbar (same fan-in).
- For each **destination** `(own bank b, reg)`: **WAW stall** if `busy_b[reg]`;
  **structural stall** if the reserved target cycle in `wbres_b` would exceed
  the write-port count. Both checks touch only the issuing slot's own bank.

A bundle that passes **issues**: `busy` is set on its destinations and entries
are inserted into the `wbres` delay lines. A bundle that fails makes **no**
reservation at all (this matters for flush behaviour, §6.6).

---

## 5. Stall, Update, and Progress

- **No hazard:** the packet issues and reserves.
- **Hazard:** a single **global lock-step stall** freezes the front end (PC,
  fetch, issue registers) while the delay lines keep shifting — *freeze the
  front, drain the back*. In-flight writes retire, `busy` bits clear, and the
  packet re-tests the next cycle.

**WAR is free:** in-order issue with operand read at a fixed stage (RR)
guarantees an earlier reader samples before a later writer commits.

**Progress guarantee (no deadlock).** Only the issue stage ever stalls;
instructions past issue always advance and every reservation clears
unconditionally within `LMAX` cycles (§3). Any stall therefore lasts at most
`LMAX` cycles — there is no circular wait.

---

## 6. Interaction with Control Flow

### 6.1 The scoreboard is control-flow-oblivious

Scoreboard state is indexed by **register**, not by PC. A PC redirect —
taken branch, jump, trap, loop back-edge — does **not** reset any scoreboard
state; the only control-flow effect is the cancellation of reservations made
by *squashed* (wrong-path) bundles (§6.5). Consequences:

- Hazards resolve correctly **across** taken branches, calls and returns:
  e.g. a `MUL` issued just before a taken branch keeps `busy` set, and a
  consumer at the branch **target** stalls until W + 4 exactly as a sequential
  consumer would.
- The loop back-edge (CONTROL_UNIT.md §4.4) needs no scoreboard action at
  all: a loop-carried dependency (producer in iteration *i*, consumer in
  iteration *i*+1) is an ordinary cross- or intra-bank RAW through the same
  `busy` bits. `LCLR` makes no reservations of its own; with an active loop it
  does flush younger in-flight words (CONTROL_UNIT.md §4.5) — reservation
  handling for those follows §6.5.

### 6.2 Branches as consumers

A conditional branch **reads** `rs1`/`rs2` and writes nothing:

- Its sources are RAW-checked at issue like any operand — the scoreboard
  guarantees the condition is computed from **settled values**; a branch can
  never resolve on a stale operand. If a source is busy, the whole bundle
  stalls (all-or-nothing, §4).
- It makes **no reservation** (no `rd`), so a branch has zero scoreboard
  footprint of its own. The same holds for `TRAP`, `ERET`, `LOOP`
  (source-read only), `LCLR`.

`JAL`/`JALR` additionally **write the link register**: they reserve `rd` in
the control bank at issue and release it at W + 1 (the shortest `wbres`
entry). `JALR`'s `rs1` is RAW-checked like a branch source.

### 6.3 Branch not-taken

Nothing happens. There is no flush; the `BRANCH_SHADOW` slots after the branch
are the genuine fall-through path and proceed normally — they issue, reserve,
and retire like any bundles. A not-taken branch is scoreboard-invisible
(§6.2) and costs zero cycles beyond its own slot.

### 6.4 Taken branch / jump / trap: timeline

On a taken redirect (`BEQ…BGEU` taken, `JAL`, `JALR`, `TRAP`, `ERET`,
loop-skip), EX1 asserts `flush` (CONTROL_UNIT.md §5.1). With the baseline
pipeline (`BRANCH_SHADOW` = 3), bundle `B` resolving in EX1 at cycle `T`:

| Cycle | `B` (redirecting)         | `B`+1                     | `B`+2     | `B`+3     | Target        |
|-------|---------------------------|---------------------------|-----------|-----------|---------------|
| T−1   | RR — issues, reserves     | ID                        | IF        | —         | —             |
| T     | EX1 — taken, `flush`      | RR — see §6.5             | ID → NOP  | IF → NOP  | `next_pc` set |
| T+1   | EX2 — link WB (JAL/JALR)  | dead; stale entries cleared | —       | —         | IF            |
| T+2   | (drains)                  | —                         | —         | —         | ID            |
| T+3   | —                         | —                         | —         | —         | **RR** — first correct-path issue check |

Key properties:

- **Flush kills strictly younger VLIW words.** The redirecting bundle's
  **own** side effects commit: the co-issued ALU/LS slots of the same 128-bit
  word retire normally (their reservations stand and clear on schedule), the
  `JAL`/`JALR` link write happens, and `TRAP` latches `IRQ_SAVED_PC`.
- **Only bundle `B`+1 can have touched the scoreboard.** `B`+2 and `B`+3 are
  NOP-forced in ID/IF, upstream of the issue stage — they never reach RR as
  real instructions. So at most **one** wrong-path bundle ever holds
  reservations.
- **Older bundles (≤ `B`) drain normally** — a long-latency op issued before
  the redirect (e.g. `MUL` at `B`−1) retires under scoreboard control, and a
  consumer at the target stalls on it correctly (§6.1).
- The earliest correct-path bundle reaches RR at **T+3** (refetch walks
  IF→ID→RR) — the safety margin used by §6.5.
- The **short-body loop catch-up** (CONTROL_UNIT.md §4.3) reuses this flush
  *selectively*: only in-flight words with `pc > loop_end` are squashed; the
  in-flight body word (iteration 1) is correct-path and keeps its
  reservations. The §6.5 contract applies unchanged to the squashed words.
- Every flush also **reloads the speculative loop state** from the committed
  copies (CONTROL_UNIT.md §4.4): fetch-time back-edge decrements made for
  squashed iterations never stick.

### 6.5 Squashed-reservation contract

**Requirement:** no reservation made by a squashed bundle may be observable by
any correct-path issue check.

Two admissible implementations, both without rollback/unreserve machinery:

- **Registered flush (default, `fmax`-friendly).** The bundle in RR at cycle
  `T` issues and reserves normally (the flush acts one cycle later); at T+1
  the registered flush clears its `busy` bits and cancels its pending `wbres`
  entries, and the bundle itself is NOP-forced. Safe because the stale entries
  are gone at T+1 while the first correct-path check happens at T+3 (§6.4). A
  wrong-path bundle that *stalls* on another wrong-path reservation in the
  meantime is harmless — it is being flushed anyway. Nothing feeds
  combinationally back from EX1 into the scoreboard.
- **Same-cycle inhibit (optional, tighter invariant).** The same `flush`
  inhibits the RR bundle's reservations in cycle `T` itself, so wrong-path
  instructions never touch the scoreboard. Cleaner invariant ("no stale entry
  ever exists"), at the cost of an EX1→RR combinational arc into the wide
  scoreboard — the arc most likely to limit `fmax` on FPGA. Prefer only when
  timing analysis shows slack.

Both are functionally equivalent; the choice is a pure timing/area trade-off
made at implementation time.

### 6.6 Flush × stall coincidence

The two front-end controls compose without special cases:

- **A stalled bundle has no footprint.** Reservations happen only on
  successful issue (§4), so a wrong-path bundle sitting *stalled* in RR when
  the flush arrives has reserved nothing; the flush simply NOP-forces it and
  the stall condition evaporates (a NOP raises no hazard). **Flush overrides
  stall** for the squashed stages.
- **A redirect can never be blocked by a data stall.** Only the issue stage
  stalls; a control instruction that has reached EX1 has already issued and
  always resolves. (If the *branch's own* bundle is stalled at RR, it simply
  has not resolved yet — it issues later and flushes then.)

### 6.7 Interrupts

An asynchronous IRQ is injected at EX1 and reuses the same flush
(ARCHITECTURE.md §Interrupts and Exceptions, *Entry point and saved PC*).
Scoreboard-wise it is identical to a taken branch at `B`: younger bundles are
squashed per §6.5, older bundles drain. The handler's context-spill loads and
stores are RAW-checked like any consumer, so they read **settled** register
values even if a long-latency op (MUL, INV_SQRT) was still in flight at entry.
Further IRQs are blocked until `ERET` (*in-handler* flag, ARCHITECTURE.md
§Interrupts and Exceptions). An IRQ arriving during a **global stall** is
accepted with `IRQ_SAVED_PC` = the stalled bundle's PC — safe precisely
because a stalled bundle has made no reservations (§6.6).

---

## 7. Variable-Latency Extension

The global-stall mechanism generalizes cleanly to **variable-latency**
accesses (the NoC port B, or a future external-memory/cache variant —
ARCHITECTURE.md §Memory Model): a miss asserts the same global stall so that
all relative timings are preserved, with no ISA change. The current on-chip
DMEM is fixed-latency, so loads are deterministic in the base core.

---

## 8. Cost

- **State:** 4 × 32 `busy` bits (+ optional `ready_at`) and 4 × (`LMAX`+1)
  `wbres` bits — a few hundred flip-flops.
- **Logic:** a muxed ~8-operand RAW comparison network (same fan-in as the RF
  read crossbar), per-bank WAW/structural checks, one global stall wire, and
  (registered-flush variant) a one-cycle-late clear.
- No renaming, no ROB, no reservation stations — one to two orders of
  magnitude cheaper than an out-of-order core of the same width.
