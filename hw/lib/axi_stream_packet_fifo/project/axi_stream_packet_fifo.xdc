# axi_stream_packet_fifo out-of-context timing constraints for fmax
# analysis. Single clock domain, 5.000 ns target.
#
# Zero-value input/output delays charge the full internal path against
# the period: the reported WNS directly measures the pointer compare +
# ready/store decode + RAM access consumption, as if driven by
# zero-delay upstream/downstream registers.
# Achievable fmax = 1 / (period - WNS).

create_clock -name clock -period 5.000 [get_ports clock]

set_input_delay  -clock clock 0.000 [get_ports {sreset m_axi_tready}]
set_input_delay  -clock clock 0.000 [get_ports {s_axi_tvalid s_axi_tlast s_axi_tuser}]
set_input_delay  -clock clock 0.000 [get_ports {s_axi_tdata[*] s_info*}]
set_output_delay -clock clock 0.000 [get_ports {s_axi_tready m_axi_tvalid m_axi_tlast}]
set_output_delay -clock clock 0.000 [get_ports {m_axi_tdata[*] m_info* m_length[*]}]

# OOC hold artifact: input ports have no clock tree, so zero-value input
# delays produce spurious hold violations on every port-launched path.
# Hold is re-timed for real when the block is integrated in context.
set_false_path -hold -from [all_inputs]
