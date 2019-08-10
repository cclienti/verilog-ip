//                              -*- Mode: Verilog -*-
// Filename        : barrel.v
// Description     : Barrel Shift with extra input
// Author          : Christophe Clienti
// Created On      : Sun Feb 16 11:48:17 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Sun Feb 16 11:48:17 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module barrel
  #(parameter WIDTH       = 64,  //WIDTH of the word to right shift
    parameter SHIFT_WIDTH = 6,   //WIDTH of the shift word
    parameter SHIFT_MAX   = 46,  //maximum allowable shift value
    parameter IS_REG_IN   = 1)   //register input or not

   (input wire                   clk, enable,
    input wire                   is_signed,
    input wire [SHIFT_WIDTH-1:0] shift,
    input wire [WIDTH-1:0]       in,
    input wire [WIDTH-1:0]       ex,
    output reg [WIDTH-1:0]       out);


   wire [WIDTH-1:0]        muxin[SHIFT_MAX+1:0];
   wire                    signbit;

   reg                     is_signed_reg;
   reg [SHIFT_WIDTH-1:0]   shift_reg;
   reg [WIDTH-1:0]         in_reg, ex_reg;


   // register or not inputs
   generate
      if(IS_REG_IN==0) begin
         always @(*) begin
            is_signed_reg = is_signed;
            shift_reg = shift;
            in_reg = in;
            ex_reg = ex;
         end
      end else begin
         always @ (posedge clk) begin
            if(enable == 1'b1) begin
               is_signed_reg <= is_signed;
               shift_reg <= shift;
               in_reg <= in;
               ex_reg <= ex;
            end
         end
      end
   endgenerate


   // assign bit sign depending if input are signed or not
   assign signbit = in_reg[WIDTH-1] & is_signed_reg;


   // Assign mux input with all possible shift values
   genvar                 i;
   generate
      assign muxin[0] = in_reg;
      assign muxin[SHIFT_MAX+1] = ex_reg;
      for(i=1; i<=SHIFT_MAX; i=i+1) begin : blk_muxin_in
         assign muxin[i] = {{i{signbit}}, in_reg[WIDTH-1:i]};
      end
   endgenerate


   // Assign output
   always @ ( posedge clk) begin
      if(enable == 1'b1) begin
         out <= muxin[shift_reg];
      end
   end




endmodule // barrel
