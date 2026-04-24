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

module cmpgt_tb () ;
   parameter WIDTH = 16;

   reg [WIDTH-1:0]         a, b;
   wire signed [WIDTH-1:0] a_s, b_s;
   reg                     is_signed;
   wire                    out;
   reg                     out_ref;

   integer                 cpt;


   cmpgt #(.WIDTH(WIDTH))
   cmpgt(.out(out),
         .is_signed(is_signed),
         .a(a),
         .b(b));

   initial  begin
      $dumpfile ("cmpgt_tb.vcd");
      $dumpvars;
   end

   initial begin
      cpt = 0;
   end

   always begin
      #2 cpt <= cpt + 1;
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
            out_ref = 1;
         end
         2: begin
            a = -1;
            b = 1;
            is_signed = 1;
            out_ref = 0;
         end
         3: begin
            a = 2;
            b = -1;
            is_signed = 0;
            out_ref = 0;
         end
         4: begin
            a = 2;
            b = -1;
            is_signed = 1;
            out_ref = 1;
         end
         5: begin
            a = 2;
            b = 1;
            is_signed = 0;
            out_ref = 1;
         end
         6: begin
            a = 2;
            b = 1;
            is_signed = 1;
            out_ref = 1;
         end
         7: begin
            a = 1;
            b = 2;
            is_signed = 0;
            out_ref = 0;
         end
         8: begin
            a = 1;
            b = 2;
            is_signed = 1;
            out_ref = 0;
         end
         9: begin
            a = -2;
            b = -1;
            is_signed = 1;
            out_ref = 0;
         end
         10: begin
            a = -2;
            b = -1;
            is_signed = 0;
            out_ref = 0;
         end
         11: begin
            a = -1;
            b = -2;
            is_signed = 1;
            out_ref = 1;
         end
         12: begin
            a = -1;
            b = -2;
            is_signed = 0;
            out_ref = 1;
         end
         13: $finish;
      endcase
   end

   assign a_s = a;
   assign b_s = a;

   always @(*) begin
      #1;
      if (is_signed) begin
         $write("cpt(%0d) signed(%0d) a(%0d) > b(%0d) = out(%0d) # out_ref(%0d)",
                cpt, is_signed, a_s, b_s, out, out_ref);
      end
      else begin
         $write("cpt(%0d) signed(%0d) a(%0d) > b(%0d) = out(%0d) # out_ref(%0d)",
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
