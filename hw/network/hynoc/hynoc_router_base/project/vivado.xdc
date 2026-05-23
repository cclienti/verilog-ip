# Timing Constraints - 200 MHz (5.000 ns period)

# Main router clock
create_clock -period 5.000 -name router_clk [get_ports router_clk]

# All ingress clocks are the same physical clock as router_clk
create_clock -period 5.000 -name port_ingress_clk_0 [get_ports port_ingress_clk[0]]
create_clock -period 5.000 -name port_ingress_clk_1 [get_ports port_ingress_clk[1]]
create_clock -period 5.000 -name port_ingress_clk_2 [get_ports port_ingress_clk[2]]
create_clock -period 5.000 -name port_ingress_clk_3 [get_ports port_ingress_clk[3]]
create_clock -period 5.000 -name port_ingress_clk_4 [get_ports port_ingress_clk[4]]

# All clocks are synchronous - no clock groups exclusion
# Inter-clock paths will be fully analyzed by the timing engine


# create_pblock pb_hynoc
# add_cells_to_pblock [get_pblocks pb_hynoc] [get_cells -hierarchical *]
# resize_pblock       [get_pblocks pb_hynoc] -add {SLICE_X0Y0:SLICE_X30Y30}
