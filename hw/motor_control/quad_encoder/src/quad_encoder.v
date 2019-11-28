//-----------------------------------------------------------------------------
// Title: Quadrature Encoder
// -----------------------------------------------------------------------------
// Description: Manage quadrature encoder signals to determine
// movement rotation direction and speed.
//
//-----------------------------------------------------------------------------
// Copyright (c) 2019 by Christophe Clienti. This model is the
// confidential and proprietary property of Christophe Clienti and the
// possession or use of this file requires a written license from
// Christophe Clienti.
//-----------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module quad_encoder
  #(parameter SAMPLING_WIDTH = 16,
    parameter NUM_SAMPLER_FILTER = 5)
   (input wire                      clock,
    input wire                      srst,
    input wire [SAMPLING_WIDTH-1:0] sampling,
    input wire                      channel_a,
    input wire                      channel_b,
    output reg                      direction,
    output reg                      pulse);


   //-----------------------------------------------------------------------------
   // Sampling
   //-----------------------------------------------------------------------------

   reg [SAMPLING_WIDTH-1:0] sampling_counter;
   reg                      sample;

   always @(posedge clock) begin
      if (srst == 1'b1) begin
         sampling_counter <= 0;
      end
      else begin
         if (sample == 1'b1) begin
            sampling_counter <= 0;
         end
         else begin
            sampling_counter <= sampling_counter + 1'b1;
         end
      end
   end

   always @(*) begin
      if (sampling_counter == sampling) begin
         sample = 1'b1;
      end
      else begin
         sample = 1'b0;
      end
   end


   //-----------------------------------------------------------------------------
   // Filter inputs
   //-----------------------------------------------------------------------------

   reg [NUM_SAMPLER_FILTER:0] channel_a_regs;
   reg [NUM_SAMPLER_FILTER:0] channel_b_regs;

   always @(posedge clock) begin
      if (srst == 1'b1) begin
         channel_a_regs <= 0;
         channel_b_regs <= 0;
      end
      else begin
         if (sample) begin
            channel_a_regs <= {channel_a_regs[NUM_SAMPLER_FILTER-1:0], channel_a};
            channel_b_regs <= {channel_b_regs[NUM_SAMPLER_FILTER-1:0], channel_b};
         end
      end
   end

   reg channel_a_filt, channel_a_filt_reg;
   reg channel_b_filt, channel_b_filt_reg;

   always @(posedge clock) begin
      if (srst == 1'b1) begin
         channel_a_filt <= 0;
         channel_b_filt <= 0;
         channel_a_filt_reg <= 0;
         channel_b_filt_reg <= 0;
      end
      else begin
         channel_a_filt <= | channel_a_regs[NUM_SAMPLER_FILTER:1];
         channel_b_filt <= | channel_b_regs[NUM_SAMPLER_FILTER:1];
         channel_a_filt_reg <= channel_a_filt;
         channel_b_filt_reg <= channel_b_filt;
      end
   end


   //-----------------------------------------------------------------------------
   // Direction
   //-----------------------------------------------------------------------------

   always @(posedge clock) begin
      if (srst == 1'b1) begin
         direction <= 0;
         pulse <= 0;
      end
      else begin
         direction <= channel_a_filt ^ channel_b_filt_reg;
         pulse <= (channel_a_filt ^ channel_a_filt_reg ^ channel_b_filt ^ channel_b_filt_reg) & !direction;
      end
   end

endmodule
