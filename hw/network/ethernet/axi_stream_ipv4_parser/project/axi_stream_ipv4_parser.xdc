# axi_stream_ipv4_parser out-of-context timing constraints for fmax analysis.
# Single clock domain, 5.000 ns target.
#
# Zero-value input/output delays charge the full internal path against
# the period, as if driven by zero-delay upstream/downstream registers.
# Achievable fmax = 1 / (period - WNS).

create_clock -name clock -period 5.000 [get_ports clock]

set_input_delay  -clock clock 0.000 [get_ports {sreset s_axi_tvalid* s_axi_tlast* s_axi_tuser*}]
set_input_delay  -clock clock 0.000 [get_ports {local_ip[*] s_axi_tdata[*]}]
set_input_delay  -clock clock 0.000 [get_ports {m_axi_tready*}]
set_output_delay -clock clock 0.000 [get_ports {s_axi_tready* m_axi_tvalid* m_axi_tlast* m_axi_tuser*}]
set_output_delay -clock clock 0.000 [get_ports {m_axi_tdata[*] m_sel[*] m_src_ip[*] m_dst_ip[*] m_protocol[*] m_length[*]}]

# OOC hold artifact: input ports have no clock tree, so zero-value input
# delays produce spurious hold violations on every port-launched path.
# Hold is re-timed for real when the block is integrated in context.
# The clock port is excluded: a clock-source startpoint expands the
# waiver to every register-launched path, silencing real hold analysis.
set_false_path -hold -from [remove_from_collection [all_inputs] [get_ports clock]]
