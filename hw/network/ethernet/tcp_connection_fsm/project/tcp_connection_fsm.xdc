# tcp_connection_fsm out-of-context timing constraints for fmax analysis.
# Single clock domain, 5.000 ns target.
#
# Zero-value input/output delays charge the full internal path against
# the period, as if driven by zero-delay upstream/downstream registers.
# Achievable fmax = 1 / (period - WNS).

create_clock -name clock -period 5.000 [get_ports clock]

set_input_delay  -clock clock 0.000 [get_ports {sreset listen clear_done close_ready}]
set_input_delay  -clock clock 0.000 [get_ports {syn_rx ctl_acked fin_rx rst_rx give_up}]
set_output_delay -clock clock 0.000 [get_ports {clear listening syn_ack_pending connected}]
set_output_delay -clock clock 0.000 [get_ports {rx_open tx_open fin_pending}]

# OOC hold artifact: input ports have no clock tree, so zero-value input
# delays produce spurious hold violations on every port-launched path.
# Hold is re-timed for real when the block is integrated in context.
# The clock port is excluded: a clock-source startpoint expands the
# waiver to every register-launched path, silencing real hold analysis.
set_false_path -hold -from [get_ports -filter {DIRECTION == IN && NAME != clock}]
