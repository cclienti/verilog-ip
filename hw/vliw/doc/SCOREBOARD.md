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
  bank's owning slot ever writes it (one write port per bank; five in total:
  ALU0, ALU1, LS-A, LS-B and CTRL, the LS slot owning one bank per lane of a
  dual load — LOAD_STORE.md §2).
- **Only RAW hazards cross banks** — because any slot can read any bank.

Everything below follows from this single-writer-per-bank property; it is the
reason the scoreboard is a few hundred flip-flops instead of an out-of-order
machine.

---

## 3. Architectural State

For each bank `b` (5 banks × 32 registers):

| Structure          | Size                    | Purpose                                     |
|--------------------|-------------------------|---------------------------------------------|
| `busy_b[r]`        | 32 bits per bank        | a write to register `r` is in flight        |
| `wbres_b[0..LMAX]` | `LMAX`+1 bits per bank  | write-port reservations for future cycles   |

- **`busy_b[r]`** — set when an instruction that writes `(b, r)` issues,
  cleared when the write retires. `busy` answers *"is a write in flight?"*;
  it is the WAW and write-port interlock. Whether a **reader** must wait is
  a different question, answered by `ready_at_b[r]` (§7).
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
  This is the only wide network — up to 10 read operands (2 per ALU, up to 4
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

## 7. Early Issue: `ready_at` and the Bypass Network

### 7.1 The question `busy` cannot answer

`busy_b[r]` marks a write **in flight**. A consumer scheduled at exactly the
producer's latency — the normal case for correctly scheduled code — issues in
the very cycle that write retires. Whether it stalls therefore depends on a
definition, not on a hazard:

- if `busy` means *"not yet written"*, the consumer sees it still set and
  stalls one cycle **even though the compiler scheduled correctly**, and the
  latency tables in the slot documents are all wrong by one;
- if `busy` means *"not yet readable"*, the consumer issues.

The second reading is normative. Two mechanisms implement it, and they are
independent:

| Mechanism | Effect | Cost |
|-----------|--------|------|
| **Write-first register file** — a value written in cycle `W` is visible to a read in cycle `W` | a dependence at *exactly* the machine latency never stalls | none (a `dpmemrf`/LUTRAM property) |
| **Bypass network** (§7.3) with `ready_at` (§7.2) | a dependence at latency **− 1** never stalls | a forwarding crossbar (§7.4) |

Without the first, every correctly scheduled dependence costs a spurious
stall. The second is a performance option on top.

### 7.2 `ready_at`: readable versus written

`ready_at_b[r]` records when the value may be **consumed**, which is the
write-back cycle minus the forwarding depth:

```
ready_at = write_back_cycle - BYPASS_DEPTH        (BYPASS_DEPTH = 0 or 1)
```

It is held as a small **countdown** `rem_b[r]` of `clog2(LMAX+1)` bits (3
bits for `LMAX` = 5), not as an absolute cycle number — no global cycle
counter, no comparator:

- loaded at issue with `latency − BYPASS_DEPTH` for the destination;
- decremented every cycle while non-zero, **including during a global
  stall** — countdowns belong to the *back* of the machine, which drains
  (§5), not to the frozen front;
- `rem_b[r] == 0` ⇔ the value is readable or forwardable this cycle.

`busy` is unchanged and still governs WAW and the write port: two writes to
one register may never be in flight together, since a single `busy` bit
cannot distinguish which of them a reader would get (§4).

### 7.3 Issue check with early issue

Only the RAW rule of §4 changes:

- **RAW stall** if `busy_bank[reg] && rem_bank[reg] != 0` — that is, a write
  is in flight *and* its value cannot be delivered this cycle.
- **WAW** and the `wbres` structural check are untouched.

With `BYPASS_DEPTH = 0` this is exactly §4 under a write-first register file.
With `BYPASS_DEPTH = 1` a consumer may issue one cycle before the write
retires, its operand arriving through the forwarding path instead of the
register file.

### 7.4 The bypass network

Forwarding of depth 1 muxes each slot's write-back value into the operand
paths at RR. Its size is the product of the two widths the register file
already has:

```
5 write ports (ALU0, ALU1, LS-A, LS-B, CTRL) x 10 read operands
  = 50 tag comparisons and 50 x 32-bit mux inputs
```

That crossbar — not the countdowns, which are a few hundred flip-flops — is
the whole cost of the option, and it lands on the RR→EX1 path that already
limits `fmax` (§6.5). Two consequences for implementation:

- **Depth 1 only.** Forwarding from EX3/EX4/EX5 (shift, `MUL`, `INV_SQRT`)
  would multiply the crossbar by the number of stages for a rapidly
  diminishing return; long-latency results are better scheduled around.
- **It is optional by construction.** `BYPASS_DEPTH = 0` removes the network
  entirely and costs only the one cycle of effective latency; binaries do not
  change, because latencies are advisory (§1).

The payoff is the back-to-back dependent case: with `BYPASS_DEPTH = 1` an
`ADD` or a load feeding the next bundle issues without a stall, so a
software-pipelined kernel whose dependence distance is one bundle runs at one
bundle per cycle.

### 7.5 Interactions

- **Squash (§6.5).** `rem` entries are cleared by the same registered flush
  that clears `busy`; no rollback machinery is added.
- **Masked writes.** A `CMOV` whose condition is false releases `busy` and
  reaches `rem = 0` on schedule like any other op (§3) — readability never
  depends on run-time data.
- **Split memory accesses.** When a dual access conflicts, the LS unit
  serializes it and lane 1 retires one cycle later (LOAD_STORE.md §10.4).
  `conflict` is available combinationally in the issue cycle, so `d1`'s
  countdown is simply loaded with `latency + 1` at issue — the reservation is
  right the first time, with nothing to revise afterwards.
- **Variable latency (§8).** A miss stalls globally; countdowns continue to
  drain, which is what keeps all relative timings intact.

### 7.6 Worked example: latency-blind versus latency-aware code

The kernel is `dst[i] = src[i] + 1` for four elements, unrolled, with `c1`
and `c3` the source and destination pointers, `m*` in LS-A and `a*` in the
ALU0 bank. Unrolling addresses every element with an immediate offset, so
the body needs no pointer arithmetic at all. Baseline latencies: a load and
an `ADD` are both readable at `W + 2` (LOAD_STORE.md §5.1).

**Latency-blind.** Each consumer sits directly behind its producer. The code
is *correct* — that is the scoreboard's contract — but pays a stall at every
dependence:

```asm
        LW    m0, 0(c1)
    ;
        ADD   a0, m0, 1          ; RAW on m0: 1 stall
    ;
        SW    a0, 0(c3)          ; RAW on a0: 1 stall
    ;
        LW    m1, 4(c1)
    ;
        ADD   a1, m1, 1          ; RAW: 1 stall
    ;
        SW    a1, 4(c3)          ; RAW: 1 stall
    ;
        ...                      ; two more elements, same shape
```

Twelve bundles and eight stalls: **20 cycles for four elements**.

**Latency-aware.** The same instructions, reordered so that every consumer
sits two bundles behind its producer — exactly the machine latency — with
the loads hoisted to fill the pipeline:

```asm
        LW    m0,  0(c1)
    ;
        LW    m1,  4(c1)
    ;
        LW    m0,  8(c1)   | ADD  a0, m0, 1      ; the ADD reads the m0 of b0
    ;
        LW    m1, 12(c1)   | ADD  a1, m1, 1
    ;
        SW    a0,  0(c3)   | ADD  a0, m0, 1      ; the SW reads the a0 of b2
    ;
        SW    a1,  4(c3)   | ADD  a1, m1, 1
    ;
        SW    a0,  8(c3)
    ;
        SW    a1, 12(c3)
    ;
```

Eight bundles, **8 cycles for four elements** — no stall anywhere, the LS
slot carrying a memory access in every bundle, and **two register names per
bank**, not one per element. Each of the three checks of §4 is exercised
exactly at its limit:

- **RAW**: every source is read exactly two bundles after it was written,
  the machine latency (§7.1) — one cycle earlier would stall, one later
  would waste a slot.
- **WAR**: from `b2` on, a bundle's `LW` rewrites the very register its
  `ADD` reads, and its `SW` reads the register the `ADD` in the same bundle
  rewrites. Both are free: all reads happen at RR, all writes at EX2 (§5).
- **WAW**: a name is rewritten exactly when its previous write retires
  (`m0` at `b0` then `b2`, `a0` at `b2` then `b4`), which is the earliest
  the check of §4 permits.

Two names is also the **minimum**, and the bound is worth stating because
it is the scoreboard's two write rules combined. A name may be rewritten
only once its previous write has retired (WAW, `L` bundles) and no earlier
than the bundle in which its last reader issues (a reader one bundle later
would stall and then observe the *new* value — the WAR exemption covers the
same bundle only). So writes to one name must be `max(L, lifetime)` bundles
apart, and a schedule producing a value every `II` bundles needs
`ceil(max(L, lifetime) / II)` names — here `2 / 1 = 2`.

The cost of going below it is not a stall but a slower schedule: with a
single name per bank the loads must be spaced two bundles apart, which
collides with the stores on the one LS slot, and the best schedule for the
same four elements takes **12 bundles instead of 8** — three cycles per
element for two registers saved. Above the minimum nothing is gained:
giving each element its own register (`m0`…`m3`, `a0`…`a3`) is equally
correct and easier to read, at double the register pressure and the same
eight bundles.

What remains is not a data hazard but a **structural** bound: two memory
accesses per element and a single LS slot per bundle, hence two cycles per
element. Reaching one requires the pair instructions, which move two
elements per memory bundle (`LD2W` + `ST2`, LOAD_STORE.md §10.2), with
`stride % 3 != 0` so the pair never serializes (LOAD_STORE.md §10.4).

---

## 8. Variable-Latency Extension

The global-stall mechanism generalizes cleanly to **variable-latency**
accesses (the NoC port B, or a future external-memory/cache variant —
ARCHITECTURE.md §Memory Model): a miss asserts the same global stall so that
all relative timings are preserved, with no ISA change. The current on-chip
DMEM is fixed-latency, so loads are deterministic in the base core.

---

## 9. Cost

- **State:** 5 × 32 `busy` bits and 5 × (`LMAX`+1) `wbres` bits — a few
  hundred flip-flops; the optional `ready_at` countdowns (§7.2) add
  5 × 32 × 3 bits.
- **Logic:** a muxed 10-operand RAW comparison network (same fan-in as the RF
  read crossbar), per-bank WAW/structural checks, one global stall wire, and
  (registered-flush variant) a one-cycle-late clear.
- **Optional:** the depth-1 bypass crossbar (§7.4), 5 × 10 forwarding paths —
  larger than everything above put together, and the only part that touches
  the critical RR→EX1 path.
- No renaming, no ROB, no reservation stations — one to two orders of
  magnitude cheaper than an out-of-order core of the same width.
