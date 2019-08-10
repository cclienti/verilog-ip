//                              -*- Mode: Verilog -*-
// Filename        : asdpmem_tb.v
// Description     : asdpmem testbench
// Author          : Christophe Clienti
// Created On      : Sun Feb 16 16:34:21 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Sun Feb 16 16:34:21 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module asdpmem_tb();

   parameter DEPTH = 6;
   parameter WIDTH = 32;

   reg              clka, ena, wea;
   reg [DEPTH-1:0]  addra;
   reg [WIDTH-1:0]  dia;

   reg [DEPTH-1:0]  addrb;
   wire [WIDTH-1:0] dob;

   integer          cpt = 0;


   asdpmem #(.DEPTH(DEPTH), .WIDTH(WIDTH))
   DUT(.clka(clka), .ena(ena), .wea(wea),
       .addra(addra), .dia(dia),
       .addrb(addrb), .dob(dob));

   //----------------------------------------------------------------
   // VCD
   //----------------------------------------------------------------
   initial begin
      $dumpfile("asdpmem_tb.vcd");
      $dumpvars(0,asdpmem_tb);
   end

   //----------------------------------------------------------------
   // Clock generation
   //----------------------------------------------------------------
   initial begin
      clka = 1'b1;
      # 10000 $finish;
   end

   always begin
     #5 clka = ~clka;
   end

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
           wea = 0;
           dia = 0;
           addra = 0;
           addrb = 1;
        end

        2: begin
           wea = 1;
           dia = 32'h11223344;
           addra = 1;
        end

        3: begin
           wea = 1;
           dia = 32'h55667788;
           addra = 2;
        end

        4: begin
           wea = 0;
           dia = 0;
           addra = 0;
           addrb = 2;
        end

      endcase // case (cpt)
   end

endmodule
