# hw/vliw — working notes

Specification and tooling for the VLIW core. Rules that apply here on top
of the repository ones.

## The L/S encoding is generated, not hand-written

`tools/ls_isa.py` owns the field map, formats and opcode map for the
Load/Store slot, and emits the specification tables, the assembler
reference and the RTL decode package.

```sh
cd tools
python3 ls_isa.py --check       # tables are internally consistent
python3 ls_isa.py --check-doc   # tables agree with doc/LOAD_STORE.md
python3 ls_isa.py --test        # embedded unit tests
```

**All three green in the same commit as any encoding change.**
`--check-doc` exists because `LOAD_STORE.md` and the tables drifted apart
three separate times before it did.

The **ALU and control slots are not covered** — their encodings are
hand-maintained in `doc/ALU.md` and `doc/CONTROL_UNIT.md`, and they have
drifted repeatedly: a `payload(26)` left behind after the slot widened, a
slot-to-bank table with four entries instead of five, register addresses
still written on 7 bits. Extending the generator to them is the
highest-value open task in this subtree. Until then, changing either
encoding means checking every layout table by hand.

Golden vectors in the test suite are hand-computed from the field map. A
failing one means the encoding changed — re-bless it deliberately, never
to make the test pass.

## Two widths, easily confused

The datapath is **32 bits** (registers, ALU operands, memory words). The
instruction slot is **36 bits**, the bundle 144. Most of the stale text
found in these documents came from "32-bit" meaning one and being read as
the other. When editing, say which.

## Design invariant

The core is **fully exposed**: no interlock, no branch-shadow squash, no
interrupts, no traps beyond a deliberate halt. Instruction latencies, the
branch shadow and write ordering are architectural — the compiler owns
every hazard it can decide statically, and a scheduling mistake yields a
wrong result rather than a stall.

The single dynamic mechanism is the bank-conflict freeze in the data
memory, kept only because its trigger is a runtime register value.

Apply this to new proposals: **hardware handles only what the compiler
cannot decide.** It settled the ALU write-port conflict (static, so the
compiler owns it), the same-word write merge (rejected: the compiler can
pack the pair itself) and the sub-word dual forms.

A corollary that keeps being useful: because the freeze is *total*, every
pipeline-relative latency is preserved across it, so serializing an
access is invisible to program correctness and only costs a cycle. That
makes such optimisations safe to defer — they change no semantics and
break no binary.

## Document status

`doc/SCOREBOARD.md` describes a **removed** mechanism, retained as design
rationale behind a status note. Do not implement from it, and do not
reconcile the other documents to it.

`doc/CONTROL_UNIT.md` carries its own status note listing what is still
being rewritten. Read it before trusting a section.

Values still provisional and marked as such: `BRANCH_SHADOW` (3) and the
whole latency table. They are architectural in nature — the compiler
encodes them and a change is an ISA change — but the numbers await
synthesis of the functional units. Assembly in the specifications
illustrates the contract, not the final schedule.
