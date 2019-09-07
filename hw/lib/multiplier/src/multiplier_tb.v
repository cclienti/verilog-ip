//                              -*- Mode: Verilog -*-
// Filename        : multiplier_tb.v
// Description     : Signed/Unsigned multiplier testbench
// Author          : Christophe Clienti
// Created On      : Sun Feb 16 17:39:26 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Sun Feb 16 17:39:26 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

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
