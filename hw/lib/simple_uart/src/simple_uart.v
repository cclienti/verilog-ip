// SPDX-License-Identifier: CERN-OHL-P-2.0
// Copyright (c) 2013-2026 Christophe Clienti
//
// This source describes Open Hardware and is licensed under the CERN-OHL-P v2.
// You may redistribute and modify this file under the terms of the CERN-OHL-P v2
// (https://ohwr.org/cern_ohl_p_v2.txt).
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING
// OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A PARTICULAR PURPOSE.
// Please see the CERN-OHL-P v2 for applicable conditions.



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
