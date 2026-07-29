Prime-Interleaved Parallel Memory Family (parmem)
=================================================

Description
-----------

The ``parmem`` family provides scratchpad memories built from **M
prime-interleaved banks** (true-dual-port, dual-clock BRAM — ``dpmemrf``,
READ_FIRST) serving an **L-lane strided access group from one
instruction**:

- lane ``i`` (``i = 0 .. L-1``) accesses ``EA_i = addr + i*stride``
  (``stride`` signed, in words);
- ``lane_en[i]`` enables lane ``i`` individually (vector tails come free);
- all enabled lanes share ``wen``: a group load (LDn) or a group store
  (STn) — a read/write mix cannot be expressed.

Addressing is CRT-based (Chinese Remainder Theorem) — **no divider**:
``bank = EA mod M`` (a digit-sum LUT tree exploiting ``2^d ≡ ±1 mod M``)
and ``index = EA mod 2^DEPTH`` (the low address bits). Since
``gcd(M, 2^DEPTH) = 1`` the map is a bijection over the ``M * 2^DEPTH``
word space. With M prime and L ≤ M, the group is conflict-free **iff**
``stride ≢ 0 (mod M)`` — ``conflict`` is one bit, a pure function of the
stride residue and the lane mask (power-of-2 strides never conflict).
Every EA is range-checked at full width before truncation and reported
per lane on ``oob[i]``.

**Side B** is a single linear-addressed port on its own clock with its
own CRT decode — e.g. a NoC network interface; the dual-clock banks are
the clock-domain crossing.

Components
----------

All components share the same interface style (per-lane enables, packed
lane data; only the linear address width differs with M) and are
interchangeable under a common load/store unit.

===============  ====  ====  =======================================================
Component        M     L     Status on a 5 ns (200 MHz) OOC budget
===============  ====  ====  =======================================================
``parmem3_2``    3     2     Single-cycle on all fabrics (meets outright on Zynq)
``parmem5_2``    5     2     Single-cycle on all fabrics; strides ×3 conflict-free
``parmem5_4``    5     4     Single-cycle from Kintex-7; ADRREG on Zynq-7000
``parmem11_8``   11    8     Single-cycle on Kintex UltraScale+ only
``parmem17_16``  17    16    Burroughs-BSP configuration; near-miss on UltraScale+
===============  ====  ====  =======================================================

See each component's ``README.rst`` for its full contract and
``doc/RESULTS.md`` for the study behind the family: the six measured
design techniques, the (M × L) scaling law (LUTs ≈ 45–50 · L · M), the
cross-fabric feasibility boundary (L ≤ 2 on Zynq-7000, L ≤ 4 on
Kintex-7, L ≤ 8 on Kintex UltraScale+), and the architectural
consequence (beyond the boundary, a SIMD unit with an aligned wide
memory port replaces banking).

Common parameters and latency
-----------------------------

==========  ==========================================================
Name        Description
==========  ==========================================================
DEPTH       Log2 of words per bank (total ``M * 2^DEPTH`` words)
WIDTH       Data width
STRIDE_W    Signed stride width, in words (<= linear address width)
ADRREG      Address-phase pipeline register (+1 cycle, fmax option)
OUTREGA/B   BRAM output register per side (+1 cycle, fmax option)
==========  ==========================================================

Side-A reads return in ``1 + ADRREG + OUTREGA`` cycles, side-B reads in
``1 + OUTREGB`` cycles. ``ADRREG`` registers the bank
enables/WE/address/data muxes and bank ids **after** conflict/oob are
derived from the ports, so both stay **combinational in the issue
cycle** — pipelining trades data latency only, never the stall/trap
contract. The ``dpmemrf`` output register is enable-gated: hold the
enable one extra cycle to flush. READ_FIRST: a write returns the
pre-write content of the addressed cell.

Verification and fmax methodology
---------------------------------

Each component has a self-checking testbench (bijection, signed-stride
group accesses, conflict rule, per-lane out-of-range including the
truncation-alias trap, partial lane masks, dual-clock NI port, ADRREG
and OUTREG variants) run with ``make sim``, and an out-of-context
Vivado flow (``project/Makefile`` + component xdc: 5 ns clocks, async
clock groups, zero I/O delays, port-hold false path) for post-route
area/timing measurement; results are archived under
``project/results/<part>-<config>/``.

The Python reference model (bijection, reverse map with constant-folded
modular inverse, conflict rule, NI walk strategies) is
``hw/vliw/study/crt_addressing.py``.
