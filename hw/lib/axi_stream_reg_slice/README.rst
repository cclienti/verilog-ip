AXI Stream Register Slice
=========================

Description
-----------

Full register slice (skid buffer) for an AXI stream link. Every signal
of both interfaces is driven by a register — the payload and ``tvalid``
through the output register, ``tready`` by the skid-occupied flag alone
— so no combinational arc crosses the slice in either direction. Insert
one anywhere a chain of modules passes ``tready`` through
combinationally (resizers, the FCS modules, the packet FIFO's lossless
mode) to cut the accumulated ready path, at the cost of one cycle of
latency and zero throughput.

A registered ``tready`` announces last cycle's willingness, so there is
always one exposed cycle where the master launches a beat into a slice
that just stalled; the skid register catches exactly that beat. Two
storage slots are what make the slice full-throughput: with a single
one, a registered ``tready`` could only sustain one beat every other
cycle. The externally visible contract is simply
``s_axi_tready == (beats in flight < 2)``, which the testbench checks on
every cycle.

Parameters
----------

- ``DATA_WIDTH``: beat width (default 8).
- ``USER_WIDTH``: tuser width (default 1).

Signals
-------

- ``clock``, ``sreset``: clock and synchronous reset, active high.
- ``s_axi_*``: AXI stream slave; ``tready`` is register-driven.
- ``m_axi_*``: AXI stream master, one cycle behind the input, all
  outputs registered.
