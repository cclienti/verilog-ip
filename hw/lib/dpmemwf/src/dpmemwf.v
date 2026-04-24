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

module dpmemwf
  #(parameter DEPTH   = 10,
    parameter WIDTH   = 32,
    parameter OUTREGA = 1,
    parameter OUTREGB = 1)

   (input wire             clka, ena, wea,
    input wire [DEPTH-1:0] addra,
    input wire [WIDTH-1:0] dia,
    output reg [WIDTH-1:0] doa,

    input wire             clkb, enb, web,
    input wire [DEPTH-1:0] addrb,
    input wire [WIDTH-1:0] dib,
    output reg [WIDTH-1:0] dob);


   reg [WIDTH-1:0] ram[2**DEPTH-1:0];
   reg [WIDTH-1:0] doa_reg, dob_reg;


   always @ (posedge clka) begin
      if(ena == 1'b1) begin
         if(wea == 1'b1) begin
            doa_reg <= dia;
            ram[addra] <= dia;
         end else
           doa_reg <= ram[addra];
      end
   end

   generate
      if(OUTREGA != 0) begin
         always @ (posedge clka) begin
            if(ena == 1'b1) begin
               doa <= doa_reg;
            end
         end
      end else begin
         always @ (doa_reg) begin
            doa = doa_reg;
         end
      end
   endgenerate


   always @ (posedge clkb) begin
      if(enb == 1'b1) begin
         if(web == 1'b1) begin
            dob_reg <= dib;
            ram[addrb] <= dib;
         end else
           dob_reg <= ram[addrb];
      end
   end

   generate
      if(OUTREGB != 0) begin
         always @ (posedge clkb) begin
            if(enb == 1'b1) begin
               dob <= dob_reg;
            end
         end
      end else begin
         always @ (dob_reg) begin
            dob = dob_reg;
         end
      end
   endgenerate

endmodule // dpmemwf
