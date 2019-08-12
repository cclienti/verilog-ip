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

`define STRINGIFY(x) `"x`"
`define PARAMDISP(x) $display("  %s = %0d", `STRINGIFY(x), x)

module smalldiv
  #(parameter DIVIDER_VALUE         = 5,
    parameter DIVIDER_WIDTH         = $clog2(DIVIDER_VALUE),
    parameter DIVIDEND_WIDTH        = 18,
    parameter THEORETICAL_LUT_WIDTH = 6,
    parameter REGISTER_IN           = 1,
    parameter REGISTER_OUT          = 1,
    parameter PIPELINE              = 1)

   (input wire                      clock,
    input wire                      enable,
    input wire [DIVIDEND_WIDTH-1:0] dividend,
    output reg [DIVIDEND_WIDTH-1:0] quotient,
    output reg [DIVIDER_WIDTH-1:0]  remainder);

   //----------------------------------------------------------------
   // Local parameters
   //----------------------------------------------------------------

   localparam THEORETICAL_DIGIT_WIDTH = THEORETICAL_LUT_WIDTH - DIVIDER_WIDTH;
   localparam DIGIT_WIDTH             = (THEORETICAL_DIGIT_WIDTH < DIVIDER_WIDTH) ?
                                        DIVIDER_WIDTH : THEORETICAL_DIGIT_WIDTH;

   // The padding size must allow to feed the first lut with a wider
   // input than others because we don't use the LUT's remainder
   // input.
   localparam REMAINDER_WIDTH       = DIVIDER_WIDTH;
   localparam PADDING_MODULO        = DIVIDEND_WIDTH % DIGIT_WIDTH;
   localparam PADDING_WIDTH         = (PADDING_MODULO == 0) ? 0 : (DIGIT_WIDTH - PADDING_MODULO);
   localparam PADDED_DIVIDEND_WIDTH = DIVIDEND_WIDTH + PADDING_WIDTH;
   localparam NUM_DIGITS            = PADDED_DIVIDEND_WIDTH / DIGIT_WIDTH;

   //----------------------------------------------------------------
   // Display Parameters
   //----------------------------------------------------------------

   initial begin
      $display("Parameters:");
      `PARAMDISP(DIVIDER_VALUE);
      `PARAMDISP(DIVIDER_WIDTH);
      `PARAMDISP(DIVIDEND_WIDTH);
      `PARAMDISP(THEORETICAL_LUT_WIDTH);
      `PARAMDISP(REGISTER_IN);
      `PARAMDISP(REGISTER_OUT);
      `PARAMDISP(PIPELINE);

      $display("Localparams:");
      `PARAMDISP(THEORETICAL_DIGIT_WIDTH);
      `PARAMDISP(DIGIT_WIDTH);
      `PARAMDISP(REMAINDER_WIDTH);
      `PARAMDISP(PADDING_MODULO);
      `PARAMDISP(PADDING_WIDTH);
      `PARAMDISP(PADDED_DIVIDEND_WIDTH);
      `PARAMDISP(NUM_DIGITS);
   end

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
         $display("DIVIDER_VALUE (%0d) is less or equal to 1", DIVIDER_WIDTH, DIVIDER_VALUE);
         $finish;
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

   wire [NUM_DIGITS-1:0] [DIGIT_WIDTH-1:0] lut_quotient;
   /* verilator lint_off UNOPTFLAT */
   wire [DIVIDER_WIDTH-1:0] lut_remainder [NUM_DIGITS:0];

   assign lut_remainder[NUM_DIGITS] = {DIVIDER_WIDTH{1'b0}};

   // Interconnect remaining lookup tables.
   genvar i;
   generate
      for (i=0; i<NUM_DIGITS; i=i+1) begin
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
   wire [PADDED_DIVIDEND_WIDTH-1:0] padded_quotient;
   assign padded_quotient = lut_quotient;

   generate
      if (REGISTER_OUT) begin
         always @(posedge clock) begin
            if (enable) begin
               quotient <= padded_quotient[DIVIDEND_WIDTH-1:0];
               remainder <= lut_remainder[0];
            end
         end
      end
      else begin
         always @(*) begin
            quotient = padded_quotient[DIVIDEND_WIDTH-1:0];
            remainder = lut_remainder[0];
         end
      end
   endgenerate


endmodule
