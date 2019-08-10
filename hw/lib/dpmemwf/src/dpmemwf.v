//                              -*- Mode: Verilog -*-
// Filename        : dpmemwf.v
// Description     : Write-first dual port RAM
// Author          : Christophe Clienti
// Created On      : Sun Feb 16 17:38:13 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Sun Feb 16 17:38:13 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

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
