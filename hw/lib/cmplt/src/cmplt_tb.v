//                              -*- Mode: Verilog -*-
// Filename        : cmplt_tb.v
// Description     : Signed-unsigned dual-mode comparator testbench
// Author          : Christophe Clienti
// Created On      : Wed Feb 16 15:47:14 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Wed Feb 16 15:47:14 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module cmplt_tb () ;
   parameter WIDTH = 16;

   reg [WIDTH-1:0]         a, b;
   wire signed [WIDTH-1:0] a_s, b_s;
   reg                     is_signed;
   wire                    out;
   reg                     out_ref;

   integer                 cpt;


   cmplt #(.WIDTH(WIDTH))
   cmplt(.out(out),
         .is_signed(is_signed),
         .a(a),
         .b(b));


   initial  begin
      $dumpfile ("cmplt_tb.vcd");
      $dumpvars;
   end


   initial begin
      cpt = 0;
   end

   always begin
      #2 cpt = cpt + 1;
   end

   always @ (cpt) begin
      case (cpt)
         0: begin
            a = 0;
            b = 0;
            is_signed = 0;
            out_ref = 0;
         end
         1: begin
            a = -1;
            b = 1;
            is_signed = 0;
            out_ref = 0;
         end
         2: begin
            a = -1;
            b = 1;
            is_signed = 1;
            out_ref = 1;
         end
         3: begin
            a = 2;
            b = -1;
            is_signed = 0;
            out_ref = 1;
         end
         4: begin
            a = 2;
            b = -1;
            is_signed = 1;
            out_ref = 0;
         end
         5: begin
            a = 2;
            b = 1;
            is_signed = 0;
            out_ref = 0;
         end
         6: begin
            a = 2;
            b = 1;
            is_signed = 1;
            out_ref = 0;
         end
         7: begin
            a = 1;
            b = 2;
            is_signed = 0;
            out_ref = 1;
         end
         8: begin
            a = 1;
            b = 2;
            is_signed = 1;
            out_ref = 1;
         end
         9: begin
            a = -2;
            b = -1;
            is_signed = 1;
            out_ref = 1;
         end
         10: begin
            a = -2;
            b = -1;
            is_signed = 0;
            out_ref = 1;
         end
         11: begin
            a = -1;
            b = -2;
            is_signed = 1;
            out_ref = 0;
         end
         12: begin
            a = -1;
            b = -2;
            is_signed = 0;
            out_ref = 0;
         end
         13: $finish;
      endcase
   end

   assign a_s = a;
   assign b_s = a;

   always @(*) begin
      #1;
      if (is_signed) begin
         $write("cpt(%0d) signed(%0d) a(%0d) < b(%0d) = out(%0d) # out_ref(%0d)",
                cpt, is_signed, a_s, b_s, out, out_ref);
      end
      else begin
         $write("cpt(%0d) signed(%0d) a(%0d) < b(%0d) = out(%0d) # out_ref(%0d)",
                cpt, is_signed, a, b, out, out_ref);
      end
      if (out != out_ref) begin
         $display(" -> Error");
      end
      else begin
         $display(" -> Ok");
      end
   end

endmodule
