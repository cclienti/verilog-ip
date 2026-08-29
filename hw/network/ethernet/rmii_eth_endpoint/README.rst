RMII Ethernet Endpoint
======================

Description
-----------

The whole Fast Ethernet stack closed into one component: an ARP/ICMP
endpoint between the RMII pins of a PHY, in a single 50 MHz clock
domain. It answers ARP requests and ICMP echo requests for
``local_ip`` — enough to ``ping`` the device — and consumes everything
else silently.

::

  RMII rx → upsizer → fcs_check → packet FIFO → eth parser → eth demux ──→ ARP ─────────────────────┐
                                                                 └──→ IPv4 parser → ip demux → ICMP ┤
                                                                                                    │
  RMII tx ← downsizer ← fcs_gen ← packet mux ←──────────────────────────────────────────────────────┘

The receive side carries the seam glue the `chain README
<../README.rst>`_ documents: the upsizer's per-dibit ``tuser`` and
``tkeep`` reduced into the checker's single error bit, and the `packet
FIFO <../../../lib/axi_stream_packet_fifo/README.rst>`_ in
DROP_ON_FULL mode so FCS-flagged frames vanish and the MAC — which
cannot pause the wire — is never stalled. On the transmit side the
round-robin `packet mux <../../../lib/axi_stream_packet_mux/README.rst>`_
merges the two responders, guaranteeing the forward progress their
head-of-line stall requires, and the `FCS generator
<../axi_stream_eth_fcs_gen/README.rst>`_ pads short replies to the
minimum frame. The requester MAC side-band rides from the eth parser
around the IPv4 layer into the ICMP responder: the chain is strictly
serialized while a frame is in flight, so the side-band cannot change
before its sample. The eth parser runs with promiscuous off and
multicast accept off.

The testbench works at the wire level: frames with preamble, SFD and a
real FCS are driven onto the receive pins at line rate, and the
transmit pins are captured dibit by dibit — preamble and inter-frame
gap verified, replies compared byte-exact against independently
computed expectations, checksums and FCS included. That independence
matters: it caught a checksum bug the ICMP block's own bench was blind
to, because bench and RTL shared the same faulty expression.

Parameters
----------

- ``LOG2_FIFO_DEPTH``: receive packet FIFO size in bytes, log2
  (default 11 — 2048 bytes; it must absorb the receive chain stalling
  for a full reply drain, up to ``34 + 2**LOG2_ICMP_DEPTH`` bytes).
- ``LOG2_ICMP_DEPTH``: ICMP payload buffer size in bytes, log2
  (default 11 — any unfragmented ping on a 1500 MTU).

Signals
-------

- ``clock``, ``sreset``: 50 MHz RMII reference clock and synchronous
  reset, active high.
- ``local_mac``, ``local_ip``: endpoint identity, sampled per frame by
  the protocol blocks; constants or run-time values both work.
- ``phy_rxd``, ``phy_crs_dv``: RMII receive pins from the PHY.
- ``phy_txd``, ``phy_txen``: RMII transmit pins to the PHY.
- ``learn_valid``, ``learn_mac``, ``learn_ip``: sender mapping of
  every valid ARP packet, one-cycle pulse, for a future ARP cache.
