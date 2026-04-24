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



`timescale 1 ns / 100ps


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
   reg [3:0] ref [15:0];
   initial begin
      ref[0] = 4'b0000;
      ref[1] = 4'b0001;
      ref[2] = 4'b0011;
      ref[3] = 4'b0010;
      ref[4] = 4'b0110;
      ref[5] = 4'b0111;
      ref[6] = 4'b0101;
      ref[7] = 4'b0100;
      ref[8] = 4'b1100;
      ref[9] = 4'b1101;
      ref[10] = 4'b1111;
      ref[11] = 4'b1110;
      ref[12] = 4'b1010;
      ref[13] = 4'b1011;
      ref[14] = 4'b1001;
      ref[15] = 4'b1000;
   end

   integer idx;
   initial begin
      for (idx = 0; idx<16; idx=idx+1) begin
         #1 bin = idx;
         #1 if (gray != ref[idx]) begin
            $display("Error: out=4'b%04b - ref=4'b%04b", gray, ref[idx]);
         end
      end
      #10 $finish;
   end

endmodule
