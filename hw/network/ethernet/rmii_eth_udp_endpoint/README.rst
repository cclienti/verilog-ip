RMII Ethernet UDP Endpoint
==========================

Description
-----------

The Fast Ethernet endpoint carrying a UDP transport: the ARP and ICMP
device of the `RMII endpoint <../rmii_eth_endpoint/README.rst>`_ plus
one `UDP socket <../axi_stream_udp_socket/README.rst>`_ on the second
IPv4 demux output, with the socket's application streams and their
per-datagram address fields brought out to the endpoint ports. Wiring
``m_app`` straight back to ``s_app`` — data, ``tlast`` and the three
address fields together — outside the endpoint makes a UDP echo
server, answering ``nc -u`` to ``listen_port`` on top of ``arping`` and
``ping``; another user puts its own logic between the two streams. The
`Zedboard UDP demonstrator <../../boards/zedboard/udp_endpoint/README.rst>`_
is that echo build.

::

  RMII rx → upsizer → fcs_check → packet FIFO → eth parser → eth demux ─→ ARP ───────────────────────────┐
                                                                 └─→ IPv4 parser → ip demux ─→ ICMP ──────┤
                                                                                        └─→ UDP socket ──┤
  RMII tx ← downsizer ← fcs_gen ← packet mux ←──────────────────────────────────────────────────────────┘

Everything up to the eth demux is the documented receive chain. The
IPv4 parser now decodes two protocols, ICMP on demux output 0 and UDP
(protocol ``0x11``) on output 1; the transmit packet mux merges three
sources, ARP, ICMP and UDP. The socket takes the parser side-bands
(``s_src_ip``, ``s_dst_ip``, ``s_length``) and the sender's MAC from
the eth parser, exactly as the ICMP responder does, and emits complete
Ethernet reply frames into the mux.

The UDP block occupies the same **transport slot** — IP demux output 1
and packet mux input 2, selected by IP protocol — that `the TCP
endpoint <../rmii_eth_tcp_endpoint/README.rst>`_ occupies with TCP
instead, exclusively; only one of the two endpoints is ever built. That
slot remains the boundary along which a shared ``rmii_eth_endpoint_core``
would be extracted, now that a second transport exists to justify the
refactor — deferred until a build actually needs both transports at
once, which neither endpoint here does.

The socket never lowers its ``s_axi_tready``, so it does not stall the
receive chain and adds no head-of-line requirement on the packet FIFO
beyond the two responders' — ``LOG2_FIFO_DEPTH`` is unchanged from the
ARP/ICMP endpoint.

Parameters
----------

- ``LOG2_FIFO_DEPTH``, ``LOG2_ICMP_DEPTH``: as in the ARP/ICMP
  endpoint.
- ``LOG2_UDP_RX_DEPTH``, ``LOG2_UDP_RX_FRAMES`` (default 11, 6): the
  socket's receive buffer, in bytes and in datagrams, log2.
- ``LOG2_UDP_TX_DEPTH``, ``LOG2_UDP_TX_FRAMES`` (default 11, 6): the
  socket's transmit buffer, in bytes and in datagrams, log2. In an
  echo build keep ``LOG2_UDP_TX_DEPTH`` at least equal to
  ``LOG2_UDP_RX_DEPTH``: a datagram that passed the receive fit check
  is streamed whole into the transmit buffer, and one larger than that
  buffer deadlocks its writer for good, as the packet FIFO's README
  says of any oversized frame in backpressure mode. Nothing checks
  this at elaboration; the defaults satisfy it.

Signals
-------

- ``clock``, ``sreset``: 50 MHz RMII reference clock and synchronous
  reset, active high.
- ``local_mac``, ``local_ip``, ``listen_port``: endpoint identity and
  the UDP listening port. The responders sample them per frame; the
  UDP socket folds ``local_ip`` and ``listen_port`` into a datagram's
  checksum as it is written and reads them again as its header
  leaves, so they must hold still while any datagram is queued.
- ``phy_rxd``, ``phy_crs_dv``, ``phy_txd``, ``phy_txen``: the RMII PHY
  pins.
- ``learn_valid``, ``learn_mac``, ``learn_ip``: the ARP learn
  side-band.
- ``m_app_*``, ``m_app_peer_mac``/``peer_ip``/``peer_port``: the
  socket's received-datagram stream and the sender it came from,
  stable for that datagram's whole frame.
- ``s_app_*``, ``s_app_dst_mac``/``dst_ip``/``dst_port``: the socket's
  outgoing-datagram stream and the destination it goes to, sampled
  with its first beat. An echo build ties all six — data, ``tlast``
  and the three address fields — from the ``m_app_*`` set to the
  ``s_app_*`` set.

Testing
-------

The testbench drives the RMII pins at the wire level, frames built by
the `UDP model <../udp_model/README.rst>`_ with a real preamble and
FCS, and captures the transmit pins, strips the preamble and FCS, and
parses the reply with the same model. It ties ``m_app`` back to
``s_app``, address fields included, for the echo, then sends two
datagrams in turn from one station and a third from a second station,
and checks each reply is addressed back to the station that sent that
datagram — not the previous one — and echoes its payload byte-exact:
the chain is not one-shot, since a UDP datagram carries no connection
state to persist between them, and the per-datagram addressing that is
the whole point of the side-band survives the trip through the demux
and mux. 11 checks, ALL TESTS PASSED under ``check.iverilog`` and
``check.verilator``, ``lint.verilator`` clean. The socket carries its
own exhaustive bench; this one proves the integration and the
demux/mux routing.
