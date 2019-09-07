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
   // Some usefull information
   //----------------------------------------------------------------
   integer j;

   initial begin
      $display("LUT:");
      for(j=0 ; j<2**WIDTH ; j=j+1) begin
         $display("\t %b -> %d", j[WIDTH-1:0], prra_lut.lut[j]);
      end
   end

   initial begin
      request = 0;
      for(j=0 ; j<2**WIDTH ; j=j+1) begin
         #4 request = j;
      end
      #10 $finish;
   end


endmodule
