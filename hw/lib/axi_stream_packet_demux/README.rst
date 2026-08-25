AXI Stream Packet Demux
=======================

Description
-----------

Frame-atomic route of one AXI stream to one of ``NB_OUTPUTS`` streams.
The route comes from the ``s_sel`` side-band, which the upstream parser
presents with the first beat (an EtherType or protocol field it has
already decoded); the demux samples it there and holds it to ``tlast``,
so a select that moves mid-frame cannot split a frame across outputs. A
select of ``NB_OUTPUTS`` or more discards the frame: it is consumed at
full rate and no output sees a beat — the unknown-EtherType branch of a
protocol tree comes for free.

Per-output buses are packed: output *i* owns bit slice ``[i*W +: W]``.
The ``INFO_WIDTH`` side-band passes through on the shared ``m_info``
bus, valid for whichever output is receiving the frame. The counterpart
merge is the `packet mux <../axi_stream_packet_mux/README.rst>`_, whose
testbench closes the two into a round trip.

Parameters
----------

- ``NB_OUTPUTS``: number of stream outputs (default 3).
- ``DATA_WIDTH``: beat width (default 8).
- ``INFO_WIDTH``: side-band word width (default 1).

Signals
-------

- ``clock``, ``sreset``: clock and synchronous reset, active high.
- ``s_axi_*``, ``s_sel``, ``s_info``: AXI stream slave with the
  per-frame route.
- ``m_axi_*``, ``m_info``: packed per-output AXI stream masters.
