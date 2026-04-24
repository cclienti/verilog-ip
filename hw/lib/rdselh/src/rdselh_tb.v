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

module rdselh_tb();
   //----------------------------------------------
   // DUT
   //----------------------------------------------
   reg         is_signed;
   reg         sel;
   reg [31:0]  in;
   wire [31:0] out;

   rdselh rdselh(.out(out),
                 .is_signed(is_signed),
                 .sel(sel),
                 .in(in));


   //----------------------------------------------
   // VCD
   //----------------------------------------------
   initial  begin
      $dumpfile ("rdselh_tb.vcd");
      $dumpvars;
   end


   //----------------------------------------------
   // Clock
   //----------------------------------------------
   reg clk;

   initial begin
      clk = 0;
   end

   always begin
      #4 clk = ~clk;
   end

   //----------------------------------------------
   // Test Vectors
   //----------------------------------------------
   integer    cpt;
   reg [31:0] out_ref;

   initial begin
      sel       = 0;
      is_signed = 0;
      in        = 0;
      cpt       = 0;
      out_ref   = 0;
   end

   always @(posedge clk) begin
      cpt <= cpt + 1;
   end

   always @ (posedge clk) begin
      case (cpt)
         0: begin
            sel       <= 0;
            is_signed <= 0;
            in        <= 32'h788EFD0C;
            out_ref   <= 32'h0000FD0C;
         end

         1: begin
            sel       <= 0;
            is_signed <= 1;
            in        <= 32'h788EFD0C;
            out_ref   <= 32'hFFFFFD0C;
         end

         2: begin
            sel       <= 1;
            is_signed <= 0;
            in        <= 32'h788EFD0C;
            out_ref   <= 32'h0000788E;
         end

         3: begin
            sel       <= 1;
            is_signed <= 1;
            in        <= 32'h788EFD0C;
            out_ref   <= 32'h0000788E;
         end

         5: $finish;
      endcase
   end

   //----------------------------------------------
   // Checker
   //----------------------------------------------
   always @(posedge clk) begin
      $write("cpt(%0d) out(32'h%08h) out_ref(32'h%08h)", cpt, out, out_ref);

      if (out != out_ref) begin
         $display(" -> Error");
      end
      else begin
         $display(" -> Ok");
      end
   end

endmodule // rdselh_tb
