UART Register Interface
=======================

The ``uart_reg_if`` module implements a UART-based register interface that allows reading and
writing an array of internal registers over a serial UART link. It is designed to be used with the
``simple_uart`` module and is suitable for motor control systems and other FPGA-based applications
requiring remote register access.

Protocol
--------

The protocol is command-based and operates over a UART serial link. Each transaction starts with a
``S`` (Set register index) command:

1. Send ``S`` (0x53): Set register command.
2. Send register index (1 byte).
3. Send ``R`` (0x52) to read or ``W`` (0x57) to write.

   - **Read:** The module responds by sending ``NUM_BYTES_PER_REG`` bytes of the selected register.
   - **Write:** Send ``NUM_BYTES_PER_REG`` bytes to write into the selected register.

Parameters
----------

===================  ==============  =====================================================
Name                 Default value   Description
===================  ==============  =====================================================
NUM_BYTES_PER_REG    4               Number of bytes per register (must be a power of 2)
NUM_REGISTERS        8               Number of registers in the register array
===================  ==============  =====================================================

Signals
-------

=======================  ===========  =============================================  =====================================================
Name                     I/O type     Range                                          Description
=======================  ===========  =============================================  =====================================================
clock                    input wire   1                                              System clock
srst                     input wire   1                                              Synchronous reset, active high
uart_rx_value            input wire   [7:0]                                          Received byte from UART RX
uart_rx_value_ready      input wire   1                                              Received byte valid strobe
uart_tx_value            output reg   [7:0]                                          Byte to send via UART TX
uart_tx_value_write      output reg   1                                              Write strobe for UART TX
uart_tx_value_done       input wire   1                                              UART TX done flag
value_in                 input wire   [NUM_REGISTERS-1:0][NUM_BYTES_PER_REG-1:0]    Register readback inputs (connect to value_out)
value_out                output wire  [NUM_REGISTERS-1:0][NUM_BYTES_PER_REG-1:0]    Register outputs
=======================  ===========  =============================================  =====================================================

**Note:** Connect ``value_in[j]`` to ``value_out[j]`` for each register to allow readback of
written values.

Example Instantiation
---------------------

.. code-block:: verilog

   uart_reg_if #(
     .NUM_BYTES_PER_REG(4),
     .NUM_REGISTERS(8)
   ) u_uart_reg_if (
     .clock(clock),
     .srst(srst),
     .uart_rx_value(uart_rx_value),
     .uart_rx_value_ready(uart_rx_value_ready),
     .uart_tx_value(uart_tx_value),
     .uart_tx_value_write(uart_tx_value_write),
     .uart_tx_value_done(uart_tx_value_done),
     .value_in(value_out),   // connect readback
     .value_out(value_out)
   );

Simulation
----------

.. code-block:: bash

   cd project
   make sim    # Icarus Verilog simulation
   make trace  # Simulate and open GTKWave
