# Zedboard pin and timing constraints for the eth_endpoint demonstrator.
#
# The LAN8720 RMII PHY module is jumper-wired to Pmod JA. JA is in
# bank 13 and the LEDs are in bank 33; both banks take their VCCO from
# the board's fixed 3V3 rail, as do the Pmod connector's own power
# pins, so the 3.3 V module needs no jumper. BTNC (P16) is the
# exception: it is in bank 34, one of the two banks powered from VADJ,
# which ships at 1V8. The LVCMOS33 below is then uncharacterized but
# harmless -- the button is driven from VADJ itself, so its levels
# track that bank's VCCO. The module's 50 MHz reference clock enters on
# the nINT/REFCLKO pin wired to JA4, a clock-capable pin -- see the
# README. TX0/TX1/TX_EN are named from the PHY's side: they are the
# module's transmit inputs, driven by the FPGA.

# 50 MHz RMII reference from the PHY module
create_clock -name phy_refclk -period 20.000 [get_ports phy_refclk]

# Pmod JA; JA1 is not connected. The reference clock must sit on JA4:
# AA9 is the P side of the connector's clock-capable pair and AA8
# (JA10) is the N side, which cannot drive a clock buffer for a
# single-ended input (DRC PLIO-9) -- CRS_DV, a plain data input, takes
# JA10 instead.
set_property PACKAGE_PIN AA11 [get_ports {phy_txd[0]}];   # JA2  - TX0
set_property PACKAGE_PIN Y10  [get_ports {phy_rxd[1]}];   # JA3  - RX1
set_property PACKAGE_PIN AA9  [get_ports {phy_refclk}];   # JA4  - nINT/REFCLKO, CC P-side
set_property PACKAGE_PIN AB11 [get_ports {phy_txd[1]}];   # JA7  - TX1
set_property PACKAGE_PIN AB10 [get_ports {phy_txen}];     # JA8  - TX_EN
set_property PACKAGE_PIN AB9  [get_ports {phy_rxd[0]}];   # JA9  - RX0
set_property PACKAGE_PIN AA8  [get_ports {phy_crs_dv}];   # JA10 - CRS_DV

# BTNC and LD0..LD3
set_property PACKAGE_PIN P16 [get_ports {btn_reset}]
set_property PACKAGE_PIN T22 [get_ports {led[0]}]
set_property PACKAGE_PIN T21 [get_ports {led[1]}]
set_property PACKAGE_PIN U22 [get_ports {led[2]}]
set_property PACKAGE_PIN U21 [get_ports {led[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports *]

# RMII timing against the PHY's REF_CLK: the PHY drives rxd/crs_dv
# with a large clock-to-out (worst case from the LAN8720 datasheet)
# and needs 4 ns setup / 2 ns hold on txd/txen. The receive side is
# resynchronized inside the MAC, so the input constraint is only there
# to keep the analysis honest, not tight. The transmit pins are plain
# rising-edge registers: the clock insertion delay plus the OBUF
# provides the hold margin and leaves ample setup -- both corners
# measured met. (A falling-edge ODDR retime was tried and reverted:
# its half-period shift plus the same insertion delay overshot into
# the next sampling edge.)
set_input_delay  -clock phy_refclk -max 14.000 [get_ports {phy_rxd[*] phy_crs_dv}]
set_input_delay  -clock phy_refclk -min  2.000 [get_ports {phy_rxd[*] phy_crs_dv}]
set_output_delay -clock phy_refclk -max  4.000 [get_ports {phy_txd[*] phy_txen}]
set_output_delay -clock phy_refclk -min -2.000 [get_ports {phy_txd[*] phy_txen}]

# Asynchronous by design: the button feeds a synchronizing shift
# register and the LEDs are for eyes only
set_false_path -from [get_ports btn_reset]
set_false_path -to   [get_ports {led[*]}]
