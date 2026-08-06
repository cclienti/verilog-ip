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

   integer errors = 0;

   //----------------------------------------------------------------
   // Clock generation
   //----------------------------------------------------------------
   initial begin
      clock = 1'b1;
      # 1000000;
      if (errors == 0)
        $display("smalldiv_tb: ALL TESTS PASSED");
      else
        $display("smalldiv_tb: %0d ERROR(S)", errors);
      $finish;
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

   // Typed integer, and each term widened explicitly: the sum of two
   // 1-bit comparison results is evaluated in 1-bit width by Verilator
   // (1+1 overflows to 0), while iverilog widens it -- with DELAY 0 the
   // reference pipeline degenerates to a wire and every registered
   // configuration miscompares.
   localparam integer DELAY = (REGISTER_IN != 0 ? 1 : 0) + (REGISTER_OUT != 0 ? 1 : 0);

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
   // Case equality: with ==, an X on either output compares as "maybe
   // equal" and the bench prints nothing -- an undriven DUT passed.
   wire test_ok = (quotient_ref === quotient) && (remainder_ref === remainder);

   // The reference pipeline needs DELAY+1 enabled cycles before its
   // output and the DUT's refer to the same dividend: the head of the
   // reference chain is combinational, so the first enabled edge from
   // cold captures it one cycle before the DUT's input register holds
   // real data. Under a four-state simulator the warm-up self-masks --
   // both pipelines hold X and X === X passes -- but under Verilator's
   // two-state semantics everything starts at zero and the skew shows,
   // so the warm-up is skipped explicitly.
   integer warmup = 0;

   always @(posedge clock) begin
      if (enable && warmup <= DELAY+1) begin
         warmup <= warmup + 1;
      end
   end

   // Sampled on the falling edge: dividend advances at the posedge, and
   // in the combinational configuration both the reference and the DUT
   // are direct functions of it -- a posedge checker races that update,
   // and which value it reads differs between simulators. Mid-cycle,
   // everything is settled.
   always @(negedge clock) begin
      if (enable && warmup > DELAY+1) begin
         if (!test_ok) begin
            errors = errors + 1;
            $display({"Error in %m: dividend: %0d, quotient ref: %0d - obtained: %0d, ",
                      "remainder ref: %0d - obtained: %0d"},
                     dividend_delayed[0], quotient_ref, quotient, remainder_ref, remainder);
            $display("smalldiv_tb: %0d ERROR(S)", errors);
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
