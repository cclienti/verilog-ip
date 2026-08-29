# rmii_eth_endpoint out-of-context timing constraints for fmax analysis.
# Single clock domain, 20.000 ns target: the RMII reference clock is
# 50 MHz, so this block only ever needs to close at that period.
#
# Zero-value input/output delays charge the full internal path against
# the period, as if driven by zero-delay upstream/downstream registers.

create_clock -name clock -period 20.000 [get_ports clock]

set_input_delay  -clock clock 0.000 [get_ports {sreset phy_rxd[*] phy_crs_dv}]
set_input_delay  -clock clock 0.000 [get_ports {local_mac[*] local_ip[*]}]
set_output_delay -clock clock 0.000 [get_ports {phy_txd[*] phy_txen}]
set_output_delay -clock clock 0.000 [get_ports {learn_valid learn_mac[*] learn_ip[*]}]

# OOC hold artifact: input ports have no clock tree, so zero-value input
# delays produce spurious hold violations on every port-launched path.
# Hold is re-timed for real when the block is integrated in context.
# The clock port is excluded: a clock-source startpoint expands the
# waiver to every register-launched path, silencing real hold analysis.
set_false_path -hold -from [remove_from_collection [all_inputs] [get_ports clock]]
