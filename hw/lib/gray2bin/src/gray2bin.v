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

module gray2bin
  #(parameter WIDTH = 4)

   (input wire [WIDTH-1:0]  gray,
    output wire [WIDTH-1:0] bin);

   localparam lut_length = 2**WIDTH;

   reg [WIDTH-1:0] lut_array [lut_length-1:0];

   reg [WIDTH-1:0] bin_temp;
   reg [WIDTH-1:0] gray_temp;

   integer i;

   initial begin
      for(i=0 ; i<lut_length ; i=i+1) begin
         bin_temp              = i[WIDTH-1:0];
         gray_temp             = (bin_temp >> 1) ^ bin_temp;
         lut_array[gray_temp]  = bin_temp;
      end
   end

   assign bin = lut_array[gray];

endmodule
