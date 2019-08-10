//                              -*- Mode: Verilog -*-
// Filename        : rdselh_tb.v
// Description     : Half word read select testbench
// Author          : Christophe Clienti
// Created On      : Sun Feb 17 09:39:17 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Sun Feb 17 09:39:17 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module rdselh_tb();
   reg         is_signed;
   reg         sel;
   reg [31:0]  in;
   wire [31:0] out;

   integer     cpt;


   rdselh DUT(.out(out),
              .is_signed(is_signed),
              .sel(sel),
              .in(in));


   initial  begin
      $dumpfile ("rdselh_tb.vcd");
      $dumpvars;
   end


   initial begin
      cpt = 0;
      #1000 $finish;
   end


   always
     #2 cpt = cpt + 1;


   always @ (cpt)
     begin
        case (cpt)
          0: begin
             sel = 0;
             is_signed = 0;
             in = 32'h788EFD0C;
          end

          1: begin
             sel = 0;
             is_signed = 1;
             in = 32'h788EFD0C;
          end

          2: begin
             sel = 1;
             is_signed = 0;
             in = 32'h788EFD0C;
          end

          3: begin
             sel = 1;
             is_signed = 1;
             in = 32'h788EFD0C;
          end


          4: $finish;

        endcase // case (cpt)
     end

endmodule // rdselh_tb
