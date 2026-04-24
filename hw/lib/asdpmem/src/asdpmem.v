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
