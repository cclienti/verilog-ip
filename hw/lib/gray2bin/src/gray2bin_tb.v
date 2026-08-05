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
   // Test vectors
   //----------------------------------------------------------------
   reg [3:0] bin_ref [15:0];
   initial begin
      bin_ref[0]  = 4'b0000;
      bin_ref[1]  = 4'b0001;
      bin_ref[3]  = 4'b0010;
      bin_ref[2]  = 4'b0011;
      bin_ref[6]  = 4'b0100;
      bin_ref[7]  = 4'b0101;
      bin_ref[5]  = 4'b0110;
      bin_ref[4]  = 4'b0111;
      bin_ref[12] = 4'b1000;
      bin_ref[13] = 4'b1001;
      bin_ref[15] = 4'b1010;
      bin_ref[14] = 4'b1011;
      bin_ref[10] = 4'b1100;
      bin_ref[11] = 4'b1101;
      bin_ref[9]  = 4'b1110;
      bin_ref[8]  = 4'b1111;
   end

   integer idx;
   integer errors = 0;
   initial begin
      for (idx=0; idx<16; idx=idx+1) begin
         #1 gray = idx;
         #1 if (bin !== bin_ref[idx]) begin
            errors = errors + 1;
            $display("Error: out=4'b%04b - bin_ref=4'b%04b", bin, bin_ref[idx]);
         end
      end
      if (errors == 0)
        $display("gray2bin_tb: ALL TESTS PASSED");
      else
        $display("gray2bin_tb: %0d ERROR(S)", errors);
      #10 $finish;
   end


endmodule
