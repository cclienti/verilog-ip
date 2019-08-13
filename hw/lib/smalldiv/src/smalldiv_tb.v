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

module smalldiv_test #(parameter DIVIDER_VALUE         = 5,
                       parameter DIVIDEND_WIDTH        = 18,
                       parameter THEORETICAL_LUT_WIDTH = 6,
                       parameter REGISTER_IN           = 1,
                       parameter REGISTER_OUT          = 1);

   localparam DIVIDER_WIDTH = $clog2(DIVIDER_VALUE);

   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------
   reg                       clock;
   reg                       enable;
   reg [DIVIDEND_WIDTH-1:0]  dividend;
   wire [DIVIDEND_WIDTH-1:0] quotient;
   wire [DIVIDER_WIDTH-1:0]  remainder;

   smalldiv
   #(
      .DIVIDER_VALUE         (DIVIDER_VALUE),
      .DIVIDEND_WIDTH        (DIVIDEND_WIDTH),
      .THEORETICAL_LUT_WIDTH (THEORETICAL_LUT_WIDTH),
      .REGISTER_IN           (REGISTER_IN),
      .REGISTER_OUT          (REGISTER_OUT)
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

   //----------------------------------------------------------------
   // Check
   //----------------------------------------------------------------

   localparam DELAY=(REGISTER_IN != 0) + (REGISTER_OUT != 0);

   reg [DIVIDEND_WIDTH-1:0] dividend_delayed [DELAY:0];

   always @(*) begin
      dividend_delayed[DELAY] = dividend;
   end

   genvar i;
   generate
      for (i=0; i<DELAY; i=i+1) begin: GEN_LOOPS
         always @(posedge clock) begin
            if (enable) begin
               dividend_delayed[i] <= dividend_delayed[i+1];
            end
         end
      end
   endgenerate

   wire [DIVIDEND_WIDTH-1:0] quotient_ref = dividend_delayed[0] / DIVIDER_VALUE;
   wire [DIVIDER_WIDTH-1:0] remainder_ref = dividend_delayed[0] % DIVIDER_VALUE;
   wire test_ok = (quotient_ref == quotient) && (remainder_ref == remainder);

   always @(posedge clock) begin
      if (enable) begin
         if (!test_ok) begin
            $display({"Error in %m: dividend: %0d, quotient ref: %0d - obtained: %0d, ",
                      "remainder ref: %0d - obtained: %0d"},
                     dividend_delayed[0], quotient_ref, quotient, remainder_ref, remainder);
            $finish;
         end
      end
   end

endmodule


module smalldiv_tb();
   smalldiv_test #(.DIVIDER_VALUE         (3),
                   .DIVIDEND_WIDTH        (18),
                   .THEORETICAL_LUT_WIDTH (6),
                   .REGISTER_IN           (1),
                   .REGISTER_OUT          (1)) test0 ();

   smalldiv_test #(.DIVIDER_VALUE         (5),
                   .DIVIDEND_WIDTH        (18),
                   .THEORETICAL_LUT_WIDTH (6),
                   .REGISTER_IN           (0),
                   .REGISTER_OUT          (1)) test1 ();

   smalldiv_test #(.DIVIDER_VALUE         (7),
                   .DIVIDEND_WIDTH        (18),
                   .THEORETICAL_LUT_WIDTH (6),
                   .REGISTER_IN           (1),
                   .REGISTER_OUT          (0)) test2 ();

   smalldiv_test #(.DIVIDER_VALUE         (11),
                   .DIVIDEND_WIDTH        (18),
                   .THEORETICAL_LUT_WIDTH (6),
                   .REGISTER_IN           (0),
                   .REGISTER_OUT          (0)) test3 ();
endmodule
