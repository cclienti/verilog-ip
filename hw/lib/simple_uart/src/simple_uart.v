//-----------------------------------------------------------------------------
// Title         : Simple Uart
//-----------------------------------------------------------------------------
// File          : simple_uart.v
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 06.11.2019
// Last modified : 06.11.2019
//-----------------------------------------------------------------------------
// Description :
// Implements a basic RX/TX UART / 8-bit / No Parity / 1 Stop Bit
//-----------------------------------------------------------------------------
// Copyright (c) 2019 by Christophe Clienti. This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module simple_uart
  #(parameter SYSTEM_FREQ = 50_000_000,
    parameter BAUD_RATE   = 9600)

   (input wire        clock,
    input wire        srst,

    input wire        rx_bit,
    output wire       tx_bit,

    output wire [7:0] rx_value,
    output wire       rx_value_ready,

    input wire [7:0]  tx_value,
    input wire        tx_value_write,
    output wire       tx_value_done);


   simple_uart_rx
     #(.SYSTEM_FREQ (SYSTEM_FREQ),
       .BAUD_RATE   (BAUD_RATE))
   simple_uart_rx_inst
     (.clock          (clock),
      .srst           (srst),
      .rx_bit         (rx_bit),
      .rx_value       (rx_value),
      .rx_value_ready (rx_value_ready));


   simple_uart_tx
   #(.SYSTEM_FREQ (SYSTEM_FREQ),
     .BAUD_RATE   (BAUD_RATE))
   simple_uart_tx_inst
     (.clock          (clock),
      .srst           (srst),
      .tx_bit         (tx_bit),
      .tx_value       (tx_value),
      .tx_value_write (tx_value_write),
      .tx_value_done  (tx_value_done));


endmodule
