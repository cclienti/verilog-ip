//                              -*- Mode: Verilog -*-
// Filename        : smalldiv.v
// Description     : Small Constant Divider Testbench
// Author          : Christophe Clienti
// Created On      : Sun Aug 11 15:42:58 2019
// Last Modified By: Christophe Clienti
// Last Modified On: Sun Aug 11 15:42:58 2019
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved


`timescale 1 ns / 100 ps

module smalldiv_tb();
   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------
   localparam DIVIDER_VALUE         = 5;
   localparam DIVIDER_WIDTH         = $clog2(DIVIDER_VALUE);
   localparam DIVIDEND_WIDTH        = 18;
   localparam THEORETICAL_LUT_WIDTH = 6;
   localparam REGISTER_IN           = 0;
   localparam REGISTER_OUT          = 1;
   localparam PIPELINE              = 1;

   reg                                     clock;
   reg                                     enable;
   reg [DIVIDEND_WIDTH-1:0]                dividend;
   wire [DIVIDEND_WIDTH-DIVIDER_WIDTH-1:0] quotient;
   wire [DIVIDER_WIDTH-1:0]                remainder;

   smalldiv
   #(
      .DIVIDER_VALUE         (DIVIDER_VALUE),
      .DIVIDER_WIDTH         (DIVIDER_WIDTH),
      .DIVIDEND_WIDTH        (DIVIDEND_WIDTH),
      .THEORETICAL_LUT_WIDTH (THEORETICAL_LUT_WIDTH),
      .REGISTER_IN           (REGISTER_IN),
      .REGISTER_OUT          (REGISTER_OUT),
      .PIPELINE              (PIPELINE)
   )
   smalldiv_inst
   (
      .clock     (clock),
      .enable    (enable),
      .dividend  (dividend),
      .quotient  (quotient),
      .remainder (remainder)
   );

   //----------------------------------------------------------------
   // VCD
   //----------------------------------------------------------------
   initial begin
      $dumpfile("smalldiv_tb.vcd");
      $dumpvars(0, smalldiv_tb);
   end

   //----------------------------------------------------------------
   // Clock generation
   //----------------------------------------------------------------
   initial begin
      clock = 1'b1;
      # 1000000 $finish;
   end

   always begin
     #5 clock = ~clock;
   end

   initial begin
      dividend = 0;
      enable = 1'b0;
      #10 enable = 1'b1;
   end

   //----------------------------------------------------------------
   // Test vectors
   //----------------------------------------------------------------
   always @(posedge clock) begin
      if (enable) begin
         dividend <= dividend + 1;
      end
   end

endmodule
