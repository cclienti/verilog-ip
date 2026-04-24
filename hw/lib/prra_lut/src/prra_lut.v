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

module prra_lut
  #(parameter WIDTH        = 4,
    parameter LOG2_WIDTH   = $clog2(WIDTH),
    parameter STATE_OFFSET = 0)

   (input wire [WIDTH-1:0]      request,
    output reg [LOG2_WIDTH-1:0] state);


   localparam lut_length = 2**WIDTH;


   integer j; // iterate in a lut
   integer k; // interate over bits of a specific lut index
   integer l; // rotate k;
   integer value;

   reg [WIDTH-1:0] lut_index;
   reg [LOG2_WIDTH-1:0] lut [lut_length-1:0];

   initial begin
      lut[0] = STATE_OFFSET[LOG2_WIDTH-1:0];

      for(j=1 ; j<lut_length ; j=j+1) begin

         lut_index = j[WIDTH-1:0];
         value = -1;

         //Looking for the first one bit
         //we starts at ((STATE_OFFSET+1) % WIDTH)
         for(k=0 ; k<WIDTH ; k=k+1) begin
            l = (k+STATE_OFFSET+1) % WIDTH;
            if(lut_index[l] == 1'b1) begin
               if(value == -1) value = l;
            end
         end

         lut[j] = value[LOG2_WIDTH-1:0];

      end
   end

   always @(*) begin
      state = lut[request];
   end

endmodule
