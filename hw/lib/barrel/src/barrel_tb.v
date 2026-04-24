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
