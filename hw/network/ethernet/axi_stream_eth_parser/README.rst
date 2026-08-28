AXI Stream Ethernet Parser
==========================

Description
-----------

Strips the 14-byte Ethernet header from a byte-wide AXI stream frame
and decodes it for the `packet demux
<../../../lib/axi_stream_packet_demux/README.rst>`_ downstream. The
destination and source MAC, the EtherType and the payload length are
presented on dedicated side-band outputs, registered before the first
payload beat and stable to the last, following the `packet FIFO
<../../../lib/axi_stream_packet_fifo/README.rst>`_ convention.

``m_sel`` carries the index of the EtherType in the ``ETHERTYPES``
list — the lowest matching index wins — or ``NB_ETHERTYPES``, the
demux discard code, when no entry matches or the destination filter
rejects the frame: not promiscuous, not the local MAC, not broadcast —
nor, with ``ACCEPT_MULTICAST``, any group address (I/G bit); per-group
filtering belongs to the protocol layer that knows its joined
addresses. The parser itself never drops a payload beat; steering an
unwanted frame at the discard code is what makes it vanish in the
demux, consumed at full rate with no output beat.

``m_length`` is ``s_length`` minus the header, for a producer that
delivers the frame length on the first beat (the packet FIFO
``m_length``); tie ``s_length`` off and ignore ``m_length`` when no
length is available. A frame whose ``tlast`` falls inside the header
is consumed and nothing is emitted, so a zero-beat frame can never
reach the demux. ``tuser`` passes through on payload beats; on header
beats it is ignored.

Parameters
----------

- ``NB_ETHERTYPES``: number of decoded EtherTypes (default 2).
- ``ETHERTYPES``: packed list of EtherTypes, element *i* on bit slice
  ``[i*16 +: 16]``, matched to select code *i* (default IPv4 ``0x0800``
  on 0, ARP ``0x0806`` on 1).
- ``LENGTH_WIDTH``: width of the length side-band (default 12, the
  packet FIFO ``LOG2_DEPTH + 1``).
- ``ACCEPT_MULTICAST``: widen the broadcast accept to any group
  address, all-or-nothing (default 0).

Signals
-------

- ``clock``, ``sreset``: clock and synchronous reset, active high.
- ``local_mac``, ``promiscuous``: endpoint identity, sampled once per
  frame with the last header byte.
- ``s_axi_*``, ``s_length``: AXI stream slave, whole frames with the
  length on the first beat.
- ``m_axi_*``: AXI stream master, the payload.
- ``m_sel``, ``m_dst_mac``, ``m_src_mac``, ``m_ethertype``,
  ``m_length``: decoded header side-band, stable for the whole payload
  frame.
