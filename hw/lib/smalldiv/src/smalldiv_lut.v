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

module smalldiv_lut
  #(parameter DIGIT_WIDTH   = 3,
    parameter DIVIDER_VALUE = 5,
    parameter DIVIDER_WIDTH = $clog2(DIVIDER_VALUE))

   (input wire [DIGIT_WIDTH-1:0] dividend_digit,
    input wire [DIVIDER_WIDTH-1:0]        last_remainder,
    output reg [DIGIT_WIDTH-1:0] quotient,
    output reg [DIVIDER_WIDTH-1:0]        remainder);

   localparam REMAINDER_WIDTH = DIVIDER_WIDTH;
   localparam LUT_WIDTH       = DIGIT_WIDTH + REMAINDER_WIDTH;

   //----------------------------------------------------------------
   // Check Parameters
   //----------------------------------------------------------------

   initial begin
      if (DIVIDER_WIDTH > DIGIT_WIDTH) begin
         $display("DIVIDER_WIDTH (%0d) must be less or equal to DIGIT_WIDTH (%0d)",
                  DIVIDER_WIDTH, DIGIT_WIDTH);
         $finish;
      end
   end


   //----------------------------------------------------------------
   // Fill Quotient Lookup Table and Remainder Lookup Table
   //----------------------------------------------------------------

   reg [DIGIT_WIDTH-1:0] qlut [2**LUT_WIDTH-1:0];
   reg [DIVIDER_WIDTH-1:0] rlut [2**LUT_WIDTH-1:0];

   integer i, q, m;

   initial begin
      for (i=0; i<2**LUT_WIDTH; i=i+1) begin
         q = i / DIVIDER_VALUE;
         qlut[i] = q[DIGIT_WIDTH-1:0];

         m = i % DIVIDER_VALUE;
         rlut[i] = m[DIVIDER_WIDTH-1:0];
      end
   end


   //----------------------------------------------------------------
   // Output results
   //----------------------------------------------------------------

   always @(*) begin
      quotient = qlut[{last_remainder, dividend_digit}];
   end

   always @(*) begin
      remainder = rlut[{last_remainder, dividend_digit}];
   end

endmodule
