# tcp_rx_parser out-of-context timing constraints for fmax analysis.
# Single clock domain, 5.000 ns target.
#
# Zero-value input/output delays charge the full internal path against
# the period, as if driven by zero-delay upstream/downstream registers.
# Achievable fmax = 1 / (period - WNS).

create_clock -name clock -period 5.000 [get_ports clock]

set_input_delay  -clock clock 0.000 [get_ports {sreset s_axi_tdata[*] s_axi_tuser s_axi_tvalid s_axi_tlast}]
set_input_delay  -clock clock 0.000 [get_ports {s_src_ip[*] s_dst_ip[*] s_length[*] m_pl_tready}]
set_output_delay -clock clock 0.000 [get_ports {s_axi_tready m_pl_tdata[*] m_pl_tvalid m_pl_tlast m_pl_tuser}]
set_output_delay -clock clock 0.000 [get_ports {src_port[*] dst_port[*] seq_num[*] ack_num[*] flags[*]}]
set_output_delay -clock clock 0.000 [get_ports {window[*] urgent[*] mss[*] payload_len[*] hdr_valid seg_done seg_ok}]

# OOC hold artifact: input ports have no clock tree, so zero-value input
# delays produce spurious hold violations on every port-launched path.
# Hold is re-timed for real when the block is integrated in context.
# The clock port is excluded: a clock-source startpoint expands the
# waiver to every register-launched path, silencing real hold analysis.
set_false_path -hold -from [get_ports -filter {DIRECTION == IN && NAME != clock}]
