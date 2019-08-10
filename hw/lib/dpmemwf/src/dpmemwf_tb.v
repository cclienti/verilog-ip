//                              -*- Mode: Verilog -*-
// Filename        : dpmemwf_tb.v
// Description     : Write-first dual port RAM testbench
// Author          : Christophe Clienti
// Created On      : Sun Feb 16 17:38:43 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Sun Feb 16 17:38:43 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module dpmemwf_tb();

   parameter DEPTH = 10;
   parameter WIDTH = 32;
   parameter OUTREGA = 1;
   parameter OUTREGB = 0;

   reg              clka, ena, wea;
   reg [DEPTH-1:0]  addra;
   reg [WIDTH-1:0]  dia;
   wire [WIDTH-1:0] doa;

   reg              clkb, enb, web;
   reg [DEPTH-1:0]  addrb;
   reg [WIDTH-1:0]  dib;
   wire [WIDTH-1:0] dob;

   integer          cpt = 0;


   dpmemwf #(.DEPTH(DEPTH), .WIDTH(WIDTH),
             .OUTREGA(OUTREGA), .OUTREGB(OUTREGB))
   DUT(.clka(clka), .ena(ena), .wea(wea),
       .addra(addra), .dia(dia), .doa(doa),
       .clkb(clkb), .enb(enb), .web(web),
       .addrb(addrb), .dib(dib), .dob(dob));

   //----------------------------------------------------------------
   // VCD
   //----------------------------------------------------------------
   initial begin
      $dumpfile("dpmemwf_tb.vcd");
      $dumpvars(0,dpmemwf_tb);
   end

   //----------------------------------------------------------------
   // Clock generation
   //----------------------------------------------------------------
   initial begin
      clka = 1'b1;
      clkb = 1'b1;
      # 10000 $finish;
   end

   always fork
     #5 clka = ~clka;
     #5 clkb = ~clkb;
   join

   //----------------------------------------------------------------
   // Test Vectors
   //----------------------------------------------------------------
   always @ (posedge clka) begin
      cpt <= cpt + 1;
   end

   always @ (cpt) begin
      case (cpt)
        0: begin
           ena = 1;
           enb = 1;
           wea = 0;
           web = 0;
           dia = 0;
           dib = 0;
           addra = 0;
           addrb = 0;
        end

        1: begin
           wea = 1;
           dia = 32'h11223344;
           addra = 1;
        end

        2: begin
           wea = 1;
           dia = 32'h55667788;
           addra = 2;
        end

        3: begin
           wea = 0;
           dia = 0;
           addra = 2;
           web = 1;
           dib = 32'hCAFEDECA;
           addrb = 2;
        end

        4: begin
           wea = 0;
           dia = 0;
           addra = 2;
           web = 0;
           dib = 0;
           addrb = 2;
        end

      endcase // case (cpt)
   end

endmodule
