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
   parameter WIDTH_A = 16;
   parameter WIDTH_B = 16;
   parameter NB_OUT_REG = 1;


   reg         clk;
   reg         enable;
   reg         is_signed;

   reg [WIDTH_A-1:0] a = 0;
   reg [WIDTH_B-1:0] b = 0;

   wire [WIDTH_A+WIDTH_B-1:0] out;

   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------
   multiplier #(.WIDTH_A(WIDTH_A),
                .WIDTH_B(WIDTH_B),
                .NB_OUT_REG(NB_OUT_REG))
   DUT(.clk(clk),
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

   always
     #5 clk = ~clk;

   //----------------------------------------------------------------
   // Test Vectors
   //----------------------------------------------------------------
   initial begin
      enable = 1'b0;
      is_signed = 1'b0;
      #10 enable = 1'b1;
   end

   always @(posedge clk) begin
      a <= a + 1;
      b <= b - 3;
      is_signed <= ~is_signed;
   end



endmodule // multiplier_tb
