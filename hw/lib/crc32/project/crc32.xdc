# crc32 is purely combinational, so a clock constraint is meaningless
# here: the input-to-output depth is bounded instead. 5.000 ns matches
# the out-of-context clock target of the modules that instantiate it.
set_max_delay 5.000 -from [all_inputs] -to [all_outputs]
