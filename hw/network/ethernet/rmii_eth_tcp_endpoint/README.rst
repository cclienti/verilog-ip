RMII Ethernet TCP Endpoint
==========================

Description
-----------

The Fast Ethernet endpoint carrying a TCP transport: the ARP and ICMP
device of the `RMII endpoint <../rmii_eth_endpoint/README.rst>`_ plus
one passive `TCP socket <../axi_stream_tcp_socket/README.rst>`_ on the
second IPv4 demux output, with the socket's application streams
brought out to the endpoint ports. Wiring ``m_app`` straight back to
``s_app`` outside the endpoint makes an echo server, answering
``telnet`` or ``nc`` to ``listen_port`` on top of ``arping`` and
``ping``; another user puts its own logic between the two streams. The
`Zedboard TCP demonstrator
<../../boards/zedboard/tcp_endpoint/README.rst>`_ is that echo build.

::

  RMII rx → upsizer → fcs_check → packet FIFO → eth parser → eth demux ─→ ARP ───────────────────────────┐
                                                                 └─→ IPv4 parser → ip demux ─→ ICMP ──────┤
                                                                                        └─→ TCP socket ──┤
  RMII tx ← downsizer ← fcs_gen ← packet mux ←──────────────────────────────────────────────────────────┘

Everything up to the eth demux is the documented receive chain. The
IPv4 parser now decodes two protocols, ICMP on demux output 0 and TCP
(protocol 6) on output 1; the transmit packet mux merges three
sources, ARP, ICMP and TCP. The socket takes the parser side-bands
(``s_src_ip``, ``s_dst_ip``, ``s_length``) and the requester MAC from
the eth parser, exactly as the ICMP responder does, and emits complete
Ethernet reply frames into the mux.

The TCP block occupies a **transport slot** — IP demux output 1 and
packet mux input 2, selected by IP protocol — that `the UDP endpoint
<../rmii_eth_udp_endpoint/README.rst>`_ occupies with UDP instead,
exclusively; only one of the two endpoints is ever built. That slot
remains the boundary along which a shared ``rmii_eth_endpoint_core``
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
- ``LOG2_TCP_RX_DEPTH``, ``LOG2_TCP_TX_DEPTH`` (default 11): the
  socket's receive buffer and transmit ring in bytes, log2.
- ``TCP_MSS`` (default 1460), ``TCP_RTO_CLOCKS`` (default 10 000 000,
  200 ms at 50 MHz), ``TCP_MAX_RETRIES`` (default 8),
  ``TCP_IDLE_CLOCKS`` (default 10 minutes): the socket's transport
  parameters.

Signals
-------

- ``clock``, ``sreset``: 50 MHz RMII reference clock and synchronous
  reset, active high.
- ``local_mac``, ``local_ip``, ``listen_port``: endpoint identity and
  the TCP passive-open port.
- ``phy_rxd``, ``phy_crs_dv``, ``phy_txd``, ``phy_txen``: the RMII PHY
  pins.
- ``learn_valid``, ``learn_mac``, ``learn_ip``: the ARP learn
  side-band.
- ``tcp_connected``, ``tcp_peer_ip``, ``tcp_peer_port``: the TCP
  connection status, the peer valid while connected.
- ``m_app_*``, ``s_app_*``: the socket's application streams, received
  payload out and bytes to send in, ``tuser`` the close token on both.
  An echo build ties ``m_app`` to ``s_app`` externally.

Testing
-------

The testbench drives the RMII pins at the wire level, frames built by
the `TCP model <../tcp_model/README.rst>`_ with a real preamble and
FCS, and captures the transmit pins, strips the preamble and FCS, and
parses the reply with the same model. It ties ``m_app`` back to
``s_app`` for the echo, then walks a TCP connection through the whole
chain: SYN to SYN-ACK, the ACK to established with the peer reported,
a data segment echoed byte-exact, and the close.
9 checks, ALL TESTS PASSED under ``check.iverilog`` and
``check.verilator``, ``lint.verilator`` clean. The socket and its
sub-blocks carry their own exhaustive benches; this one proves the
integration and the demux/mux routing.
