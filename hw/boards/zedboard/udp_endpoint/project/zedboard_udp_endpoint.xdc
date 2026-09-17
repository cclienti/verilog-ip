# Zedboard pin and timing constraints for the udp_endpoint demonstrator.
# Board, PHY, clocking and pin registers are identical to the ICMP-only
# and TCP demonstrators'; see their own .xdc for the fuller explanation
# of each choice. This file differs from the TCP one only in its
# module name and in the measured-figures note below.
#
# An ethernet-pmod v2 (LAN8720A) plugs straight into Pmod JA: header
# pin n is JAn, so the map below is the module's own pinout, no jumper
# wires. JA is in bank 13 and the LEDs are in bank 33; both banks take
# their VCCO from the board's fixed 3V3 rail, as do the connector's
# power pins, so the 3.3 V module needs no jumper. BTNC (P16) is the
# exception: it is in bank 34, one of the two banks powered from VADJ,
# which ships at 1V8. The LVCMOS33 below is then uncharacterized but
# harmless -- the button is driven from VADJ itself, so its levels
# track that bank's VCCO.
#
# The module carries no crystal and straps nINTSEL high, so it runs in
# REF_CLK In mode: the 50 MHz reference is generated here from the
# board's 100 MHz oscillator and forwarded out on JA7. TXD/TXEN are
# named from the PHY's side -- they are the module's transmit inputs,
# driven by the FPGA.

# The board's 100 MHz oscillator, the only clock entering the design
create_clock -name clk100 -period 10.000 [get_ports clk100]
set_property PACKAGE_PIN Y9 [get_ports clk100]

# The 50 MHz RMII reference: clk100 halved in the fabric onto a global
# buffer, then forwarded to the module through an ODDR tied high/low.
# Both cells are named in the RTL and referenced here; rename either
# and the whole interface analysis disappears with the constraint --
# the only trace is a "[Vivado 12-584] No pins matched" in the log.
create_generated_clock -name refclk -source [get_ports clk100] -divide_by 2 \
    [get_pins refclk_bufg/O]
create_generated_clock -name phy_clkin -source [get_pins phy_clkin_oddr/C] \
    -divide_by 1 [get_ports phy_clkin]

# Pmod JA, the module's pinout one to one
set_property PACKAGE_PIN Y11  [get_ports {phy_rxd[1]}];   # JA1  - RXD1
set_property PACKAGE_PIN AA11 [get_ports {phy_rxd[0]}];   # JA2  - RXD0
set_property PACKAGE_PIN Y10  [get_ports {phy_crs_dv}];   # JA3  - CRS_DV
set_property PACKAGE_PIN AA9  [get_ports {phy_txd[0]}];   # JA4  - TXD0
set_property PACKAGE_PIN AB11 [get_ports {phy_clkin}];    # JA7  - CLKIN
set_property PACKAGE_PIN AB10 [get_ports {phy_rstn}];     # JA8  - RSTn
set_property PACKAGE_PIN AB9  [get_ports {phy_txen}];     # JA9  - TXEN
set_property PACKAGE_PIN AA8  [get_ports {phy_txd[1]}];   # JA10 - TXD1

# BTNC and LD0..LD3
set_property PACKAGE_PIN P16 [get_ports {btn_reset}]
set_property PACKAGE_PIN T22 [get_ports {led[0]}]
set_property PACKAGE_PIN T21 [get_ports {led[1]}]
set_property PACKAGE_PIN U22 [get_ports {led[2]}]
set_property PACKAGE_PIN U21 [get_ports {led[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports *]

# The forwarded clock leaves through a fast-slew OBUF, as on the ICMP
# and TCP builds; see their .xdc for the measured margin this buys.
set_property SLEW FAST [get_ports phy_clkin]

# RMII timing against the reference this design forwards. The PHY needs
# 4 ns setup / 2 ns hold on txd/txen and answers with a large
# clock-to-out (worst case from the LAN8720A datasheet). Both pin
# register sets sit in the IOBs, so the datapath's timing lives in the
# fabric-domain (refclk to refclk) numbers this project measures on its
# own, not in the transmit/receive pin numbers below, which are
# IOB-to-pin paths this build shares with the ICMP-only and TCP ones.
set_input_delay  -clock phy_clkin -max 14.000 [get_ports {phy_rxd[*] phy_crs_dv}]
set_input_delay  -clock phy_clkin -min  2.000 [get_ports {phy_rxd[*] phy_crs_dv}]
set_output_delay -clock phy_clkin -max  4.000 [get_ports {phy_txd[*] phy_txen}]
set_output_delay -clock phy_clkin -min -2.000 [get_ports {phy_txd[*] phy_txen}]

# Asynchronous by design: the button feeds a synchronizing shift
# register, the PHY reset is a static level the module samples with its
# own logic, and the LEDs are for eyes only
set_false_path -from [get_ports btn_reset]
set_false_path -to   [get_ports {led[*] phy_rstn}]
