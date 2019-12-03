//-----------------------------------------------------------------------------
// Title: PWM Generator
//-----------------------------------------------------------------------------
// Description: Pulse Width Generator.
//
//-----------------------------------------------------------------------------
// Copyright (c) 2019 by Christophe Clienti. This model is the
// confidential and proprietary property of Christophe Clienti and the
// possession or use of this file requires a written license from
// Christophe Clienti.
//-----------------------------------------------------------------------------

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
