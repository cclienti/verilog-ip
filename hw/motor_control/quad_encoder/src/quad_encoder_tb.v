//-----------------------------------------------------------------------------
// Title: Quadrature Encoder Testbench
//-----------------------------------------------------------------------------
// Description: Test the quad_encoder module.
//
//-----------------------------------------------------------------------------
// Copyright (c) 2019 by Christophe Clienti. This model is the
// confidential and proprietary property of Christophe Clienti and the
// possession or use of this file requires a written license from
// Christophe Clienti.
//-----------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module quad_encoder_tb;

   //----------------------------------------------------------------
   // Contants
   //----------------------------------------------------------------

   localparam SAMPLING_WIDTH = 16;
   localparam NUM_SAMPLER_FILTER = 5;


   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------

   reg                      clock;
   reg                      srst;
   reg [SAMPLING_WIDTH-1:0] sampling;
   wire                     channel_a;
   wire                     channel_b;
   wire                     direction;
   wire                     pulse;


   //----------------------------------------------------------------
   // Value Change Dump
   //----------------------------------------------------------------

   initial  begin
      $dumpfile ("quad_encoder_tb.vcd");
      $dumpvars;
   end


   //----------------------------------------------------------------
   // Clock and Reset Generation
   //----------------------------------------------------------------

   reg arst;

   initial begin
      clock  = 0;
      arst   = 1;
      srst   = 1;
      #1000 arst = 0;
   end

   always begin
      #20 clock = !clock;
   end

   always @(posedge clock) begin
      srst <= arst;
   end


   //----------------------------------------------------------------
   // Init
   //----------------------------------------------------------------

   initial begin
      sampling = 1;
   end


   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------

   quad_encoder #(.SAMPLING_WIDTH (SAMPLING_WIDTH),
                  .NUM_SAMPLER_FILTER (NUM_SAMPLER_FILTER))
   quad_encoder_inst (.clock     (clock),
                      .srst      (srst),
                      .sampling  (sampling),
                      .channel_a (channel_a),
                      .channel_b (channel_b),
                      .direction (direction),
                      .pulse     (pulse));


   //----------------------------------------------------------------
   // Count pulse
   //----------------------------------------------------------------

   integer count;

   initial begin
      count = 0;
   end

   always @(posedge clock) begin
      if (pulse == 1'b1) begin
         count <= direction ? count + 1 : count - 1;
      end
   end


   //----------------------------------------------------------------
   // Helpers
   //----------------------------------------------------------------

   reg [3:0] [1:0] channel_states;
   reg [1:0]       channel_state;
   reg [1:0]       channels;

   always @(*) begin
      channels = channel_states[channel_state];
   end

   assign channel_a = channels[0];
   assign channel_b = channels[1];

   initial begin
      channel_state = 0;
      channel_states[0] = 2'b00;
      channel_states[1] = 2'b01;
      channel_states[2] = 2'b11;
      channel_states[3] = 2'b10;
   end

   integer count_ref;

   task rotate(input reg direction, input reg [SAMPLING_WIDTH-1:0] delay);
      begin
         channel_state <= channel_state + (direction ? 1 : -1);
         repeat(delay + 1) @(posedge clock);

         count_ref = count_ref + (direction ? 1 : -1);
         $write("count = %0d, count_ref = %0d", count, count_ref / 2);
         if (count != count_ref / 2) begin
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

   initial begin
      count_ref = 1;
      repeat(20) rotate(1, 40);
      repeat(20) rotate(1, 20);

      count_ref = count_ref - 1;
      repeat(20) rotate(0, 20);
      repeat(20) rotate(0, 40);
      #100 $finish;
   end

endmodule
