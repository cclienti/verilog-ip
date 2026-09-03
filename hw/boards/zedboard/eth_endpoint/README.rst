Zedboard Ethernet Endpoint Demonstrator
=======================================

Description
-----------

`rmii_eth_endpoint <../../../network/ethernet/rmii_eth_endpoint/README.rst>`_
on a Zedboard, live: the board answers ``arping`` and
``ping 192.168.90.42``. The Zedboard's own Ethernet PHY hangs off the
PS GEM and is not reachable from the PL, so the demonstrator uses a
LAN8720 RMII PHY module jumper-wired to Pmod JA. The wrapper adds only
what a board needs: a power-on/button reset stretcher (BTNC re-arms
it), the fixed identity constants, and four LEDs — LD0 heartbeat, LD1
receive activity, LD2 transmit activity, LD3 lit for ~84 ms whenever a
valid ARP packet taught the endpoint a mapping. The transmit pins are
plain rising-edge registers: the LAN8720 samples TXD/TX_EN on the
rising edge with a 4 ns setup / 2 ns hold window, and the measured
clock insertion delay (~3–5.6 ns across corners) plus the OBUF lands
the transitions comfortably inside it. A falling-edge ODDR retime was
tried against an early hold number and reverted: that number came from
a bufferless netlist, and the real insertion delay pushed the ODDR's
half-period shift into the next sampling edge (setup −3.8 ns,
measured).

Hardware setup
--------------

- **Pmod JA needs no jumper.** JA is in bank 13, whose VCCO is the
  board's fixed 3V3 rail, and the connector's power pins (6 and 12)
  are that same rail — schematic sheets 3 (Pmods) and 9 (FPGA banks).
  The LAN8720 module therefore gets 3.3 V I/O and 3.3 V supply
  whatever J18 is set to. LD0..LD3 are in bank 33, also fixed 3V3.
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
- Wire the module to JA following the pin map in
  `project/zedboard_eth_endpoint.xdc <project/zedboard_eth_endpoint.xdc>`_:
  TX0 on JA2, RX1 on JA3, **nINT/REFCLKO on JA4**, TX1 on JA7, TX_EN
  on JA8, RX0 on JA9, **CRS_DV on JA10**, JA1 left unconnected, plus
  ground and 3V3. The clock must be on JA4: it is the P side of the
  connector's clock-capable pair, and the N side (JA10) cannot drive a
  clock buffer for a single-ended input. Keep the jumper wires short:
  this is a 50 MHz bus on flying leads.
- Everything is clocked by the PHY module's 50 MHz reference entering
  on JA4 (clock-capable) from the nINT/REFCLKO pin. On the common
  blue LAN8720 breakout that pin carries the clock in REF_CLK Out
  mode (nINTSEL strap low at power-up); a module that expects REF_CLK
  *in* instead needs the FPGA to generate 50 MHz, which this wrapper
  deliberately does not do — one clock, one source.
- MDIO is not used: the LAN8720 straps default to auto-negotiation
  with all speeds advertised, which is enough for an RMII 100BASE-TX
  link. The two MDIO pads on the module stay unconnected.

Build and run
-------------

::

  cd project
  make impl.vivado

``VIVADO_BITSTREAM=1`` in the Makefile makes ``impl.vivado`` also
write ``vivado-post-impl/zedboard_eth_endpoint.bit``. Program it (JTAG
via ``vivado`` hardware manager, or ``xsdb``), plug the module into a
switch or a PC, then::

  arping 192.168.90.42
  ping 192.168.90.42

LD1 blinks on any wire traffic, LD3 on the first ARP exchange, LD2
whenever the board answers.

The testbench here is a smoke test of what the wrapper adds — the
init-value power-on reset, the button re-arm, the identity constants
and the LEDs — via a byte-exact ARP exchange on the pins before and
after a button press. The chain itself is verified in depth by the
endpoint's own bench.
