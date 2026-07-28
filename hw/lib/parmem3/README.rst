Parallel Memory, 3 Prime-Interleaved Banks, Dual Load/Store Front End
=====================================================================

Description
-----------

The ``parmem3`` module implements the data memory of a VLIW dual load/store
unit: three true-dual-port, dual-clock memory banks (``dpmemrf``, READ_FIRST
on both ports — i.e. BRAM semantics) accessed as a **strided pair from one
instruction**:

- lane ``i`` (``i = 0, 1``) accesses ``EA_i = addr + i*stride``
  (``stride`` is signed, in words);
- ``lane_en[i]`` enables lane ``i`` individually;
- both enabled lanes share ``wen``: an LD2 (two loads) or an ST2 (two
  stores) — a read/write mix cannot be expressed.

The interface is shared with ``parmem5_2`` / ``parmem5_4`` / ``parmemn``
(per-lane enables, packed lane data), so the memories are interchangeable
under a common load/store unit — only the linear address width differs
(``DEPTH+2`` bits here vs ``DEPTH+3`` for the 5-bank variants).

``ADRREG = 1`` inserts a pipeline register at the end of the address
phase (bank enables/WE/address/data muxes and bank ids), breaking the
stride/addr worst-case paths before the bank access. ``conflict`` and
``oob`` are computed before the register, from the ports only, and
**stay combinational**: the issue-cycle contract is unchanged — only
the side-A read latency grows to ``1 + ADRREG + OUTREGA`` cycles (and
writes commit one cycle later, invisibly, in order).

CRT (Chinese Remainder Theorem) addressing — **no divider**:

- ``bank(EA)  = EA mod 3`` — a small digit-sum LUT tree (base-4 digits,
  since 4 ≡ 1 mod 3, "casting out threes");
- ``index(EA) = EA mod 2^DEPTH`` — the low address bits, free.

Because ``gcd(3, 2^DEPTH) = 1`` this map is a bijection over the
``3 * 2^DEPTH``-word space. The pair conflicts exactly when
``stride ≡ 0 (mod 3)`` — **power-of-2 strides never conflict**. On
conflict, lane 0 is served, lane 1 is dropped (its write is not performed
and its ``doa`` slice is **invalid**), and ``conflict`` requests
serialization from the caller; the same applies to a lane suppressed by
``oob*``. ``conflict`` is a **pure function of the stride residue and the
lane mask** (deliberately not gated by ``oob*``, which keeps the EA1
adder and range compare out of its cone — it is the caller's stall
request and the most timing-critical output); it may assert together with
``oob[1]``, in which case the oob trap takes precedence.

The **stride residue** (``stride mod 3``, corrected for the
two's-complement representation: the raw-pattern residue is off by
``2^STRIDE_W mod 3`` when the stride is negative) drives ``conflict``,
and lane 1's bank id is the **parallel residue**
``bank1 = (bank0 + residue) mod 3`` — computed in parallel with the EA1
adder (mod is a homomorphism). This was measured as the better of the
two implementations in the ``parmemn`` study (the former ``PARRES``
parameter is gone).

``EA1`` is range-checked at **full width before truncation**: a negative
or overflowing sum can alias an in-range address after truncation (e.g.
``DEPTH = 4``: ``0 + (-20)`` truncates to ``44 < 48``). The check is a
pure **3-bit test on the sum** — sign bit for negative, both top bits of
the in-range field for ``>= 3 * 2^DEPTH`` (which is ``"11" << DEPTH``) —
so no comparator carry chain follows the adder. Out-of-range lanes are
reported on ``oob[i]``/``oobb`` and suppressed individually (the other
lane proceeds).

Steering per bank: one address 2:1 mux, one write-data 2:1 mux, and smart
enables (``wea_bank[b] = ena_bank[b] & wen`` — the operation type is
shared, so a single write gate suffices); lane 0 has priority. The mux
selects use the lane-0 raw residue match with **lane 1 as default**,
keeping the EA1 adder and out-of-range logic off the address/data select
cone. Lane 1 is dropped on a conflict **by the steering priority itself**
— the ``conflict`` output is advisory to the caller, not part of the drop
mechanism. Per lane: a 3:1 read-data bank mux whose select is the
**registered** bank id, aligned with the read latency.

**Side B** (``clkb``, independent clock) is a single linear-addressed port
with its own CRT decode — e.g. a NoC network interface. A single requester
means no muxes (address/data broadcast, enable gating only) and no conflicts
by construction. The dual-clock banks are the clock-domain crossing.

Reads are synchronous (BRAM): side-A data is valid ``1 + ADRREG +
OUTREGA`` cycles after the access, side-B data ``1 + OUTREGB`` cycles
(``OUTREG*`` = BRAM output-register fmax option). READ_FIRST: a write
returns the pre-write content of the addressed
cell on the same port (the primitive behind an ``XCHW``-style exchange).
With ``OUTREG* = 1`` the ``dpmemrf`` output register is enable-gated: keep
the port enabled one extra cycle to flush the last read out.

The reference model (bijection, reverse map with constant-folded modular
inverse, conflict rule, NI walk strategies) is
``hw/vliw/study/crt_addressing.py``.

Parameters
----------

==========  ==============  ====================================================
Name        Default value   Description
==========  ==============  ====================================================
DEPTH       10              Log2 of words per bank (total ``3 * 2^DEPTH`` words)
WIDTH       32              Data width
STRIDE_W    12              Signed stride width, in words (must be <= DEPTH+2)
ADRREG      0               Address-phase pipeline register (+1 cycle, fmax option)
OUTREGA     0               Extra side-A output register (+1 cycle, fmax option)
OUTREGB     0               Extra side-B output register (+1 cycle, fmax option)
==========  ==============  ====================================================

Signals
-------

=============  ============  ==================  =========================================
Name           I/O type      Range               Description
=============  ============  ==================  =========================================
clka           input                             Side A clock (load/store unit)
en             input                             Side A enable
wen            input                             Write enable, shared by the pair (0 = read)
lane_en        input         [1:0]               Per-lane enable (lane i at ``addr + i*stride``)
addr           input         [DEPTH+1:0]         Linear word address of lane 0
stride         input         [STRIDE_W-1:0]      Signed word stride (EA1 = addr + stride)
dia            input         [2*WIDTH-1:0]       Lane write data (lane i at ``i*WIDTH``)
doa            output        [2*WIDTH-1:0]       Lane read data (1 + ADRREG + OUTREGA cycles)
conflict       output                            stride % 3 == 0 and both lanes: serialize
oob            output        [1:0]               ``EA_i`` out of range, lane suppressed
clkb           input                             Side B clock (network interface)
enb            input                             Port B enable
web            input                             Port B write enable (0 = read)
addrb          input         [DEPTH+1:0]         Port B linear word address
dib            input         [WIDTH-1:0]         Port B write data
dob            output        [WIDTH-1:0]         Port B read data (1 + OUTREGB cycles)
oobb           output                            Port B address out of range, ignored
=============  ============  ==================  =========================================
