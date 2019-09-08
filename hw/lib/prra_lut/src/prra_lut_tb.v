//                              -*- Mode: Verilog -*-
// Filename        : hynoc_prra.v
// Description     : Testbench of PRRA LUT definition
// Author          : Christophe Clienti
// Created On      : Tue Jun 25 16:46:01 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Tue Jun 25 16:46:01 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module prra_lut_tb();

   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------
   localparam WIDTH        = 4;
   localparam LOG2_WIDTH   = 2;
   localparam STATE_OFFSET = 1;


   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------
   reg [WIDTH-1:0] request;
   wire [LOG2_WIDTH-1:0] state;

   //----------------------------------------------------------------
   // Value Change Dump
   //----------------------------------------------------------------
   initial begin
      $dumpfile ("prra_lut_tb.vcd");
      $dumpvars;
   end

   //----------------------------------------------------------------
   // Clock generation
   //----------------------------------------------------------------
   reg clk;

   initial begin
      clk = 1'b1;
   end

   always begin
     #5 clk = ~clk;
   end

   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------
   prra_lut
   #(
      .WIDTH        (WIDTH),
      .LOG2_WIDTH   (LOG2_WIDTH),
      .STATE_OFFSET (STATE_OFFSET)
   )
   prra_lut
   (
      .request (request),
      .state   (state)
   );

   //----------------------------------------------------------------
   // Test vectors
   //----------------------------------------------------------------
   integer cpt;

   initial begin
      request = 0;
      cpt = 0;
   end

   always @(posedge clk) begin
      cpt <= cpt + 1;
      request <= request + 1;
      if (cpt == 16) begin
         $finish;
      end
   end

   //----------------------------------------------------------------
   // Checker
   //----------------------------------------------------------------
   reg [LOG2_WIDTH-1:0] state_ref_array [2**WIDTH-1:0];
   initial begin
      state_ref_array[0] = 1;
      state_ref_array[1] = 0;
      state_ref_array[2] = 1;
      state_ref_array[3] = 0;
      state_ref_array[4] = 2;
      state_ref_array[5] = 2;
      state_ref_array[6] = 2;
      state_ref_array[7] = 2;
      state_ref_array[8] = 3;
      state_ref_array[9] = 3;
      state_ref_array[10] = 3;
      state_ref_array[11] = 3;
      state_ref_array[12] = 2;
      state_ref_array[13] = 2;
      state_ref_array[14] = 2;
      state_ref_array[15] = 2;
   end

   wire [LOG2_WIDTH-1:0] state_ref;
   assign state_ref = state_ref_array[request];

   always @(posedge clk) begin
      $write("request(%04b) state(%04b) ref(%04b)", request, state, state_ref);
      if (state != state_ref) begin
         $display(" -> Error");
      end
      else begin
         $display(" -> Ok");
      end
   end

endmodule
