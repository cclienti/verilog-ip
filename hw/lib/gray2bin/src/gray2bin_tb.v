//                              -*- Mode: Verilog -*-
// Filename        : gray2bin_tb.v
// Description     : Testbench of Gray to Binary converter
// Author          : Christophe Clienti
// Created On      : Thu Jun 27 14:51:32 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Thu Jun 27 14:51:32 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps


module gray2bin_tb;

   //----------------------------------------------------------------
   //Constants
   //----------------------------------------------------------------
   localparam WIDTH = 4;


   //----------------------------------------------------------------
   //Signals
   //----------------------------------------------------------------
   //DUT Signals
   reg [WIDTH-1:0] gray;
   wire [WIDTH-1:0] bin;


   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------
   gray2bin
     #(.WIDTH(WIDTH))
   gray2bin_inst
     (.gray(gray),
      .bin(bin));


   //----------------------------------------------------------------
   // Value Change Dump
   //----------------------------------------------------------------
   initial  begin
      $dumpfile ("gray2bin_tb.vcd");
      $dumpvars;
   end


   //----------------------------------------------------------------
   // Test vectors
   //----------------------------------------------------------------
   initial begin
      gray = 4'b0000;
      #5 gray = 4'b0001;
      #5 gray = 4'b0011;
      #5 gray = 4'b0010;
      #5 gray = 4'b0110;
      #5 gray = 4'b0111;
      #5 gray = 4'b0101;
      #5 gray = 4'b0100;
      #5 gray = 4'b1100;
      #5 gray = 4'b1101;
      #5 gray = 4'b1111;
      #5 gray = 4'b1110;
      #5 gray = 4'b1010;
      #5 gray = 4'b1011;
      #5 gray = 4'b1001;
      #5 gray = 4'b1000;
      #10 $finish;
   end


endmodule
