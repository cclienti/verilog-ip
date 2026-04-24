Simple UART
===========

Description
-----------

The ``simple_uart`` module implements a basic UART (Universal Asynchronous Receiver/Transmitter)
with both RX and TX. It supports 8 data bits, no parity, and 1 stop bit (8N1). The system clock
frequency and baud rate are parameterizable, and the module provides ready/valid handshake signals
for RX and TX data.

Parameters
----------

============  ==============  ===========================================
Name          Default value   Description
============  ==============  ===========================================
SYSTEM_FREQ   50_000_000      System clock frequency in Hz
BAUD_RATE     9600            UART baud rate
============  ==============  ===========================================

Signals
-------

================  ============  ========  ================================
Name              I/O type      Range     Description
================  ============  ========  ================================
clock             input wire    1         System clock
srst              input wire    1         Synchronous reset, active high
rx_bit            input wire    1         UART RX serial input
tx_bit            output wire   1         UART TX serial output
rx_value          output wire   [7:0]     Received byte
rx_value_ready    output wire   1         RX data valid strobe
tx_value          input wire    [7:0]     Byte to transmit
tx_value_write    input wire    1         TX write strobe
tx_value_done     output wire   1         TX done flag
================  ============  ========  ================================

Example Instantiation
---------------------

.. code-block:: verilog

   simple_uart #(
     .SYSTEM_FREQ(50_000_000),
     .BAUD_RATE(9600)
   ) u_simple_uart (
     .clock(clock),
     .srst(srst),
     .rx_bit(rx_bit),
     .tx_bit(tx_bit),
     .rx_value(rx_value),
     .rx_value_ready(rx_value_ready),
     .tx_value(tx_value),
     .tx_value_write(tx_value_write),
     .tx_value_done(tx_value_done)
   );

Simulation
----------

.. code-block:: bash

   cd project
   make sim    # Icarus Verilog simulation
   make trace  # Simulate and open GTKWave
   make lint   # Lint with Verilator

License
-------

This module is licensed under the **CERN Open Hardware Licence Version 2 - Permissive (CERN-OHL-P-2.0)**.
See `LICENSE <../../LICENSE>`_ for details.
