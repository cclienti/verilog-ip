Zedboard Ethernet Endpoint Demonstrator
=======================================

Description
-----------

`rmii_eth_endpoint <../../../network/ethernet/rmii_eth_endpoint/README.rst>`_
on a Zedboard, live: the board answers ``arping`` and
``ping 192.168.90.42``. The Zedboard's own Ethernet PHY hangs off the
PS GEM and is not reachable from the PL, so the demonstrator uses an
`ethernet-pmod v2 <https://github.com/swetland/ethernet-pmod>`_ — a
LAN8720A on a 12-pin Pmod — plugged straight into Pmod JA. The wrapper
adds only what a board needs: the 50 MHz reference and its forwarding,
the PHY reset pulse, a power-on/button reset (BTNC re-arms it), the
fixed identity constants, and four LEDs — LD0 heartbeat, LD1 receive
activity, LD2 transmit activity, LD3 lit for ~84 ms whenever a valid
ARP packet taught the endpoint a mapping.

Clocking, which is the whole point of the wrapper
-------------------------------------------------

The module carries no crystal and straps ``nINTSEL`` high, so it runs
in **REF_CLK In mode**: it expects the 50 MHz RMII reference on its
CLKIN pin and its ``nINT/REFCLKO`` pin is not even brought out. The
FPGA therefore owns the clock — the board's 100 MHz oscillator (Y9)
halved by one flip-flop onto a BUFG, then forwarded to JA7 through an
ODDR tied high/low. A divider rather than an MMCM: the ppm accuracy is
the oscillator's either way, and this is the design's only clock.

That forwarded copy is delayed from the fabric clock only by the ODDR
and its output buffer, so the clock insertion delay is common to it
and to every pin register and cancels. The consequence is the one
thing to remember here: **the PHY samples the transmit pins
essentially on the fabric edge that launched them**, right where its
4 ns setup / 2 ns hold window must not be. So the transmit pins are
registered on the *falling* edge, half a period away from that sample,
and the receive pins stay on the rising edge — a full period after the
edge that made the PHY launch them, which is where their eye is. Both
pin register sets are pushed into the IOBs.

This is the mirror image of the earlier wiring, where a blue LAN8720
breakout sourced the clock and the FPGA received it. There the fabric
clock *lagged* the wire by the insertion delay, a plain rising-edge
launch had margin on both sides, and a falling-edge retime overshot
into the next sample (measured, ``551adaf``). Nothing carries over:
the same retime that failed then is what is required now.

Measured, Vivado 2026.1 on the -1 part, all constraints met: transmit
setup 5.198 ns and hold 7.759 ns, receive setup **0.610 ns** and hold
3.392 ns, 4.042 ns of slack inside the 50 MHz domain. The receive
number is nearly the whole budget spent — the forwarded edge needs
4.439 ns to reach the pin (3.088 of it the OBUF at the slow corner),
the constraint then allows the PHY 14 ns, and the IBUF another 1.561.
``SLEW FAST`` on ``phy_clkin`` is already in: it took that OBUF arc
from 3.620 to 3.088 ns and the receive setup from 0.078 ns, which a
rerun could have placed either side of zero, to the figure above, at
the cost of 0.5 ns on the transmit side. That path has no routing and
no placement freedom, so no implementation strategy moves it. Two
levers remain before anyone reaches for a waiver: the LAN8720A's real
RMII clock-to-out in place of the datasheet-worst 14 ns, then a PLL
output advanced by about 2 ns for the ODDR alone, which is the only
way to center the 6.7 ns receive eye — the divider cannot move phase.

