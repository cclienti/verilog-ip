//                              -*- Mode: Verilog -*-
// Filename        : hynoc_prra.v
// Description     : LUT definition of the PRRA
// Author          : Christophe Clienti
// Created On      : Tue Jun 25 16:46:01 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Tue Jun 25 16:46:01 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

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
