Parallel Memory, 5 Prime-Interleaved Banks, Quad Strided-Group Front End
========================================================================

Description
-----------

The ``parmem5_4`` module is a member of the ``parmem`` prime-interleaved
family, at ``(NB_BANKS, NB_LANES) = (5, 4)``: five
true-dual-port, dual-clock memory banks (``dpmemrf``, READ_FIRST — i.e.
BRAM semantics) accessed as a **quad strided group from one
instruction**:

- lane ``i`` (``i = 0 .. 3``) accesses ``EA_i = addr + i*stride``
  (``stride`` signed, in words);
- ``lane_en[i]`` enables lane ``i`` individually (vector tails come free);
- all enabled lanes share ``wen``: a group load (LD4) or a group store
  (ST4) — a read/write mix cannot be expressed.

The body is standalone (no shared generic) so that pipeline registers
can be inserted to break the
worst-case paths. ``ADRREG = 1`` does exactly that: it registers the end
of the address phase (bank enables/WE/address/data muxes and bank ids),
before the bank access. ``conflict`` and ``oob`` are computed before the
register, from the ports only, and **stay combinational**: the
issue-cycle contract is unchanged — only the side-A read latency grows
to ``1 + ADRREG + OUTREGA`` cycles (writes commit one cycle later,
invisibly, in order).

Measured combinational figures for this configuration (post-route OOC,
xc7z020-1, 5 ns, OUTREG = 1 — see ``hw/lib/parmem/doc/RESULTS.md``):
**955 LUTs, 5 RAMB36, clka WNS −1.994 ns** (≈ 143 MHz pessimistic bound,
worst path stride→WE, 9 logic levels, 65 % routing).

CRT (Chinese Remainder Theorem) addressing — **no divider**:

- ``bank(EA)  = EA mod 5`` — base-4 digit tree with alternating signs
  (``4 ≡ −1 mod 5``, casting out elevens), final reduction as a bounded
  constant modulo, one-hot output fused with the bank compare;
- ``index(EA) = EA mod 2^DEPTH`` — the low address bits, free.

Because ``gcd(5, 2^DEPTH) = 1`` this map is a bijection over the
``5 * 2^DEPTH``-word space. Lanes collide iff ``stride ≡ 0 (mod 5)`` —
so ``conflict`` is **one bit and a pure function of the stride residue
and the lane mask** (>= 2 active lanes), never of the addresses: the EA
adders stay out of the stall cone. It may assert together with ``oob*``;
the oob trap takes precedence. On conflict, the lowest enabled lane is
served and the other active lanes are dropped (by the steering priority
itself — ``conflict`` is advisory; dropped lanes' ``doa`` is invalid,
their writes are not performed). **Power-of-2 strides never conflict**;
all strides except multiples of 5 serve four lanes conflict-free.

Lane EAs are computed by **parallel adders** (``2s`` is a shift, ``3s``
one narrow pre-add), and lane bank ids in **constant depth**:
``bank_i = (bank_0 + i*scorr) mod 5``, where ``scorr`` is the
sign-corrected stride residue and ``(i*scorr) mod 5`` a 3-bit LUT
function.

Every EA is range-checked at **full width before truncation** (a negative
or overflowing sum can alias an in-range address): the test is
``sign | (top bits >= 5)`` — a one-LUT compare, no carry chain after the
adder. Out-of-range lanes are reported on ``oob[i]`` and suppressed
individually (other lanes proceed).

Steering per bank: one 4:1 address mux, one 4:1 write-data mux (one-hot
AND-OR), smart enables (``wea_bank[b] = ena_bank[b] & wen``),
lowest-lane priority. The mux selects use the first raw residue match
among lanes 0..2 with **lane 3 as default**, keeping the adders and
out-of-range logic off the address/data select cone. Per lane: a 5:1
read-data bank mux whose select is the **registered** bank id, aligned
with the read latency.

**Side B** (``clkb``, independent clock) is a single linear-addressed port
with its own CRT decode — e.g. a NoC network interface (fixed stride-1
walker on the NI side). A single requester means no muxes and no conflicts
by construction. The dual-clock banks are the clock-domain crossing.

Reads are synchronous (BRAM): side-A data is valid ``1 + ADRREG +
OUTREGA`` cycles after the access, side-B data ``1 + OUTREGB`` cycles
(``OUTREG*`` = BRAM output-register fmax option; the ``dpmemrf`` output
register is enable-gated — keep the port enabled one extra cycle to
flush). READ_FIRST: a write returns the pre-write content of the
addressed cell on the same port.

The reference model (bijection, reverse map with constant-folded modular
inverse, conflict rule, NI walk strategies) is
``hw/vliw/study/crt_addressing.py``.

Parameters
----------

==========  ==============  ====================================================
Name        Default value   Description
==========  ==============  ====================================================
DEPTH       10              Log2 of words per bank (total ``5 * 2^DEPTH`` words)
WIDTH       32              Data width
STRIDE_W    12              Signed stride width, in words (<= DEPTH + 3)
ADRREG      0               Address-phase pipeline register (+1 cycle, fmax option)
OUTREGA     0               Extra side-A output register (+1 cycle, fmax option)
OUTREGB     0               Extra side-B output register (+1 cycle, fmax option)
==========  ==============  ====================================================

Signals
-------

=============  ============  ==========================  ==================================================
Name           I/O type      Range                       Description
=============  ============  ==========================  ==================================================
clka           input                                     Side A clock (load/store unit)
en             input                                     Side A enable
wen            input                                     Write enable, shared by the group (0 = read)
lane_en        input         [3:0]                       Per-lane enable (lane i at ``addr + i*stride``)
addr           input         [DEPTH+2:0]                 Linear word address of lane 0
stride         input         [STRIDE_W-1:0]              Signed word stride
dia            input         [4*WIDTH-1:0]               Lane write data (lane i at ``i*WIDTH``)
doa            output        [4*WIDTH-1:0]               Lane read data (1 + ADRREG + OUTREGA cycles)
conflict       output                                    ``stride % 5 == 0`` and >= 2 lanes: serialize
oob            output        [3:0]                       ``EA_i`` out of range, lane suppressed
clkb           input                                     Side B clock (network interface)
enb            input                                     Port B enable
web            input                                     Port B write enable (0 = read)
addrb          input         [DEPTH+2:0]                 Port B linear word address
dib            input         [WIDTH-1:0]                 Port B write data
dob            output        [WIDTH-1:0]                 Port B read data (1 + OUTREGB cycles)
oobb           output                                    Port B address out of range, ignored
=============  ============  ==========================  ==================================================
