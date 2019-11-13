//-----------------------------------------------------------------------------
// Title: UART Register Interface Testbench
//-----------------------------------------------------------------------------
// Description: Test the uart_reg_if module.
//
//-----------------------------------------------------------------------------
// Copyright (c) 2019 by Christophe Clienti. This model is the
// confidential and proprietary property of Christophe Clienti and the
// possession or use of this file requires a written license from
// Christophe Clienti.
//-----------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module uart_reg_if_tb;

   //----------------------------------------------------------------
   // Contants
   //----------------------------------------------------------------

   localparam NUM_BYTES_PER_REG = 4;
   localparam NUM_REGISTERS     = 8;


   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------
   reg                                                  clock;
   reg                                                  srst;
   reg  [7:0]                                           uart_rx_value;
   reg                                                  uart_rx_value_ready;
   wire [7:0]                                           uart_tx_value;
   wire                                                 uart_tx_value_write;
   reg                                                  uart_tx_value_done;
   reg [NUM_REGISTERS-1:0][NUM_BYTES_PER_REG-1:0][7:0]  value_in;
   wire [NUM_REGISTERS-1:0][NUM_BYTES_PER_REG-1:0][7:0] value_out;


   //----------------------------------------------------------------
   // Value Change Dump
   //----------------------------------------------------------------

   initial  begin
      $dumpfile ("uart_reg_if_tb.vcd");
      $dumpvars;
   end


   //----------------------------------------------------------------
   // Clock and Reset Generation
   //----------------------------------------------------------------

   reg arst;

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
   // Init
   //----------------------------------------------------------------

   integer byte_index, reg_index;
   reg [NUM_BYTES_PER_REG-1:0] [7:0] temp_value;

   initial begin
      uart_rx_value = 0;
      uart_rx_value_ready = 0;
      uart_tx_value_done = 0;
   end

   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------

   uart_reg_if #(.NUM_BYTES_PER_REG (NUM_BYTES_PER_REG),
                 .NUM_REGISTERS     (NUM_REGISTERS))
   uart_reg_if_inst (.clock               (clock),
                     .srst                (srst),
                     .uart_rx_value       (uart_rx_value),
                     .uart_rx_value_ready (uart_rx_value_ready),
                     .uart_tx_value       (uart_tx_value),
                     .uart_tx_value_write (uart_tx_value_write),
                     .uart_tx_value_done  (uart_tx_value_done),
                     .value_in            (value_in),
                     .value_out           (value_out));


   //----------------------------------------------------------------
   // Helpers
   //----------------------------------------------------------------

   localparam NUM_CYCLES_PER_BAUD = 2;

   task send(input reg [7:0] byte_value);
     begin
        repeat(NUM_CYCLES_PER_BAUD) @(posedge clock);
        uart_rx_value <= byte_value;
        uart_rx_value_ready <= 1'b1;
        @(posedge clock);
        uart_rx_value_ready <= 1'b0;
     end
   endtask

   task receive(output reg [7:0] byte_value);
      begin
         while (uart_tx_value_write == 1'b0) begin
            @(posedge clock);
         end
         byte_value <= uart_tx_value;
         repeat(NUM_CYCLES_PER_BAUD) @(posedge clock);
         uart_tx_value_done <= 1'b1;
         @(posedge clock);
         uart_tx_value_done <= 1'b0;
     end
   endtask

   task write_reg(input reg [7:0] index, input reg [NUM_BYTES_PER_REG-1:0][7:0] value);
      integer i;
      begin
         send("S");
         send(index);
         send("W");
         for (i=0; i<NUM_BYTES_PER_REG; i=i+1) begin
            send(value[i]);
         end
      end
   endtask

   task read_reg(input reg [7:0] index, output reg [NUM_BYTES_PER_REG-1:0][7:0] value);
      integer i;
      begin
         send("S");
         send(index);
         send("R");
         for (i=0; i<NUM_BYTES_PER_REG; i=i+1) begin
           receive(value[i]);
         end
      end
   endtask


   //----------------------------------------------------------------
   // Connect input from register outputs to enable read-back
   //----------------------------------------------------------------

   always @(*) begin
      value_in = value_out;
   end


   //----------------------------------------------------------------
   // Test vectors
   //----------------------------------------------------------------

   integer cpt;
   reg [NUM_BYTES_PER_REG-1:0][7:0] send_value;
   reg [NUM_BYTES_PER_REG-1:0][7:0] read_value;

   initial begin
      repeat(20) @(posedge clock);

      send_value = 32'hCAFEDECA;

      for(cpt=0; cpt<NUM_REGISTERS; cpt=cpt+1) begin
         write_reg(cpt, send_value);
         read_reg(cpt, read_value);

         if (send_value == read_value) begin
            $display("sent value: 0x%04h, read value: 0x%04h --> Ok", send_value, read_value);
         end
         else begin
            $display("sent value: 0x%04h, read value: 0x%04h --> Error", send_value, read_value);
         end

         send_value = send_value + 32'h01010101;
      end
   end

   always @(*) begin
      if (cpt == NUM_REGISTERS) begin
         #100 $finish();
      end
   end

endmodule
