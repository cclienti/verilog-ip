Zedboard UDP Endpoint Demonstrator
==================================

Description
-----------

`rmii_eth_udp_endpoint
<../../../network/ethernet/rmii_eth_udp_endpoint/README.rst>`_ on a
Zedboard, live: the board answers ``arping`` and
``ping 192.168.90.42`` as the `ICMP demonstrator
<../eth_endpoint/README.rst>`__ does, and additionally echoes UDP
datagrams sent to port 7 — the classic echo port — so
``nc -u 192.168.90.42 7`` types back whatever you send, one datagram
per line. The echo is the socket's ``m_app`` stream wired straight
back to ``s_app`` here in the board wrapper — data, ``tlast`` and the
sender's MAC, IP and port together, so each reply goes back to
whoever sent it; the endpoint itself brings those streams out to
ports and holds no opinion about what connects them.

The board, the PHY, the clocking, the reset sequence and the pin
registers are identical to the `ICMP demonstrator
<../eth_endpoint/README.rst>`__ and the `TCP demonstrator
<../tcp_endpoint/README.rst>`_ — an `ethernet-pmod v2
<https://github.com/swetland/ethernet-pmod>`_ (LAN8720A) on Pmod JA,
the 50 MHz reference halved from the 100 MHz oscillator and forwarded
through an ODDR, transmit pins registered on the falling edge. The
ICMP README is the reference for the clock geometry, which is the
whole reason the wrapper exists; nothing about it changes here. The
four LEDs are the same: LD0 heartbeat, LD1 receive activity, LD2
transmit activity, LD3 the ARP-learn pulse.

The only differences from the TCP demonstrator are the endpoint
instance (``rmii_eth_udp_endpoint`` listening on port 7), the echo
loopback carrying three address fields alongside the data instead of
TCP's close token, and the smaller datapath a connectionless socket
needs — so this project is re-synthesized and its timing re-measured
rather than assumed from either earlier build.

Live test
---------

Once the link is up (LD1/LD2 blink on traffic), from a host on
192.168.90.0/24::

  arping 192.168.90.42          # the ARP responder
  ping 192.168.90.42            # the ICMP echo
  nc -u 192.168.90.42 7         # the UDP echo: type a line, it comes back

Each line ``nc -u`` sends is one datagram, echoed back as one
datagram. Unlike the TCP demonstrator there is no connection to open
or close and no option negotiation to muddy the first bytes; ``nc``
simply prints what comes back.

Testing
-------

The wrapper's clocking, reset and pin timing are proven by the smoke
testbench, the same one the ICMP and TCP demonstrators use, now over
the UDP endpoint: the forwarded clock is a 50 MHz square wave,
``nRST`` holds its 100 µs and releases before the MAC reset, no frame
leaves before then, and an ARP request comes back byte-exact with its
FCS at the PHY's timing — the transmit pins never move inside the
setup/hold window. ALL TESTS PASSED under ``check.iverilog`` and
``check.verilator``, ``lint.verilator`` clean. The UDP path through
the whole chain is proven at the network level by
``rmii_eth_udp_endpoint_tb``; the on-board ``nc -u`` session is the
live test, as ``ping`` is for the ICMP demonstrator.

Measured, Vivado 2026.1 on the -1 part, all constraints met: transmit
setup 5.198 ns and hold 7.759 ns, receive setup 0.610 ns and hold
3.392 ns — identical to the ICMP-only and TCP builds to the
picosecond, since those are IOB-to-pin register paths dominated by
fixed IBUF/OBUF/ODDR delays, untouched by anything in the fabric. The
fabric-domain (``refclk`` to ``refclk``) number: **0.283 ns** of setup
slack, 0.086 ns of hold, against 0.372 ns on the TCP build and
7.522 ns on the ICMP-only one. The critical path is the one the TCP
README already describes and leaves alone on purpose — it starts at
the front receive packet FIFO's block RAM read data, runs down the
whole parser chain, and closes back at that same FIFO's
``m_axi_tvalid`` register through its look-ahead read pointer, 30
logic levels and 16 CARRY4 — with one UDP-specific segment in the
middle: the socket's receive checksum fold. The fold sits on that
path because the doom flag depends on the checksum verdict and the
receive buffer's ``tready`` is combinational on the doom, so the
verdict propagates back up the chain as ready; the TCP receive parser
has the same structure, and the 89 ps difference between the two
builds is placement, not a different path. The transmit checksum —
the three-term fold that carries the length in with the last byte,
the one place this socket is arithmetically deeper than the TCP
receive fold — does not appear anywhere in the timing report: the
fabric-domain report names no ``tx_fold``, ``tx_checksum`` or
``txf_s_info`` net on any listed path, so the concern the socket
README raised about it is answered by measurement, not by argument.
1907 LUT, 1419 flops, 4 RAMB18 — one each for the front receive
packet FIFO, the ICMP payload buffer and the socket's receive and
transmit buffers, every one a 9-bit-wide 2048-entry RAM that fits a
RAMB18 exactly, checked against the implemented netlist's instance
names rather than inferred from the count — and no RAMB36 —
against the TCP build's 3555 LUT, 2592 flops and 1 RAMB36, and the
ICMP-only build's 997 LUT and 1172 flops. The connectionless transport
costs about half of what TCP's connection machine, ring, scheduler
and timers do, which is the whole design argument of the socket
README in one number.

On the wire, 2026-09-17: ``nc -u 192.168.90.42 7`` echoed
``Hello World!`` back byte for byte, the first live confirmation of
the UDP path end to end — receive parse, the doom-or-commit into the
receive buffer, the sender's address riding through the wrapper's
six-signal loopback, the transmit fold and header build — on the same
bitstream this README's figures were measured from. No connection to
open, nothing to negotiate: the line went out as one datagram and
came back as one.
