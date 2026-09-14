Zedboard TCP Endpoint Demonstrator
==================================

Description
-----------

`rmii_eth_tcp_endpoint
<../../../network/ethernet/rmii_eth_tcp_endpoint/README.rst>`_ on a
Zedboard, live: the board answers ``arping`` and
``ping 192.168.90.42`` as the `ICMP demonstrator
<../eth_endpoint/README.rst>`__ does, and additionally echoes a TCP
connection to port 23, so ``telnet 192.168.90.42`` or ``nc
192.168.90.42 23`` types back whatever you send. The echo is the
socket's ``m_app`` stream wired straight back to ``s_app`` here in the
board wrapper, close token included; the endpoint itself brings those
streams out to ports and holds no opinion about what connects them.

The board, the PHY, the clocking, the reset sequence and the pin
registers are identical to the `ICMP demonstrator
<../eth_endpoint/README.rst>`__ — an `ethernet-pmod v2
<https://github.com/swetland/ethernet-pmod>`_ (LAN8720A) on Pmod JA,
the 50 MHz reference halved from the 100 MHz oscillator and forwarded
through an ODDR, transmit pins registered on the falling edge. That
README is the reference for the clock geometry, which is the whole
reason the wrapper exists; nothing about it changes here. The four
LEDs are the same: LD0 heartbeat, LD1 receive activity, LD2 transmit
activity, LD3 the ARP-learn pulse.

The only differences from the ICMP demonstrator are the endpoint
instance (``rmii_eth_tcp_endpoint`` with a listen port of 23), the
application echo loopback in the wrapper, and the larger datapath the
TCP socket adds — so this project must be re-synthesized and its
timing re-measured rather than assumed from the ICMP build.

Live test
---------

Once the link is up (LD1/LD2 blink on traffic), from a host on
192.168.90.0/24::

  arping 192.168.90.42          # the ARP responder
  ping 192.168.90.42            # the ICMP echo
  nc 192.168.90.42 23           # the TCP echo: type, and it comes back

Prefer ``nc`` to ``telnet`` for the first try: telnet opens with
option negotiation, which the echo bounces back and the client
resolves, but it muddies the first bytes on the screen.

Testing
-------

The wrapper's clocking, reset and pin timing are proven by the smoke
testbench, the same one the ICMP demonstrator uses, now over the TCP
endpoint: the forwarded clock is a 50 MHz square wave, ``nRST`` holds
its 100 µs and releases before the MAC reset, no frame leaves before
then, and an ARP request comes back byte-exact with its FCS at the
PHY's timing — the transmit pins never move inside the setup/hold
window. ALL TESTS PASSED under ``check.iverilog`` and
``check.verilator``, ``lint.verilator`` clean. The TCP path through
the whole chain is proven at the network level by
``rmii_eth_tcp_endpoint_tb``; the on-board ``nc`` session is the live
test, as ``ping`` is for the ICMP demonstrator.

Measured, Vivado 2026.1 on the -1 part, all constraints met: transmit
setup 5.198 ns and hold 7.759 ns, receive setup 0.610 ns and hold
3.392 ns — identical to the ICMP-only build to the picosecond, since
those paths are IOB-to-pin register paths dominated by fixed
IBUF/OBUF/ODDR delays, untouched by anything added in the fabric.
The fabric-domain (``refclk`` to ``refclk``) number is the one that
moved: **0.372 ns** of setup slack, 0.121 ns of hold, against 7.522 ns
on the ICMP-only build — the TCP datapath costs most of that margin.
It took two fixes to get there, not one: the receive checksum in
`tcp_rx_parser <../../../network/ethernet/tcp_rx_parser/README.rst>`_
folded every byte instead of once at the end (0.302 ns first
measured, a first attempt at that fix barely moved it to 0.361 ns
because it gave the pseudo-header its own separate reduction that
became the new worst path at 19 CARRY4, corrected to share one fold
with every byte), then `crc32
<../../../lib/crc32/README.rst>`_ rewritten as a one-level XOR
reduction once the CRC generator's bit-serial recurrence surfaced as
the next-worst path at 31 logic levels (0.213 ns mid-fix). After
both, neither checksum appears anywhere in the timing report; what
remains is a third, pre-existing path inside the shared
``axi_stream_packet_fifo``'s own valid logic, left alone on purpose —
that block has four other consumers beyond this one, its BRAM output
register is deliberately off to hold an exact one-cycle read latency
several of them depend on, and shortening it the obvious way would
mean re-verifying all of them, not just re-measuring one. 3555 LUT,
2592 flops, 1 RAMB36 — against the ICMP-only build's 997 LUT and 1172
flops, the cost of the whole TCP path: the connection machine, the
receive parser, the transmit builder, the socket's record, ring and
scheduler.

On the wire, 2026-09-14: ``arping`` 3/3 unicast replies, and
``ping -f -c 1000`` 1000/1000 at 0% loss, rtt 1.268/1.296/1.495 ms
with 22 µs mdev — in line with the ICMP-only build's own flood
numbers, so the TCP datapath's tighter fabric slack costs nothing on
the ICMP path it shares the endpoint with. ``nc 192.168.90.42 23``
echoed every line sent back byte for byte, the first live
confirmation of the TCP path end to end, on the same bitstream this
README's figures were measured from.
