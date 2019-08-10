//                              -*- Mode: Verilog -*-
// Filename        : bin2gray.v
// Description     : Binary to Gray converter
// Author          : Christophe Clienti
// Created On      : Thu Jun 27 14:36:11 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Thu Jun 27 14:36:11 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module bin2gray
  #(parameter WIDTH = 4)

   (input wire [WIDTH-1:0] bin,
    output reg [WIDTH-1:0] gray);


   always @(*) begin
      gray = (bin >> 1) ^ bin;
   end

endmodule
