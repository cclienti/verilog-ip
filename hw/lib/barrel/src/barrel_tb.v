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

   parameter WIDTH       = 32; //WIDTH of the word to right shift
   parameter SHIFT_WIDTH = 5;  //WIDTH of the shift word
   parameter SHIFT_MAX   = 30; //maximum allowable shift value
   parameter IS_REG_IN   = 1;  //register input or not

   reg                  clk, enable;
   reg                  is_signed;
   reg [SHIFT_WIDTH-1:0] shift;
   reg [WIDTH-1:0]      in, ex;
   wire [WIDTH-1:0]     out;

   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------
   barrel #(.WIDTH(WIDTH),
            .SHIFT_WIDTH(SHIFT_WIDTH),
            .SHIFT_MAX(SHIFT_MAX),
            .IS_REG_IN(IS_REG_IN))
   DUT(.clk(clk), .enable(enable), .is_signed(is_signed),
       .shift(shift), .in(in), .ex(ex), .out(out));

   //----------------------------------------------------------------
   // VCD
   //----------------------------------------------------------------
   initial begin
      $dumpfile("barrel_tb.vcd");
      $dumpvars(0,barrel_tb);
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

   initial begin
      enable = 1'b0;
      is_signed = 1'b0;
      in = 0;
      ex = 32'hCAFEDECA;
      shift = 0;
      #10 enable = 1'b1;
   end

   //----------------------------------------------------------------
   // Test Vectors
   //----------------------------------------------------------------

   always @(posedge clk) begin
      in <= in - 1;
      shift <= shift + 1;
      is_signed <= ~is_signed;
   end


endmodule //barrel_tb
