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

module pwm_generator_tb;

   //----------------------------------------------------------------
   // Contants
   //----------------------------------------------------------------

   localparam PWM_WIDTH = 32;


   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------

   logic                 clock;
   logic                 srst;
   logic [PWM_WIDTH-1:0] pwm_high_max;
   logic [PWM_WIDTH-1:0] pwm_max;
   logic                 pwm_output;


   //----------------------------------------------------------------
   // Value Change Dump
   //----------------------------------------------------------------

   initial  begin
      $dumpfile ("pwm_generator_tb.vcd");
      $dumpvars;
   end


   //----------------------------------------------------------------
   // Clock and Reset Generation
   //----------------------------------------------------------------

   initial begin
      clock = 0;
      while (1) begin
         #20 clock = !clock;
      end
   end


   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------

   pwm_generator #(.PWM_WIDTH (PWM_WIDTH))
   pwm_generator_inst (.clock        (clock),
                       .srst         (srst),
                       .pwm_high_max (pwm_high_max),
                       .pwm_max      (pwm_max),
                       .pwm_output   (pwm_output));


   //----------------------------------------------------------------
   // Helpers
   //----------------------------------------------------------------

   task check_pwm_state(input logic state, input integer expected_period);
      integer counter;
      begin
         counter = 0;
         while (pwm_output == state) begin
            @(posedge clock) counter = counter + 1;
         end
         $write("state %0b, measured period = %0d, expected period = %0d", state, counter, expected_period);
         if (counter != expected_period) begin
            $display(" -> Error");
         end
         else begin
            $display(" -> Ok");
         end
      end
   endtask


   //----------------------------------------------------------------
   // Test vectors
   //----------------------------------------------------------------

   integer index;

   initial begin
      // Prepare tests
      pwm_high_max = 0;
      pwm_max      = 255;

      // Manage reset
      srst = 1;
      #1000 srst <= 0;
      @(posedge clock);

      for (index=1; index < 255; index = index + 1) begin
         // Test 1
         pwm_high_max = index;
         pwm_max      = 255;
         while (pwm_output == 0) @(posedge clock);
         check_pwm_state(1'b1, pwm_high_max+1);
         check_pwm_state(1'b0, pwm_max-pwm_high_max);
      end

      // End
      #100 $finish;
   end

endmodule
