//                              -*- Mode: Verilog -*-
// Filename        : asdpmem.v
// Description     : Asynchronous simple dual port RAM
// Author          : Christophe Clienti
// Created On      : Sun Feb 16 16:33:56 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Sun Feb 16 16:33:56 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module asdpmem
  #(parameter DEPTH = 6,
    parameter WIDTH = 32)

   (input wire              clka, ena, wea,
    input wire [DEPTH-1:0]  addra,
    input wire [WIDTH-1:0]  dia,

    input wire [DEPTH-1:0]  addrb,
    output wire [WIDTH-1:0] dob);

   reg [WIDTH-1:0]    ram[2**DEPTH-1:0];

   always @ (posedge clka) begin
      if((ena & wea) == 1'b1) begin
         ram[addra] <= dia;
      end
   end

   assign dob = ram[addrb];


endmodule // asdpmem
