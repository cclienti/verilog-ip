# Zedboard pin and timing constraints for the eth_endpoint demonstrator.
#
# The LAN8720 RMII PHY module is jumper-wired to Pmod JA (bank 13,
# powered from VADJ: set the VADJ jumper to 3V3, the LAN8720 module is
# 3.3 V I/O). The module's 50 MHz reference clock enters on JA4, a
# clock-capable pin. On the common blue LAN8720 breakout the clock is
# available on the nINT/REFCLKO pin once the nINTSEL strap selects
# REF_CLK Out mode -- see the README.

# 50 MHz RMII reference from the PHY module
create_clock -name phy_refclk -period 20.000 [get_ports phy_refclk]

# Pmod JA
set_property PACKAGE_PIN Y11  [get_ports {phy_txd[0]}];   # JA1
set_property PACKAGE_PIN AA11 [get_ports {phy_txd[1]}];   # JA2
set_property PACKAGE_PIN Y10  [get_ports {phy_txen}];     # JA3
set_property PACKAGE_PIN AA9  [get_ports {phy_refclk}];   # JA4, clock-capable
set_property PACKAGE_PIN AB11 [get_ports {phy_rxd[0]}];   # JA7
set_property PACKAGE_PIN AB10 [get_ports {phy_rxd[1]}];   # JA8
set_property PACKAGE_PIN AB9  [get_ports {phy_crs_dv}];   # JA9

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
# to keep the analysis honest, not tight.
set_input_delay  -clock phy_refclk -max 14.000 [get_ports {phy_rxd[*] phy_crs_dv}]
set_input_delay  -clock phy_refclk -min  2.000 [get_ports {phy_rxd[*] phy_crs_dv}]
set_output_delay -clock phy_refclk -max  4.000 [get_ports {phy_txd[*] phy_txen}]
set_output_delay -clock phy_refclk -min -2.000 [get_ports {phy_txd[*] phy_txen}]

# Asynchronous by design: the button feeds a synchronizing shift
# register and the LEDs are for eyes only
set_false_path -from [get_ports btn_reset]
set_false_path -to   [get_ports {led[*]}]
