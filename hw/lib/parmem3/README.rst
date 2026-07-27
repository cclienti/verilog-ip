Parallel Memory, 3 Prime-Interleaved Banks, Dual Load/Store Front End
=====================================================================

Description
-----------

The ``parmem3`` module implements the data memory of a VLIW dual load/store
unit: three true-dual-port, dual-clock memory banks (``dpmemrf``, READ_FIRST
on both ports — i.e. BRAM semantics) accessed as a **strided pair from one
instruction**:

- ``dual = 0``: single access at ``EA0 = addr``;
- ``dual = 1``: pair access at ``EA0 = addr`` and ``EA1 = addr + stride``
  (``stride`` is signed, in words). Both accesses share ``wen``: an LD2
  (two loads) or an ST2 (two stores) — a read/write mix cannot be expressed.

CRT (Chinese Remainder Theorem) addressing — **no divider**:

- ``bank(EA)  = EA mod 3`` — a small digit-sum LUT tree (base-4 digits,
  since 4 ≡ 1 mod 3, "casting out threes");
- ``index(EA) = EA mod 2^DEPTH`` — the low address bits, free.

Because ``gcd(3, 2^DEPTH) = 1`` this map is a bijection over the
``3 * 2^DEPTH``-word space. The pair conflicts exactly when
``stride ≡ 0 (mod 3)`` — **power-of-2 strides never conflict**. On conflict,
access 0 is served, access 1 is dropped (its write is not performed and
``doa1`` is **invalid**), and ``conflict`` requests serialization from the
caller; the same applies to an access suppressed by ``oob*``. ``conflict`` is a **pure function of the
stride residue** (deliberately not gated by ``oob*``, which keeps the EA1
adder and range compare out of its cone — it is the caller's stall request
and the most timing-critical output); it may assert together with ``oob1``,
in which case the oob trap takes precedence.

The **stride residue** (``stride mod 3``, corrected for the two's-complement
representation: the raw-pattern residue is off by ``2^STRIDE_W mod 3`` when
the stride is negative) is computed in every build — it drives ``conflict``.
``bank1`` is then computed two ways, selected by the ``PARRES`` parameter for
timing comparison (functionally identical, cross-checked in the testbench
by a second DUT instance):

- ``PARRES = 1`` (default): ``bank1 = (bank0 + residue) mod 3`` — **in
  parallel** with the EA1 adder (mod is a homomorphism);
- ``PARRES = 0``: ``bank1 = mod3(EA1)`` — adder and mod-3 tree in series.

``EA1`` is range-checked at **full width before truncation**: a negative or
overflowing sum can alias an in-range address after truncation (e.g.
``DEPTH = 4``: ``0 + (-20)`` truncates to ``44 < 48``). The check is a pure
**3-bit test on the sum** — sign bit for negative, both top bits of the
in-range field for ``>= 3 * 2^DEPTH`` (which is ``"11" << DEPTH``) — so no
comparator carry chain follows the adder. Out-of-range accesses are
reported on ``oob0``/``oob1``/``oobb`` and suppressed.

Steering per bank: one address 2:1 mux, one write-data 2:1 mux, and smart
enables (``wea_bank[b] = ena_bank[b] & wen`` — the operation type is shared,
so a single write gate suffices); access 0 has priority on every select.
Access 1 is dropped on a conflict **by the steering priority itself**
(``sel1[b] = ... & ~sel0[b]``) — the ``conflict`` output is advisory to the
caller, not part of the drop mechanism. Per access: a 3:1 read-data bank
mux whose select is the **registered** bank id, aligned with the read
latency.

**Side B** (``clkb``, independent clock) is a single linear-addressed port
with its own CRT decode — e.g. a NoC network interface. A single requester
means no muxes (address/data broadcast, enable gating only) and no conflicts
by construction. The dual-clock banks are the clock-domain crossing.

Reads are synchronous (BRAM): data is valid **1 cycle** after the access
(2 cycles with ``OUTREGA``/``OUTREGB`` = 1, the BRAM output-register fmax
option). READ_FIRST: a write returns the pre-write content of the addressed
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
OUTREGA     0               Extra side-A output register (+1 cycle, fmax option)
OUTREGB     0               Extra side-B output register (+1 cycle, fmax option)
PARRES      1               bank1: 1 = parallel residue, 0 = mod3 of the EA1 sum
==========  ==============  ====================================================

Signals
-------

=============  ============  ==================  =========================================
Name           I/O type      Range               Description
=============  ============  ==================  =========================================
clka           input                             Side A clock (load/store unit)
en             input                             Side A enable
wen            input                             Write enable, shared by the pair (0 = read)
dual           input                             1 = pair access, 0 = single access
addr           input         [DEPTH+1:0]         Linear word address of access 0
stride         input         [STRIDE_W-1:0]      Signed word stride (EA1 = addr + stride)
dia0           input         [WIDTH-1:0]         Access 0 write data
dia1           input         [WIDTH-1:0]         Access 1 write data
doa0           output        [WIDTH-1:0]         Access 0 read data (1 + OUTREGA cycles)
doa1           output        [WIDTH-1:0]         Access 1 read data (1 + OUTREGA cycles)
conflict       output                            stride % 3 == 0: access 1 dropped, serialize
oob0           output                            EA0 out of range, access suppressed
oob1           output                            EA1 out of range, access suppressed
clkb           input                             Side B clock (network interface)
enb            input                             Port B enable
web            input                             Port B write enable (0 = read)
addrb          input         [DEPTH+1:0]         Port B linear word address
dib            input         [WIDTH-1:0]         Port B write data
dob            output        [WIDTH-1:0]         Port B read data (1 + OUTREGB cycles)
oobb           output                            Port B address out of range, ignored
=============  ============  ==================  =========================================
