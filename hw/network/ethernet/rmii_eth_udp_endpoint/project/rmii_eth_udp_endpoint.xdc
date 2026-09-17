# rmii_eth_udp_endpoint out-of-context timing constraints for fmax
# analysis. Single clock domain, 10.000 ns target. The board runs this
# block at 50 MHz, the RMII reference, and closes there; the 100 MHz
# target is the theoretical-fmax question -- how far the chain's
# combinational ready/valid paths are from a serious clock -- asked of
# the netlist, not of the board. Achievable fmax = 1 / (period - WNS),
# a negative WNS included.
#
# Zero-value input/output delays charge the full internal path against
# the period, as if driven by zero-delay upstream/downstream registers.

create_clock -name clock -period 10.000 [get_ports clock]

set_input_delay  -clock clock 0.000 [get_ports -filter {DIRECTION == IN  && NAME != clock}]
set_output_delay -clock clock 0.000 [get_ports -filter {DIRECTION == OUT}]

# OOC hold artifact: input ports have no clock tree, so zero-value input
# delays produce spurious hold violations on every port-launched path.
# Hold is re-timed for real when the block is integrated in context.
# The clock port is excluded: a clock-source startpoint expands the
# waiver to every register-launched path, silencing real hold analysis.
set_false_path -hold -from [get_ports -filter {DIRECTION == IN && NAME != clock}]
