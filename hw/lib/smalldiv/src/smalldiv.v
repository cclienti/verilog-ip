//                              -*- Mode: Verilog -*-
// Filename        : smalldiv.v
// Description     : Small Constant Divider
// Author          : Christophe Clienti
// Created On      : Sun Aug 11 15:42:58 2019
// Last Modified By: Christophe Clienti
// Last Modified On: Sun Aug 11 15:42:58 2019
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved


`timescale 1 ns / 100 ps

module smalldiv
  #(parameter DIVIDER_VALUE         = 5,
    parameter DIVIDER_WIDTH         = $clog2(DIVIDER_VALUE),
    parameter DIVIDEND_WIDTH        = 18,
    parameter THEORETICAL_LUT_WIDTH = 6,
    parameter REGISTER_IN           = 1,
    parameter REGISTER_OUT          = 1,
    parameter PIPELINE              = 1)

   (input wire                                    clock,
    input wire                                    enable,
    input wire [DIVIDEND_WIDTH-1:0]               dividend,
    output reg [DIVIDEND_WIDTH-DIVIDER_WIDTH-1:0] quotient,
    output reg [DIVIDER_WIDTH-1:0]                remainder);

   //----------------------------------------------------------------
   // Local parameters
   //----------------------------------------------------------------

   localparam THEORETICAL_DIGIT_WIDTH = THEORETICAL_LUT_WIDTH - DIVIDER_WIDTH;
   localparam DIGIT_WIDTH             = (THEORETICAL_DIGIT_WIDTH < 0) ?
                                        DIVIDER_WIDTH : THEORETICAL_DIGIT_WIDTH;

   // The padding size must allow to feed the first lut with a wider
   // input than others because we don't use the LUT's remainder
   // input.
   localparam REMAINDER_WIDTH       = DIVIDER_WIDTH;
   // The first (MSB) LUT will process DIGIT_WIDTH + REMAINDER_WIDTH.
   localparam PADDING_WIDTH_TO_NORM = (DIVIDEND_WIDTH - REMAINDER_WIDTH) % DIGIT_WIDTH;
   localparam NUM_DIGITS            = (DIVIDEND_WIDTH - REMAINDER_WIDTH) / DIGIT_WIDTH;
   // If PADDING_WIDTH_TO_NORM is zero, there is nothing to pad.
   localparam PADDING_WIDTH         = PADDING_WIDTH_TO_NORM == 0 ? 0 : DIGIT_WIDTH - PADDING_WIDTH_TO_NORM;
   localparam PADDED_DIVIDEND_WIDTH  = DIVIDEND_WIDTH + PADDING_WIDTH;


   //----------------------------------------------------------------
   // Check Parameters
   //----------------------------------------------------------------

   initial begin
      if ($clog2(DIVIDER_VALUE) > DIVIDER_WIDTH) begin
         $display("DIVIDER_WIDTH (%0d) is not large enough to fit DIVIDER_VALUE (%0d)",
                  DIVIDER_WIDTH, DIVIDER_VALUE);
         $finish;
      end
      if (DIVIDER_VALUE <= 1) begin

      end
   end


   //-------------------------------------------------
   // Register Input
   //-------------------------------------------------

   reg [DIVIDEND_WIDTH-1:0] dividend_reg;

   generate
      if (REGISTER_IN) begin
         always @(posedge clock) begin
            if (enable) begin
               dividend_reg <= dividend;
            end
         end
      end
      else begin
         always @(*) begin
            dividend_reg = dividend;
         end
      end
   endgenerate


   //-------------------------------------------------
   // Input padding
   //-------------------------------------------------

   wire [PADDED_DIVIDEND_WIDTH-1:0] padded_dividend;

   generate
      if (PADDING_WIDTH != 0) begin
         assign padded_dividend = {{PADDING_WIDTH{1'b0}}, dividend_reg};
      end
      else begin
         assign padded_dividend = dividend_reg;
      end
   endgenerate


   //-------------------------------------------------
   // Lookup table instances
   //-------------------------------------------------

   wire [NUM_DIGITS-1:0] [DIGIT_WIDTH-1:0]   lut_quotient;
   wire [NUM_DIGITS-1:0] [DIVIDER_WIDTH-1:0] lut_remainder;

   // The MSBs lookup table does not use remainder input. We feed the
   // LUT directly using the dividend.
   wire [DIGIT_WIDTH-1:0]   lut_dividend_digit;
   wire [DIVIDER_WIDTH-1:0] lut_last_remainder;

   assign lut_last_remainder = padded_dividend[PADDED_DIVIDEND_WIDTH-1 -: REMAINDER_WIDTH];
   assign lut_dividend_digit = padded_dividend[PADDED_DIVIDEND_WIDTH-REMAINDER_WIDTH-1 -: DIGIT_WIDTH];

   smalldiv_lut #(.DIGIT_WIDTH   (DIGIT_WIDTH),
                  .DIVIDER_VALUE (DIVIDER_VALUE),
                  .DIVIDER_WIDTH (DIVIDER_WIDTH))
   smalldiv_lut_inst (.dividend_digit (lut_dividend_digit),
                      .last_remainder (lut_last_remainder),
                      .quotient       (lut_quotient[NUM_DIGITS-1]),
                      .remainder      (lut_remainder[NUM_DIGITS-1]));

   // Interconnect remaining lookup tables.
   genvar i;
   generate
      for (i=0; i<NUM_DIGITS-1; i=i+1) begin
         smalldiv_lut #(.DIGIT_WIDTH   (DIGIT_WIDTH),
                        .DIVIDER_VALUE (DIVIDER_VALUE),
                        .DIVIDER_WIDTH (DIVIDER_WIDTH))
         smalldiv_lut_inst (.dividend_digit (padded_dividend[DIGIT_WIDTH*i +: DIGIT_WIDTH]),
                            .last_remainder (lut_remainder[i+1]),
                            .quotient       (lut_quotient[i]),
                            .remainder      (lut_remainder[i]));
      end
   endgenerate


   //-------------------------------------------------
   // Assemble results
   //-------------------------------------------------
   generate
      if (REGISTER_OUT) begin
         always @(posedge clock) begin
            if (enable) begin
               quotient = lut_quotient;
               remainder = lut_remainder[0];
            end
         end
      end
      else begin
         always @(*) begin
            quotient = lut_quotient;
            remainder = lut_remainder[0];
         end
      end
   endgenerate


endmodule
