AXI Stream Ethernet ARP Responder
=================================

Description
-----------

Answers ARP requests for the local IPv4 address. Consumes ARP payload
frames as the `parser <../axi_stream_eth_parser/README.rst>`_ and
`packet demux <../../../lib/axi_stream_packet_demux/README.rst>`_
deliver them — header stripped, whole frames — and validates them on
the fly: HTYPE 1, PTYPE ``0x0800``, HLEN 6, PLEN 4, OPER request or
reply, target IP equal to ``local_ip``, at least the 28 ARP bytes
before any Ethernet padding, and no ``tuser``. Anything else is
consumed and ignored.

A valid request triggers a complete 42-byte Ethernet reply on the
master stream — destination the requester's SHA, source ``local_mac``,
EtherType ``0x0806``, then the is-at payload — ready for the `packet
mux <../../../lib/axi_stream_packet_mux/README.rst>`_ and the `FCS
generator <../axi_stream_eth_fcs_gen/README.rst>`_, which pads to the
minimum frame; no separate header-builder stage is needed. The input
holds ``tready`` low while a reply drains, the packet FIFO upstream
absorbs the stall. The stall holds the packet demux, so every receive
protocol waits on the reply draining: the transmit merge must
guarantee forward progress, which the round-robin `packet mux
<../../../lib/axi_stream_packet_mux/README.rst>`_ does.

Every valid packet, request or reply, fires the one-cycle
``learn_valid`` pulse with the sender's mapping on
``learn_mac``/``learn_ip``, for a future ARP cache; leave the port
open until then. ``local_mac`` and ``local_ip`` are sampled once per
frame with its first beat, so the target-IP compare and the emitted
reply always use the same identity.

Parameters
----------

None.

Signals
-------

- ``clock``, ``sreset``: clock and synchronous reset, active high.
- ``local_mac``, ``local_ip``: endpoint identity, sampled with each
  frame's first beat.
- ``s_axi_*``: AXI stream slave, ARP payload frames from the packet
  demux.
- ``m_axi_*``: AXI stream master, complete Ethernet reply frames.
- ``learn_valid``, ``learn_mac``, ``learn_ip``: sender mapping of
  every valid packet, one-cycle pulse.
