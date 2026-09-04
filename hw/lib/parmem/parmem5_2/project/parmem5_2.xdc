# parmem5_2 out-of-context timing constraints for fmax analysis.
#
# Side A (dual strided load/store pair) and side B (NI) are independent
# clock domains; the dual-clock BRAM banks are the CDC boundary, so the
# domains are declared asynchronous. 5.000 ns targets the >200 MHz core
# goal.
#
# Zero-value input/output delays charge the full internal path against the
# period: the reported WNS directly measures how much of the cycle the
# lane EA adder + CRT decode + bank steering + BRAM access consumes, as
# if driven by zero-delay upstream/downstream registers.
# Achievable fmax = 1 / (period - WNS).

create_clock -name clka -period 5.000 [get_ports clka]
create_clock -name clkb -period 5.000 [get_ports clkb]

set_clock_groups -asynchronous -group clka -group clkb

# Side A ports (core clock domain)
set_input_delay  -clock clka 0.000 [get_ports {en wen lane_en[*] ben[*]}]
set_input_delay  -clock clka 0.000 [get_ports {addr[*] stride[*] dia[*]}]
set_output_delay -clock clka 0.000 [get_ports {doa[*]}]
set_output_delay -clock clka 0.000 [get_ports {conflict oob[*] freeze}]

# Side B ports (NI clock domain)
set_input_delay  -clock clkb 0.000 [get_ports {enb web addrb[*] dib[*] benb[*]}]
set_output_delay -clock clkb 0.000 [get_ports {dob[*] oobb}]

# OOC hold artifact: input ports have no clock tree, so zero-value input
# delays produce spurious hold violations on every port-launched path.
# Hold is re-timed for real when the block is integrated in context.
# The clock port(s) are excluded: a clock-source startpoint expands the
# waiver to every register-launched path, silencing real hold analysis.
# Not remove_from_collection: that is a Tcl command, not an XDC one,
# and Vivado drops the whole line with a critical warning (Designutils
# 20-1307) -- so the waiver had never applied and every hold figure
# these projects reported was the artifact itself.
set_false_path -hold -from [get_ports -filter {DIRECTION == IN && NAME != clka && NAME != clkb}]
