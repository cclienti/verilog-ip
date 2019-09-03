//                              -*- Mode: Verilog -*-
// Filename        : barrel_tb.v
// Description     : Barrel shifter testbenc
// Author          : Christophe Clienti
// Created On      : Sun Feb 16 16:56:17 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Sun Feb 16 16:56:17 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module barrel_tb();

   parameter WIDTH       = 32; // Width of the word to right shift
   parameter SHIFT_WIDTH = 5;  // Width of the shift word
   parameter SHIFT_MAX   = 30; // Maximum allowable shift value
   parameter IS_REG_IN   = 1;  // Register input or not

   reg                   clk, enable;
   reg                   is_signed;
   reg [SHIFT_WIDTH-1:0] shift;
   reg [WIDTH-1:0]       in, ex;
   wire [WIDTH-1:0]      out;

   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------
   barrel #(.WIDTH(WIDTH),
            .SHIFT_WIDTH(SHIFT_WIDTH),
            .SHIFT_MAX(SHIFT_MAX),
            .IS_REG_IN(IS_REG_IN))
   barrel(.clk(clk), .enable(enable), .is_signed(is_signed),
          .shift(shift), .in(in), .ex(ex), .out(out));

   //----------------------------------------------------------------
   // VCD
   //----------------------------------------------------------------
   initial begin
      $dumpfile("barrel_tb.vcd");
      $dumpvars(0, barrel_tb);
   end

   //----------------------------------------------------------------
   // Clock generation
   //----------------------------------------------------------------
   initial begin
      clk = 1'b1;
   end

   always begin
     #5 clk = ~clk;
   end

   initial begin
   end

   //----------------------------------------------------------------
   // Test Vectors
   //----------------------------------------------------------------
   reg [WIDTH-1:0] ref_out;

   integer cpt = 0;

   always @(posedge clk) begin
      cpt <= cpt + 1;
   end

   always @(*) begin
      case(cpt)
         0: begin
            enable = 1'b0;
            is_signed = 1'b0;
            shift = 0;
            in = 0;
            ex = 32'hCAFEDECA;
            ref_out = 0;
         end

         1: begin
            enable = 1'b1;
            is_signed = 1'b0;
            shift = 4;
            in = 32'h89ab0000;
            ex = 32'hCAFEDECA;
            ref_out = 32'h089ab000;
         end

         2: begin
            enable = 1'b1;
            is_signed = 1'b1;
            shift = 4;
            in = 32'h89ab0000;
            ex = 32'hCAFEDECA;
            ref_out = 32'hf89ab000;
         end

         3: begin
            enable = 1'b1;
            is_signed = 1'b1;
            shift = 0;
            in = 32'h89ab0000;
            ex = 32'hCAFEDECA;
            ref_out = 32'h89ab0000;
         end

         4: begin
            enable = 1'b1;
            is_signed = 1'b1;
            shift = 30;
            in = 32'h89ab0000;
            ex = 32'hCAFEDECA;
            ref_out = 32'hfffffffe;
         end

         5: begin
            enable = 1'b1;
            is_signed = 1'b0;
            shift = 30;
            in = 32'h89ab0000;
            ex = 32'hCAFEDECA;
            ref_out = 32'h00000002;
         end

         6: begin
            enable = 1'b1;
            is_signed = 1'b0;
            shift = 31;
            in = 32'h89ab0000;
            ex = 32'hCAFEDECA;
            ref_out = 32'hCAFEDECA;
         end

         10: begin
            $finish;
         end
      endcase
   end

   //----------------------------------------------------------------
   // Checker
   //----------------------------------------------------------------
   reg [WIDTH-1:0] ref_out_0, ref_out_1;

   always @(posedge clk) begin
      ref_out_0 <= ref_out;
      ref_out_1 <= ref_out_0;
   end

   wire [WIDTH-1:0] ref_out_v;
   assign ref_out_v = (IS_REG_IN == 0) ? ref_out_0 : ref_out_1;

   always @(posedge clk) begin
      if (ref_out_v != out) begin
         $display("Error: ref is 32'h%08h, obtained 32'h%08h", ref_out_v, out);
      end
   end



endmodule //barrel_tb
