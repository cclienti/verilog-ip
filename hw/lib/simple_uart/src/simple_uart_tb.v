//-----------------------------------------------------------------------------
// Title         : Simple Uart Testbench
//-----------------------------------------------------------------------------
// File          : simple_uart_tb.v
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

module simple_uart_tb;

   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------
   localparam SYSTEM_FREQ = 50_000_000;
   localparam BAUD_RATE   = 9600;

   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------
   reg        clock;
   reg        arst;
   reg        srst;

   reg        rx_bit;
   wire       tx_bit;

   wire [7:0] rx_value;
   wire       rx_value_ready;

   reg [7:0]  tx_value;
   reg        tx_value_write;

   //----------------------------------------------------------------
   // Value Change Dump
   //----------------------------------------------------------------
   initial  begin
      $dumpfile ("simple_uart_tb.vcd");
      $dumpvars;
   end

   //----------------------------------------------------------------
   // Clock and Reset Generation
   //----------------------------------------------------------------
   initial begin
      clock  = 0;
      arst   = 1;
      #200 arst = 0;
   end

   always begin
      #20 clock = !clock;
   end

   always @(posedge clock) begin
      srst <= arst;
   end

   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------
   simple_uart
     #(
       .SYSTEM_FREQ (SYSTEM_FREQ),
       .BAUD_RATE   (BAUD_RATE)
       )
   simple_uart_inst
     (
      .clock          (clock),
      .srst           (srst),
      .rx_bit         (rx_bit),
      .tx_bit         (tx_bit),
      .rx_value       (rx_value),
      .rx_value_ready (rx_value_ready),
      .tx_value       (tx_value),
      .tx_value_write (tx_value_write)
      );

   //----------------------------------------------------------------
   // Test vectors
   //----------------------------------------------------------------
   initial begin
      tx_value = 0;
      tx_value_write = 0;
      #1000 $finish;
   end

endmodule
