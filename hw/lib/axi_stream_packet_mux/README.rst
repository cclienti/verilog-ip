AXI Stream Packet Mux
=====================

Description
-----------

Frame-atomic round-robin merge of ``NB_INPUTS`` AXI streams into one. A
frame is granted at its first beat and the grant is locked until its
``tlast`` beat is accepted, whatever ``tvalid`` does in between — a slow
producer stretches its frame, it is never interleaved. The rotation
pointer moves past the granted input at every frame end, so contending
inputs are served strictly in turn and none can starve. One idle cycle
separates frames (the grant is registered).

Arbitration is a rotating-priority pointer rather than `prra
<../prra/README.rst>`_: prra holds its grant until the request *signal*
drops, which fits level-held requesters, while a packet mux must rotate
at frame boundaries even when the same source immediately presents its
next frame.

Per-input buses are packed: input *i* owns bit slice ``[i*W +: W]``. The
``INFO_WIDTH`` side-band follows the packet-FIFO convention: each
producer holds ``s_info`` stable for its whole frame, and the granted
input's word is presented on ``m_info`` for the whole output frame —
which is how a downstream `packet demux
<../axi_stream_packet_demux/README.rst>`_ or header builder knows the
frame's origin or route.

Parameters
----------

- ``NB_INPUTS``: number of stream inputs (default 3).
- ``DATA_WIDTH``: beat width (default 8).
- ``INFO_WIDTH``: side-band word width per input (default 1).

Signals
-------

- ``clock``, ``sreset``: clock and synchronous reset, active high.
- ``s_axi_*``, ``s_info``: packed per-input AXI stream slaves.
- ``m_axi_*``, ``m_info``: merged AXI stream master, one frame at a
  time.
