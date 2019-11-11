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
   localparam SYSTEM_FREQ       = 50_000_000;
   localparam BAUD_RATE         = 100_000;
   localparam BAUD_COUNTER_MAX  = SYSTEM_FREQ / BAUD_RATE;
   localparam BAUD_COUNTER_HALF = BAUD_COUNTER_MAX / 2;

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
   wire       tx_value_done;

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

   simple_uart #(.SYSTEM_FREQ (SYSTEM_FREQ),
                 .BAUD_RATE   (BAUD_RATE))
   simple_uart_inst (.clock          (clock),
                     .srst           (srst),
                     .rx_bit         (rx_bit),
                     .tx_bit         (tx_bit),
                     .rx_value       (rx_value),
                     .rx_value_ready (rx_value_ready),
                     .tx_value       (tx_value),
                     .tx_value_write (tx_value_write),
                     .tx_value_done  (tx_value_done));


   //----------------------------------------------------------------
   // Helpers
   //----------------------------------------------------------------

   // Send the stream on the RX pin of the simple_uart module.
   task send (input reg [7:0] value);
      integer i;
      integer cnt;
      begin
         // Start bit
         rx_bit <= 0;
         for (cnt=0; cnt<BAUD_COUNTER_MAX; cnt=cnt+1) @(posedge clock);

         // Send the value (lsb first)
         for (i=0; i<8; i=i+1) begin
            rx_bit <= value[i];
            for (cnt=0; cnt<BAUD_COUNTER_MAX; cnt=cnt+1) @(posedge clock);
         end

         // One Stop bit
         rx_bit <= 1;
         for (cnt=0; cnt<BAUD_COUNTER_MAX; cnt=cnt+1) @(posedge clock);
      end
   endtask

   // Reveive the stream on the RX pin of the simple_uart module.
   task receive (output reg [7:0] value);
      integer i;
      integer cnt;
      begin
         // Detect start bit
         while (tx_bit == 1'b1) begin
            @(posedge clock);
         end

         // synchronize at the middle of the baud rate to improve
         // the sampling.
         for (cnt=0; cnt<BAUD_COUNTER_HALF-1; cnt=cnt+1) @(posedge clock);

         // Sample
         for (i=0; i<8; i=i+1) begin
            for (cnt=0; cnt<BAUD_COUNTER_MAX-1; cnt=cnt+1) @(posedge clock);
            value[i] <= tx_bit;
         end

         // Detect stop bit
         for (cnt=0; cnt<BAUD_COUNTER_MAX-1; cnt=cnt+1) @(posedge clock);
         if (tx_bit == 1'b0) begin
            $display("error: bad stop bit at %0t", $time);
         end

      end
   endtask


   //----------------------------------------------------------------
   // Loop back
   //----------------------------------------------------------------

   always @(*) begin
      tx_value_write <= rx_value_ready;
      tx_value <= rx_value;
   end


   //----------------------------------------------------------------
   // Test vectors
   //----------------------------------------------------------------

   integer pattern;

   // Send process
   initial begin
      pattern = 0;
      rx_bit = 1; // line is idle

      #100000 @(posedge clock);
      send(8'h55);
      #100000 @(posedge clock);
      send(8'hAA);
      #100000 @(posedge clock);
      send(8'hCC);

      for(pattern = 0; pattern < 200; pattern = pattern + 1) begin
         send(pattern[7:0]);
      end

      #100000 $finish;
   end

   // Receive process
   reg [7:0] received_value;
   initial begin
      #1000 @(posedge clock);

      while(1) begin
         receive(received_value);
         $display("info: received value 0x%02h", received_value);
      end
   end

endmodule
