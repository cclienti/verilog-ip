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

module pwm_generator
  #(parameter PWM_WIDTH = 32)
   (input wire                 clock,
    input wire                 srst,
    input wire [PWM_WIDTH-1:0] pwm_high_max,
    input wire [PWM_WIDTH-1:0] pwm_max,
    output reg                 pwm_output);

   //-------------------------------------------------------------------------
   // Ratio counter
   //-------------------------------------------------------------------------

   reg [PWM_WIDTH-1:0] ratio_counter;

   always @(posedge clock) begin
      if (srst) begin
         ratio_counter <= 0;
         pwm_output    <= 1'b0;
      end
      else begin
         if (ratio_counter == pwm_max) begin
            ratio_counter <= 0;
            pwm_output    <= 1'b1;
         end
         else begin
            ratio_counter <= ratio_counter + 1'b1;
            if (ratio_counter == pwm_high_max) begin
               pwm_output <= 1'b0;
            end
         end
      end
   end


endmodule
