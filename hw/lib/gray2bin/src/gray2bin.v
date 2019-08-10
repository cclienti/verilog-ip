//                              -*- Mode: Verilog -*-
// Filename        : gray2bin.v
// Description     : Gray to Binary converter
// Author          : Christophe Clienti
// Created On      : Thu Jun 27 14:45:55 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Thu Jun 27 14:45:55 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

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
