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
