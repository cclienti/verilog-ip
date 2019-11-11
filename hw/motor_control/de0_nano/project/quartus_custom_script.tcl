set_global_assignment -name SDC_FILE ../../../boards/de0_nano/de0_nano.sdc
set_global_assignment -name VERILOG_FILE ../src/de0_nano.v

set_global_assignment -name VERILOG_FILE ../../../lib/simple_uart/src/simple_uart.v
set_global_assignment -name VERILOG_FILE ../../../lib/simple_uart/src/simple_uart_rx.v
set_global_assignment -name VERILOG_FILE ../../../lib/simple_uart/src/simple_uart_tx.v
