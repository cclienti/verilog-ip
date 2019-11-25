# Constraints
set_global_assignment -name SDC_FILE ../../../boards/de0_nano/de0_nano.sdc

# Top
set_global_assignment -name SYSTEMVERILOG_FILE ../src/de0_nano.v

# Simple UART
set_global_assignment -name VERILOG_FILE ../../../lib/simple_uart/src/simple_uart.v
set_global_assignment -name VERILOG_FILE ../../../lib/simple_uart/src/simple_uart_rx.v
set_global_assignment -name VERILOG_FILE ../../../lib/simple_uart/src/simple_uart_tx.v

# Register Interface
set_global_assignment -name SYSTEMVERILOG_FILE ../../uart_reg_if/src/uart_reg_if.v
