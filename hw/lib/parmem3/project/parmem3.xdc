# parmem3 out-of-context timing constraints for fmax analysis.
#
# Side A (dual load/store) and side B (NI) are independent clock domains;
# the dual-clock BRAM banks are the CDC boundary, so the domains are
# declared asynchronous. 5.000 ns targets the >200 MHz core goal.
#
# Zero-value input/output delays charge the full internal path against the
# period: the reported WNS directly measures how much of the cycle the
# EA1 adder + CRT decode + bank steering + BRAM access consumes, as if
# driven by zero-delay upstream/downstream registers.
# Achievable fmax = 1 / (period - WNS).

create_clock -name clka -period 5.000 [get_ports clka]
create_clock -name clkb -period 5.000 [get_ports clkb]

set_clock_groups -asynchronous -group clka -group clkb

# Side A ports (core clock domain)
set_input_delay  -clock clka 0.000 [get_ports {en wen dual addr[*] stride[*]}]
set_input_delay  -clock clka 0.000 [get_ports {dia0[*] dia1[*]}]
set_output_delay -clock clka 0.000 [get_ports {doa0[*] doa1[*]}]
set_output_delay -clock clka 0.000 [get_ports {conflict oob0 oob1}]

# Side B ports (NI clock domain)
set_input_delay  -clock clkb 0.000 [get_ports {enb web addrb[*] dib[*]}]
set_output_delay -clock clkb 0.000 [get_ports {dob[*] oobb}]
