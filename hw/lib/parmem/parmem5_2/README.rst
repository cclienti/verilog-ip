Parallel Memory, 5 Prime-Interleaved Banks, Dual Strided-Group Front End
========================================================================

Description
-----------

The ``parmem5_2`` module is a member of the ``parmem`` prime-interleaved
family, at ``(NB_BANKS, NB_LANES) = (5, 2)``: five
true-dual-port, dual-clock memory banks (``dpmemrf``, READ_FIRST — i.e.
BRAM semantics) accessed as a **dual strided pair from one
instruction**:

- lane ``i`` (``i = 0, 1``) accesses ``EA_i = addr + i*stride``
  (``stride`` signed, in words);
- ``lane_en[i]`` enables lane ``i`` individually;
- both enabled lanes share ``wen``: a pair load (LD2) or a pair store
  (ST2) — a read/write mix cannot be expressed.

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
**484 LUTs, 5 RAMB36, clka WNS −0.13 ns** (≈ 195 MHz pessimistic bound
including ≈ 1 ns of OOC port artifacts — production-grade at L = 2).

Compared to ``parmem3_2`` (3 banks), the 5-bank interleave also serves
stride multiples of 3 conflict-free — only multiples of 5 conflict.

CRT (Chinese Remainder Theorem) addressing — **no divider**:

- ``bank(EA)  = EA mod 5`` — base-4 digit tree with alternating signs
  (``4 ≡ −1 mod 5``, casting out elevens), final reduction as a bounded
  constant modulo, one-hot output fused with the bank compare;
- ``index(EA) = EA mod 2^DEPTH`` — the low address bits, free.

Because ``gcd(5, 2^DEPTH) = 1`` this map is a bijection over the
``5 * 2^DEPTH``-word space. The pair collides iff ``stride ≡ 0 (mod 5)``
— so ``conflict`` is **one bit and a pure function of the stride residue
and the lane mask** (both lanes active), never of the addresses: the EA
adder stays out of the stall cone. It may assert together with ``oob*``;
the oob trap takes precedence. On conflict, lane 0 is served and lane 1
is dropped (by the steering priority itself — ``conflict`` is advisory;
lane 1's ``doa`` is invalid, its write is not performed). **Power-of-2
strides never conflict**.

Every EA is range-checked at **full width before truncation** (a negative
or overflowing sum can alias an in-range address): the test is
``sign | (top bits >= 5)`` — a one-LUT compare, no carry chain after the
adder. Out-of-range lanes are reported on ``oob[i]`` and suppressed
individually (the other lane proceeds).

Steering per bank: one 2:1 address mux, one 2:1 write-data mux, smart
enables (``wea_bank[b] = ena_bank[b] & wen``), lane-0 priority. The mux
selects use the lane-0 raw residue match with **lane 1 as default**,
keeping the EA adder and out-of-range logic off the address/data select
cone. Per lane: a 5:1 read-data bank mux whose select is the
**registered** bank id, aligned with the read latency.

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
wen            input                                     Write enable, shared by the pair (0 = read)
lane_en        input         [1:0]                       Per-lane enable (lane i at ``addr + i*stride``)
addr           input         [DEPTH+2:0]                 Linear word address of lane 0
stride         input         [STRIDE_W-1:0]              Signed word stride
dia            input         [2*WIDTH-1:0]               Lane write data (lane i at ``i*WIDTH``)
doa            output        [2*WIDTH-1:0]               Lane read data (1 + ADRREG + OUTREGA cycles)
conflict       output                                    ``stride % 5 == 0`` and both lanes: serialize
oob            output        [1:0]                       ``EA_i`` out of range, lane suppressed
clkb           input                                     Side B clock (network interface)
enb            input                                     Port B enable
web            input                                     Port B write enable (0 = read)
addrb          input         [DEPTH+2:0]                 Port B linear word address
dib            input         [WIDTH-1:0]                 Port B write data
dob            output        [WIDTH-1:0]                 Port B read data (1 + OUTREGB cycles)
oobb           output                                    Port B address out of range, ignored
=============  ============  ==========================  ==================================================
