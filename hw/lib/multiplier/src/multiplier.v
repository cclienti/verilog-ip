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

module multiplier
  #(parameter WIDTH_A          = 32,
    parameter WIDTH_B          = 32,
    parameter NB_EXTRA_REG     = 4)

   (input wire                        clk,
    input wire                        enable,
    input wire                        is_signed,
    input wire [WIDTH_A-1:0]          a,
    input wire [WIDTH_B-1:0]          b,
    output wire [WIDTH_A+WIDTH_B-1:0] out);

   //----------------------------------------------------------------
   // internal signals
   //----------------------------------------------------------------
   integer                      i;

   reg [WIDTH_A+WIDTH_B-1:0]    mult_reg[NB_EXTRA_REG-1:0];

   reg signed [WIDTH_A:0]       a_ext;
   reg signed [WIDTH_B:0]       b_ext;

   wire signed [WIDTH_A+WIDTH_B+1:0] mult;

   //----------------------------------------------------------------
   // Arch description
   //----------------------------------------------------------------

   // Sign extension of inputs
   always @(posedge clk) begin
      if(enable == 1'b1) begin
         a_ext <= {{is_signed & a[WIDTH_A-1]}, a};
         b_ext <= {{is_signed & b[WIDTH_B-1]}, b};
      end
   end


   // Signed multiplier
   assign mult = a_ext * b_ext;

   // multiplier output registers
   always @(posedge clk) begin
      if(enable == 1'b1) begin
         mult_reg[0] <= mult[WIDTH_A+WIDTH_B-1:0];
         for(i=0 ; i < NB_EXTRA_REG-1 ; i=i+1)
           mult_reg[i+1] <= mult_reg[i];
      end
   end

   // Output
   assign out = mult_reg[NB_EXTRA_REG-1];

endmodule
