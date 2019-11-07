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
   simple_uart #(.SYSTEM_FREQ (SYSTEM_FREQ),
                 .BAUD_RATE   (BAUD_RATE))
   simple_uart_inst (.clock          (clock),
                     .srst           (srst),
                     .rx_bit         (rx_bit),
                     .tx_bit         (tx_bit),
                     .rx_value       (rx_value),
                     .rx_value_ready (rx_value_ready),
                     .tx_value       (tx_value),
                     .tx_value_write (tx_value_write));

   //----------------------------------------------------------------
   // Helpers
   //----------------------------------------------------------------

   // Wait for the amount of cycles specified.
   task automatic wait_cycles(input reg [31:0] cycles);
      begin
         while (cycles > 0) begin
            @(posedge clock) cycles = cycles - 1;
         end
      end
   endtask

   // Wait for a baud.
   reg send_baud_clock = 1;
   task send_baud_delay;
      begin
         wait_cycles(SYSTEM_FREQ/BAUD_RATE/2);
         send_baud_clock <= 0;
         wait_cycles(SYSTEM_FREQ/BAUD_RATE/2);
         send_baud_clock <= 1;
      end
   endtask

   // Send the stream on the RX pin of the simple_uart module.
   // send_state:
   //   -1: Idle
   //    0: Start
   //  1-8: Send bits (lsb first)
   //    9: Stop
   reg [7:0] send_state = -1;
   task send (input reg [7:0] value);
      integer i;
      begin
         // Start bit
         send_state <= 0;
         rx_bit <= 0;
         send_baud_delay();

         // Send the value (lsb first)
         for (i=0; i<8; i=i+1) begin
            send_state <= i + 1;
            rx_bit <= value[i];
            send_baud_delay();
         end

         // One Stop bit
         send_state <= i + 1;
         rx_bit <= 1;
         send_baud_delay();
         send_state <= -1;
         send_baud_delay();
      end
   endtask

   // Wait for a baud.
   task receive_half_baud_delay;
      begin
         wait_cycles(SYSTEM_FREQ/BAUD_RATE/2);
      end
   endtask

   // Set the receive_sampling bit during one clock cycle.
   reg receive_sampling = 0;
   task received_sampled;
      begin
         receive_sampling <= 0;
         @(posedge clock);
         receive_sampling <= 1;
         @(posedge clock);
      end
   endtask

   // Reveive the stream on the RX pin of the simple_uart module.
   // reveive_state:
   //   -1: Idle
   //    0: Sample Start
   //  1-8: Sample Reveive bits (lsb first)
   //    9: Sample Stop
   reg [7:0] receive_state = -1;
   task receive (output reg [7:0] value);
      integer i;
      begin
         // Detect start bit
         receive_state <= -1;
         while (tx_bit != 0) begin
            // synchronize at the middle of the baud rate to improve
            // the sampling.
            receive_half_baud_delay();
         end
         receive_state <= 0;

         // Sample
         for (i=0; i<8; i=i+1) begin
            receive_half_baud_delay();
            receive_state <= i + 1;
            receive_half_baud_delay();
            value[i] <= tx_bit;
            received_sampled();
        end

         // Detect start bit
         receive_half_baud_delay();
         receive_state <= 9;
         receive_half_baud_delay();
         if (tx_bit != 1) begin
            $display("error: bad stop bit at %0t", $time);
         end
      end
   endtask

   //----------------------------------------------------------------
   // Test vectors
   //----------------------------------------------------------------

   reg [7:0] tx_bit_regs;
   initial begin
      tx_bit_regs = 0;
      tx_value = 0;
      tx_value_write = 0;
   end

   // Send process
   initial begin
      rx_bit = 1; // line is idle
      wait_cycles(100);

      send(8'h55);
      send(8'hAA);
      send(8'hCC);

      $finish;
   end

   // Receive process
   reg [7:0] received_value;
   initial begin
      wait_cycles(10);

      while(1) begin
         receive(received_value);
         $display("info: received value 0x%02h", received_value);

         receive(received_value);
         $display("info: received value 0x%02h", received_value);
      end
   end

endmodule
