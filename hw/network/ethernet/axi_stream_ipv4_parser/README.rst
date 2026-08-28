AXI Stream IPv4 Parser
======================

Description
-----------

Strips the IPv4 header from the byte stream behind the `eth parser
<../axi_stream_eth_parser/README.rst>`_'s demux output and decodes it
for a second `packet demux
<../../../lib/axi_stream_packet_demux/README.rst>`_, one output per
transport protocol. Like the eth parser it never drops a payload beat
itself: ``m_sel`` carries the index of the protocol in the
``PROTOCOLS`` list — the lowest matching index wins — or
``NB_PROTOCOLS``, the demux discard code, when no entry matches or the
header fails validation: version/IHL other than ``0x45`` (options are
dead on modern networks and a variable-length header stage is not
worth them), a fragment (MF set or a non-zero offset), a header
checksum that does not verify, or a destination that is neither
``local_ip`` nor limited broadcast — whether to answer a broadcast is
the protocol block's policy, so the destination is exposed on
``m_dst_ip``.

The Ethernet minimum frame pads short IP packets, so the payload is
cut at ``total_length``: ``m_axi_tlast`` fires on the last real
payload byte and the padding is consumed silently. A frame that ends
before ``total_length`` is aborted with ``tuser`` on its final beat,
the receive drop convention. A frame with no L4 payload
(``total_length`` of 20 or less, or ending inside the header) emits
nothing, so a zero-beat frame can never reach the demux. Source and
destination IP, protocol and payload length are registered before the
first payload beat and stable to the last, the packet FIFO convention.

Parameters
----------

- ``NB_PROTOCOLS``: number of decoded protocols (default 1).
- ``PROTOCOLS``: packed list of protocol numbers, element *i* on bit
  slice ``[i*8 +: 8]``, matched to select code *i* (default ICMP
  ``0x01`` on 0).

Signals
-------

- ``clock``, ``sreset``: clock and synchronous reset, active high.
- ``local_ip``: endpoint identity, sampled with each frame's first
  beat.
- ``s_axi_*``: AXI stream slave, IPv4 frames from the eth parser's
  demux.
- ``m_axi_*``: AXI stream master, the L4 payload cut at
  ``total_length``.
- ``m_sel``, ``m_src_ip``, ``m_dst_ip``, ``m_protocol``,
  ``m_length``: decoded header side-band, stable for the whole payload
  frame.
