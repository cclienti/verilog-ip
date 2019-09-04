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
   reg [3:0] ref [15:0];
   initial begin
      ref[0]  = 4'b0000;
      ref[1]  = 4'b0001;
      ref[3]  = 4'b0010;
      ref[2]  = 4'b0011;
      ref[6]  = 4'b0100;
      ref[7]  = 4'b0101;
      ref[5]  = 4'b0110;
      ref[4]  = 4'b0111;
      ref[12] = 4'b1000;
      ref[13] = 4'b1001;
      ref[15] = 4'b1010;
      ref[14] = 4'b1011;
      ref[10] = 4'b1100;
      ref[11] = 4'b1101;
      ref[9]  = 4'b1110;
      ref[8]  = 4'b1111;
   end

   integer idx;
   initial begin
      for (idx=0; idx<16; idx=idx+1) begin
         #1 gray = idx;
         #1 if (bin != ref[idx]) begin
            $display("Error: out=4'b%04b - ref=4'b%04b", bin, ref[idx]);
         end
      end
      #10 $finish;
   end


endmodule
