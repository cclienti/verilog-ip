AXI Stream ICMP Echo Responder
==============================

Description
-----------

Answers ICMP echo requests. Consumes ICMP payload frames as the `IPv4
parser <../axi_stream_ipv4_parser/README.rst>`_ and `packet demux
<../../../lib/axi_stream_packet_demux/README.rst>`_ deliver them — cut
at ``total_length``, whole frames — with the parser side-bands on
``s_src_ip``/``s_dst_ip``/``s_length`` and the requester's MAC, from
the `eth parser <../axi_stream_eth_parser/README.rst>`_, on
``s_src_mac``; all are sampled with the frame's first beat. A frame is
consumed and ignored when it is not an echo request (type 8 code 0),
was sent to a broadcast destination (answering those is the smurf
amplifier), is shorter than the 8-byte echo header, does not fit the
payload buffer, carries ``tuser`` on any beat, or does not match
``s_length``. The only ``tuser`` that can arrive here is one within
``total_length``: an FCS flag lands on a padding beat the parser
swallows, so corrupt frames must be removed by the drop FIFO
upstream, as in the documented receive chain.

The identifier, sequence and data are buffered whole — headers go out
first, so store-and-forward is unavoidable — in a
``2**LOG2_DEPTH``-byte RAM, and the reply leaves as one complete
``34 + s_length``-byte Ethernet frame: MAC and IP headers built from
the sampled side-bands (TTL 64, DF set, a fresh header checksum), then
type 0 code 0 with the request's checksum incrementally adjusted per
RFC 1624 — the type field is the only change, so the offset is a
constant and the payload is never summed. The request checksum is
echoed as received, not verified. The reply relies on the `FCS
generator <../axi_stream_eth_fcs_gen/README.rst>`_ downstream padding
it to the minimum frame — a zero-data echo leaves here as 42 bytes.
The input holds ``tready`` low while a reply drains, like the `ARP
responder <../axi_stream_eth_arp/README.rst>`_, with a heavier
head-of-line consequence: a reply is up to ``34 + 2**LOG2_DEPTH``
beats, not ARP's fixed 42, and while it drains the whole receive
chain behind the demuxes stalls — the transmit merge must guarantee
forward progress and the receive FIFO's slack must absorb the drain.

Parameters
----------

- ``LOG2_DEPTH``: payload buffer size in bytes, log2 (default 11 —
  2048 bytes, any unfragmented ping on a 1500 MTU; at most 16, the
  width of the internal byte counter).

Signals
-------

- ``clock``, ``sreset``: clock and synchronous reset, active high.
- ``local_mac``, ``local_ip``: endpoint identity, sampled with each
  frame's first beat.
- ``s_axi_*``, ``s_src_ip``, ``s_dst_ip``, ``s_length``,
  ``s_src_mac``: AXI stream slave, ICMP payload frames with the parser
  side-bands.
- ``m_axi_*``: AXI stream master, complete Ethernet echo reply frames.
