Zedboard Ethernet Endpoint Demonstrator
=======================================

Description
-----------

`rmii_eth_endpoint <../../../network/ethernet/rmii_eth_endpoint/README.rst>`_
on a Zedboard, live: the board answers ``arping`` and
``ping 192.168.1.42``. The Zedboard's own Ethernet PHY hangs off the
PS GEM and is not reachable from the PL, so the demonstrator uses a
LAN8720 RMII PHY module jumper-wired to Pmod JA. The wrapper adds only
what a board needs: a power-on/button reset stretcher (BTNC re-arms
it), the fixed identity constants, and four LEDs — LD0 heartbeat, LD1
receive activity, LD2 transmit activity, LD3 lit for ~84 ms whenever a
valid ARP packet taught the endpoint a mapping.

Hardware setup
--------------

- **VADJ must be set to 3V3** (jumper J18): Pmod JA is powered from
  VADJ and the LAN8720 module is a 3.3 V part.
- Wire the module to JA following the pin map in
  `project/zedboard_eth_endpoint.xdc <project/zedboard_eth_endpoint.xdc>`_:
  TX0/TX1/TX-EN on JA1/JA2/JA3, the 50 MHz clock on JA4, RX0/RX1 on
  JA7/JA8, CRS_DV on JA9, plus ground and 3V3. Keep the jumper wires
  short: this is a 50 MHz bus on flying leads.
- Everything is clocked by the PHY module's 50 MHz reference entering
  on JA4 (clock-capable). On the common blue LAN8720 breakout the
  oscillator drives the PHY directly and the clock is exposed on the
  nINT/REFCLKO pin only in REF_CLK Out mode: tie the nINTSEL strap low
  at power-up (on most modules a pull-down on that pin) or tap the
  oscillator output. A module that expects REF_CLK *in* instead needs
  the FPGA to generate 50 MHz, which this wrapper deliberately does
  not do — one clock, one source.
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

  arping 192.168.1.42
  ping 192.168.1.42

LD1 blinks on any wire traffic, LD3 on the first ARP exchange, LD2
whenever the board answers.

The testbench here is a smoke test of what the wrapper adds — the
init-value power-on reset, the button re-arm, the identity constants
and the LEDs — via a byte-exact ARP exchange on the pins before and
after a button press. The chain itself is verified in depth by the
endpoint's own bench.
