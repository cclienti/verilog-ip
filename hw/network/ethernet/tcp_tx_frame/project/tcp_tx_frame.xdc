# tcp_tx_frame out-of-context timing constraints for fmax analysis.
# Single clock domain, 5.000 ns target.
#
# Zero-value input/output delays charge the full internal path against
# the period, as if driven by zero-delay upstream/downstream registers.
# Achievable fmax = 1 / (period - WNS).

create_clock -name clock -period 5.000 [get_ports clock]

set_input_delay  -clock clock 0.000 [get_ports {sreset start with_mss pl_len[*]}]
set_input_delay  -clock clock 0.000 [get_ports {dst_mac[*] src_mac[*] ip_id[*] src_ip[*] dst_ip[*]}]
set_input_delay  -clock clock 0.000 [get_ports {src_port[*] dst_port[*] seq[*] ack[*] flags[*] window[*] mss[*]}]
set_input_delay  -clock clock 0.000 [get_ports {pl_data[*] m_axi_tready}]
set_output_delay -clock clock 0.000 [get_ports {pl_addr[*] busy}]
set_output_delay -clock clock 0.000 [get_ports {m_axi_tdata[*] m_axi_tuser m_axi_tvalid m_axi_tlast}]

# OOC hold artifact: input ports have no clock tree, so zero-value input
# delays produce spurious hold violations on every port-launched path.
# Hold is re-timed for real when the block is integrated in context.
# The clock port is excluded: a clock-source startpoint expands the
# waiver to every register-launched path, silencing real hold analysis.
set_false_path -hold -from [get_ports -filter {DIRECTION == IN && NAME != clock}]
