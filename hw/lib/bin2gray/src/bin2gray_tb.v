//                              -*- Mode: Verilog -*-
// Filename        : bin2gray_tb.v
// Description     : Testbench of bin to gray converter
// Author          : Christophe Clienti
// Created On      : Thu Jun 27 14:40:02 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Thu Jun 27 14:40:02 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps


module bin2gray_tb;

   //----------------------------------------------------------------
   //Constants
   //----------------------------------------------------------------
   localparam WIDTH = 4;

   //----------------------------------------------------------------
   //Signals
   //----------------------------------------------------------------
   //DUT Signals
   reg [WIDTH-1:0] bin;
   wire [WIDTH-1:0] gray;

   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------
   bin2gray
     #(.WIDTH(WIDTH))
   bin2gray_inst
     (.bin(bin),
      .gray(gray));

   //----------------------------------------------------------------
   // Value Change Dump
   //----------------------------------------------------------------
   initial  begin
      $dumpfile ("bin2gray_tb.vcd");
      $dumpvars;
   end

   //----------------------------------------------------------------
   // Test vectors
   //----------------------------------------------------------------
   initial begin
      bin = 4'h0;
      #5 bin = 4'h1;
      #5 bin = 4'h2;
      #5 bin = 4'h3;
      #5 bin = 4'h4;
      #5 bin = 4'h5;
      #5 bin = 4'h6;
      #5 bin = 4'h7;
      #5 bin = 4'h8;
      #5 bin = 4'h9;
      #5 bin = 4'ha;
      #5 bin = 4'hb;
      #5 bin = 4'hc;
      #5 bin = 4'hd;
      #5 bin = 4'he;
      #5 bin = 4'hf;
      #10 $finish;
   end


endmodule
