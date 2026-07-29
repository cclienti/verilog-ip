Parallel Memory, 11 Prime-Interleaved Banks, 8-Lane Strided-Group Front End
===========================================================================

Description
-----------

The ``parmem11_8`` module is a member of the ``parmem`` prime-interleaved
family, at ``(NB_BANKS, NB_LANES) = (11, 8)``: eleven
true-dual-port, dual-clock memory banks (``dpmemrf``, READ_FIRST — i.e.
BRAM semantics) accessed as an **8-lane strided group from one
instruction**:

- lane ``i`` (``i = 0 .. 7``) accesses ``EA_i = addr + i*stride``
  (``stride`` signed, in words);
- ``lane_en[i]`` enables lane ``i`` individually (vector tails come free);
- all enabled lanes share ``wen``: a group load (LD8) or a group store
  (ST8) — a read/write mix cannot be expressed.

**Validity domain** (measured, ``hw/lib/parmem/doc/RESULTS.md``): the
combinational M11L8 point costs **4 037 LUTs / 11 RAMB36** and misses a
5 ns budget by **−7.0 ns** on xc7z020-1 — it is *not* a single-cycle
memory on slow 7-series fabric. This component exists for faster fabrics
(Kintex-7/UltraScale+) and for the ``ADRREG`` pipelined operating point;
in the study's architecture analysis this lane count is the region where
a SIMD unit with a single aligned wide memory port becomes preferable to
banking (RESULTS.md §5, item 5).

``ADRREG = 1`` registers the end of the address phase (bank
enables/WE/address/data muxes and bank ids), before the bank access.
``conflict`` and ``oob`` are computed before the register, from the
ports only, and **stay combinational**: the issue-cycle contract is
unchanged — only the side-A read latency grows to
``1 + ADRREG + OUTREGA`` cycles (writes commit one cycle later,
invisibly, in order).

CRT (Chinese Remainder Theorem) addressing — **no divider**:

- ``bank(EA)  = EA mod 11`` — seven base-32 digits folded with
  alternating signs (``32 ≡ −1 mod 11``, casting out elevens), final
  reduction as a bounded constant modulo, one-hot output fused with the
  bank compare;
- ``index(EA) = EA mod 2^DEPTH`` — the low address bits, free.

Because ``gcd(11, 2^DEPTH) = 1`` this map is a bijection over the
``11 * 2^DEPTH``-word space. With 11 prime and 8 ≤ 11 lanes, all lanes
are pairwise conflict-free **iff** ``stride ≢ 0 (mod 11)`` — so
``conflict`` is **one bit and a pure function of the stride residue and
the lane mask** (>= 2 active lanes), never of the addresses. It may
assert together with ``oob*``; the oob trap takes precedence. On
conflict, the lowest enabled lane is served and the other active lanes
are dropped (by the steering priority itself — ``conflict`` is advisory;
dropped lanes' ``doa`` is invalid, their writes are not performed).
**Power-of-2 strides never conflict**.

Lane EAs are computed by **parallel adders** (``i*stride`` as constant
shift-adds, at most 2 adds for i ≤ 7), and lane bank ids in **constant
depth**: ``bank_i = (bank_0 + i*scorr) mod 11``, where ``scorr`` is the
sign-corrected stride residue and ``(i*scorr) mod 11`` a 4-bit LUT
function (a chained form was measured at 21+ logic levels at this lane
count).

Every EA is range-checked at **full width before truncation** (a negative
or overflowing sum can alias an in-range address): the test is
``sign | (top bits >= 11)`` — a one-LUT compare, no carry chain after the
adder. Out-of-range lanes are reported on ``oob[i]`` and suppressed
individually (other lanes proceed).

Steering per bank: one 8:1 address mux, one 8:1 write-data mux (one-hot
AND-OR), smart enables (``wea_bank[b] = ena_bank[b] & wen``),
lowest-lane priority. The mux selects use the first raw residue match
among lanes 0..6 with **lane 7 as default**, keeping the adders and
out-of-range logic off the address/data select cone. Per lane: an 11:1
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

==========  ==============  =====================================================
Name        Default value   Description
==========  ==============  =====================================================
DEPTH       10              Log2 of words per bank (total ``11 * 2^DEPTH`` words)
WIDTH       32              Data width
STRIDE_W    12              Signed stride width, in words (<= DEPTH + 4)
ADRREG      0               Address-phase pipeline register (+1 cycle, fmax option)
OUTREGA     0               Extra side-A output register (+1 cycle, fmax option)
OUTREGB     0               Extra side-B output register (+1 cycle, fmax option)
==========  ==============  =====================================================

Signals
-------

=============  ============  ==========================  ==================================================
Name           I/O type      Range                       Description
=============  ============  ==========================  ==================================================
clka           input                                     Side A clock (load/store unit)
en             input                                     Side A enable
wen            input                                     Write enable, shared by the group (0 = read)
lane_en        input         [7:0]                       Per-lane enable (lane i at ``addr + i*stride``)
addr           input         [DEPTH+3:0]                 Linear word address of lane 0
stride         input         [STRIDE_W-1:0]              Signed word stride
dia            input         [8*WIDTH-1:0]               Lane write data (lane i at ``i*WIDTH``)
doa            output        [8*WIDTH-1:0]               Lane read data (1 + ADRREG + OUTREGA cycles)
conflict       output                                    ``stride % 11 == 0`` and >= 2 lanes: serialize
oob            output        [7:0]                       ``EA_i`` out of range, lane suppressed
clkb           input                                     Side B clock (network interface)
enb            input                                     Port B enable
web            input                                     Port B write enable (0 = read)
addrb          input         [DEPTH+3:0]                 Port B linear word address
dib            input         [WIDTH-1:0]                 Port B write data
dob            output        [WIDTH-1:0]                 Port B read data (1 + OUTREGB cycles)
oobb           output                                    Port B address out of range, ignored
=============  ============  ==========================  ==================================================
