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

Measured, Vivado 2026.1 on the -1 part, all constraints met:

- fabric (``refclk`` to ``refclk``) setup slack 1.406 ns, hold
  0.037 ns;
- transmit pins setup 5.198 ns, hold 7.759 ns; receive pins setup
  0.610 ns, hold 3.392 ns — IOB-to-pin register paths, fixed buffer
  delays, untouched by the fabric;
- 1659 LUT as logic and 294 as distributed RAM — the latter the
  socket's two 64-deep ``INFO`` stores, the cost of ``LOG2_*_FRAMES``
  at its default of 6 — 1595 flops, 2 block RAM tiles as 4 RAMB18:
  the front receive FIFO, the ICMP buffer and the socket's two
  buffers, one each, checked against the netlist's instance names.

How this build stands against the other two demonstrators is tabled
once, in the `chain README <../../../network/ethernet/README.rst>`_.

The fabric slack took two builds. As first built, 0.283 ns: the
critical path was the front receive FIFO's look-ahead valid loop,
with the socket's receive checksum fold on it, since the receive
buffer's backpressure-mode ``tready`` is combinational on the doom and
the doom on the verdict. That ``tready`` could never fall — the fit
check admits only what has room — so the buffer now runs in
``DROP_ON_FULL`` mode for the constant ``tready`` it gives: same 294
and 11 checks, the fold off the ready path, and the critical path now
the transmit fold itself, 27 levels with 1.4 ns to spare. The first
build predates the review-fix commit (its four address latches are
the 176 extra flops, on side-band paths off the critical one), so the
gain is attributed to the buffer mode by argument; a build of that
commit alone would confirm it and has not been run.

On the wire, 2026-09-17, on the first build's bitstream: ``nc -u
192.168.90.42 7`` echoed ``Hello World!`` back byte for byte — the
UDP path end to end, one datagram out, one back. The second build has
not been programmed.
