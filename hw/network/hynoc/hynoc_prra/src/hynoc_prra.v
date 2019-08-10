//                              -*- Mode: Verilog -*-
// Filename        : hynoc_prra.v
// Description     : Parallel Round Robin Arbiter
// Author          : Christophe Clienti
// Created On      : Tue Jun 25 16:46:01 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Tue Jun 25 16:46:01 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module hynoc_prra
  #(parameter WIDTH      = 4,
    parameter LOG2_WIDTH = 2,
    parameter PIPELINE   = 1)

   (input wire                  clk,
    input wire                  srst,
    input wire [WIDTH-1:0]      request,
    output reg [LOG2_WIDTH-1:0] state,
    output reg [WIDTH-1:0]      grant);


   wire [LOG2_WIDTH-1:0] lut_states [WIDTH-1:0];
   reg [LOG2_WIDTH-1:0]  lut_states_reg [WIDTH-1:0];
   reg [WIDTH-1:0]       request_reg;
   reg [WIDTH-1:0]       request_reg2;
   wire                  request_reg_zero;
   reg                   request_reg2_zero;
   reg                   request_reg_state;
   reg                   request_reg2_state;
   wire [LOG2_WIDTH-1:0] lut_select;
   wire [WIDTH-1:0]      grant_comb;
   reg [WIDTH-1:0]       decoder_grant [WIDTH-1:0];

   genvar                i;

   //----------------------------------------------------------------
   // LUT instances
   //----------------------------------------------------------------

   generate
      for(i=0 ; i<WIDTH ; i=i+1) begin: lut_gen
         prra_lut
            #(.WIDTH(WIDTH), .LOG2_WIDTH(LOG2_WIDTH), .STATE_OFFSET(i))
         prra_lut_inst
            (.request(request), .state(lut_states[i]));
      end
   endgenerate


   //----------------------------------------------------------------
   // Pipeline
   //----------------------------------------------------------------

   generate
      if(PIPELINE == 0) begin: no_PIPELINE_stage

         for(i=0 ; i<WIDTH ; i=i+1) begin: lut_reg
            always @(*) begin
               lut_states_reg[i] = lut_states[i];
            end
         end

         always @(*) begin
            request_reg = request;
            request_reg_state = request[state];
         end

      end
      else begin: one_PIPELINE_stage

         for(i=0 ; i<WIDTH ; i=i+1) begin: lut_reg
            always @(posedge clk) begin
               if(srst == 1'b1) begin
                  lut_states_reg[i] <= 0;
               end
               else begin
                  lut_states_reg[i] <= lut_states[i];
               end
            end
         end

         always @(posedge clk) begin
            if(srst == 1'b1) begin
               request_reg       <= 0;
               request_reg_state <= 1'b0;
            end
            else begin
               request_reg       <= request;
               request_reg_state <= request[state];
            end
         end

     end
   endgenerate


   //----------------------------------------------------------------
   // State and grant update
   //----------------------------------------------------------------

   integer decoder_addr, decoder_value;

   initial begin
      for(decoder_addr=0 ; decoder_addr<WIDTH ; decoder_addr=decoder_addr+1) begin
         decoder_value                = 2**decoder_addr;
         decoder_grant[decoder_addr]  = decoder_value[WIDTH-1:0];
      end
   end

   assign lut_select = lut_states_reg[state];
   assign request_reg_zero = (request_reg == 0) ? 1'b1 : 1'b0;
   assign grant_comb = (request_reg_zero == 1'b1) ? {WIDTH{1'b0}} : decoder_grant[lut_select];

   always @(posedge clk) begin
      if(srst == 1'b1) begin
         request_reg2       <= 0;
         request_reg2_state <= 1'b0;
         request_reg2_zero  <= 1'b0;
      end
      else begin
         request_reg2       <= request_reg;
         request_reg2_state <= request_reg[state];
         request_reg2_zero  <= request_reg_zero;
       end
   end

   always @(posedge clk) begin
      if(srst == 1'b1) begin
         state <= 0;
         grant <= 0;
      end
      else begin
         if( ((request_reg_state == 1'b0) && (request_reg2_state == 1'b1)) ||
             (request_reg2_zero == 1'b1)) begin
            state <= lut_select;
            grant <= grant_comb;
         end
      end
   end


endmodule
