//                              -*- Mode: Verilog -*-
// Filename        : rdselb_tb.v
// Description     : Byte read select testbench
// Author          : Christophe Clienti
// Created On      : Sun Feb 17 09:39:17 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Sun Feb 17 09:39:17 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module rdselb_tb();
   reg         is_signed;
   reg [1:0]   sel;
   reg [31:0]  in;
   wire [31:0] out;

   integer     cpt;


   rdselb DUT(.out(out),
              .is_signed(is_signed),
              .sel(sel),
              .in(in));


   initial  begin
      $dumpfile ("rdselb_tb.vcd");
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

          4: begin
             sel = 2;
             is_signed = 0;
             in = 32'h788EFD0C;
          end

          5: begin
             sel = 2;
             is_signed = 1;
             in = 32'h788EFD0C;
          end

          6: begin
             sel = 3;
             is_signed = 0;
             in = 32'h788EFD0C;
          end

          7: begin
             sel = 3;
             is_signed = 1;
             in = 32'h788EFD0C;
          end

          8: $finish;

        endcase // case (cpt)
     end

endmodule // rdselb_tb
