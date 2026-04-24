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

module multiplier_tb();
   parameter WIDTH_A      = 16;
   parameter WIDTH_B      = 16;
   parameter NB_EXTRA_REG = 1;


   reg                        clk;
   reg                        enable;
   reg                        is_signed;

   reg [WIDTH_A-1:0]          a;
   reg [WIDTH_B-1:0]          b;

   reg signed [WIDTH_A-1:0]   as;
   reg signed [WIDTH_B-1:0]   bs;

   wire [WIDTH_A+WIDTH_B-1:0] out;
   reg  [WIDTH_A+WIDTH_B-1:0] out_ref_array [NB_EXTRA_REG:0];
   wire [WIDTH_A+WIDTH_B-1:0] out_ref;

   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------
   multiplier #(.WIDTH_A(WIDTH_A),
                .WIDTH_B(WIDTH_B),
                .NB_EXTRA_REG(NB_EXTRA_REG))
   multiplier(.clk(clk),
              .enable(enable),
              .is_signed(is_signed),
              .a(a),
              .b(b),
              .out(out));

   //----------------------------------------------------------------
   // VCD
   //----------------------------------------------------------------
   initial begin
      $dumpfile("multiplier_tb.vcd");
      $dumpvars(0,multiplier_tb);
   end

   //----------------------------------------------------------------
   // Clock generation
   //----------------------------------------------------------------
   initial begin
      clk = 1'b1;
      # 10000 $finish;
   end

   always begin
     #5 clk = ~clk;
   end

   //----------------------------------------------------------------
   // Test Vectors
   //----------------------------------------------------------------
   initial begin
      a = 0;
      b = 0;
      is_signed = 1'b0;
      enable = 1'b0;
   end

   always @(posedge clk) begin
      a <= a + 1;
      b <= b - 3;
      is_signed <= a[5];
      enable <= ~enable;
   end

   //----------------------------------------------------------------
   // Checker
   //----------------------------------------------------------------
   always @(*) begin
      as = a;
      bs = b;
   end

   always @(posedge clk) begin
      if (enable) begin
         if (is_signed) begin
            out_ref_array[0] <= as * bs;
         end
         else begin
            out_ref_array[0] <= a * b;
         end
      end
   end

   generate
      genvar i;
      for (i=0; i<NB_EXTRA_REG; i=i+1) begin: GEN_EXTRA_REF_REG
         always @(posedge clk) begin
            if (enable) begin
               out_ref_array[i+1] <= out_ref_array[i];
            end
         end
      end
   endgenerate

   assign out_ref = out_ref_array[NB_EXTRA_REG];

   always @(*) begin
      $write("out(h'%0h) out_ref(h'%0h)", out, out_ref);
      if (out_ref != out) begin
         $display(" -> Error");
      end
      else begin
         $display(" -> Ok");
      end
   end
endmodule