On the wire, 2026-09-04 with ``SLEW FAST`` in, every test at 0% loss:
``arping`` 8/8, ``ping -s 1400`` 9/9 through the ICMP payload buffer,
and ``ping -f -c 10000`` 10000/10000 at 1.264/1.301/2.619 ms with
27 µs mdev. The 2026-09-03 bitstream before the slew change measured
1.266/1.297/1.444 ms and 17 µs over 1000, and the previous PHY-sourced
wiring 1.29 ms and 16 µs, so none of this clocking costs anything.
Each reply needs a byte-perfect frame in both directions, the receive
FIFO dropping anything that fails FCS before the ARP and ICMP
responders ever see it, so the sampling geometry is right in practice
whatever the receive slack reads like on paper. The 1400-byte replies
spread from 1.7 to 4.2 ms while the 56-byte flood holds 27 µs of
jitter: the endpoint's store-and-forward latency is fixed per frame
size, so that spread is the host's USB NIC, as it was before.

Hardware setup
--------------

- **Plug the module into JA.** It is a standard 12-pin Pmod and header
  pin *n* is JA\ *n*, so there is nothing to wire and nothing to get
  wrong — the pin map in
  `project/zedboard_eth_endpoint.xdc <project/zedboard_eth_endpoint.xdc>`_
  is the module's own pinout: RXD1 on JA1, RXD0 on JA2, CRS_DV on JA3,
  TXD0 on JA4, CLKIN on JA7, RSTn on JA8, TXEN on JA9, TXD1 on JA10.
- **Pmod JA needs no jumper.** JA is in bank 13, whose VCCO is the
  board's fixed 3V3 rail, and the connector's power pins (6 and 12)
  are that same rail — schematic sheets 3 (Pmods) and 9 (FPGA banks).
  The module therefore gets 3.3 V I/O and 3.3 V supply whatever J18 is
  set to. LD0..LD3 are in bank 33, also fixed 3V3.
- **J18 can stay at its 1V8 default.** The one pin that depends on
  VADJ is BTNC (P16): every ZedBoard button and switch is in bank 34
  or 35, the two banks powered from VADJ, and J18 ships with pin 1-2
  unloaded. The button is driven from VADJ itself through a series
  resistor against a 10K pulldown, so its levels track the bank's own
  VCCO and nothing can exceed it — no overstress, and the input
  threshold of a 7-series LVCMOS receiver scales with VCCO, so the
  button reads correctly at 1V8 despite the LVCMOS33 in the XDC.
  Vivado does not flag the mismatch either: BTNC is the only pin this
  design uses in bank 34, so there is nothing for the intra-bank
  compatibility check to conflict with. Set J18 to 3V3 only to make
  that constraint literally true — the combination is uncharacterized
  otherwise, which is academic for an asynchronous, false-pathed
  button.
- **RSTn is driven, not strapped.** The module has no pull-up on that
  line: the PHY's reset comes from JA8 alone. The wrapper holds it low
  for 328 µs after configuration or a button press — the datasheet
  asks for 100 µs, with the reference clock already running, which it
  is — and releases the MAC 164 µs later.
- MDIO is not used: the straps on the module select auto-negotiation
  with all speeds advertised (MODE=111) and PHY address 1, which is
  enough for an RMII 100BASE-TX link. The module's separate MDIO
  header stays unconnected.

Build and run
-------------

::

  cd project
  make impl.vivado
  make program.vivado

``VIVADO_BITSTREAM=1`` in the Makefile makes ``impl.vivado`` also
write ``vivado-post-impl/zedboard_eth_endpoint.bit``, and
``program.vivado`` loads it over JTAG into the ``xc7z020_1`` device the
Makefile names. Plug the module into a switch or a PC, then::

  arping 192.168.90.42
  ping 192.168.90.42

LD1 blinks on any wire traffic, LD3 on the first ARP exchange, LD2
whenever the board answers.

The testbench here is a smoke test of what the wrapper adds — the
reset sequence, the identity constants and the LEDs — via a byte-exact
ARP exchange on the pins before and after a button press. It drives
only the 100 MHz oscillator and takes everything else from
``phy_clkin``, so it also stands in for the PHY's timing: receive
dibits are launched a clock-to-out after the forwarded edge, and the
transmit pins are checked against the 4 ns / 2 ns window at every
sample. What it cannot see is the receive side, whose margin lives in
the constraints alone. The chain itself is verified in depth by the
endpoint's own bench.
