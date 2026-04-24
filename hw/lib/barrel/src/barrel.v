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

module barrel
  #(parameter WIDTH       = 64,                  // Width of the word to right shift
    parameter SHIFT_MAX   = 46,                  // Maximum allowable shift value
    parameter SHIFT_WIDTH = $clog2(SHIFT_MAX+2), // Width of the shift word
    parameter IS_REG_IN   = 1)                   // Register input or not

   (input wire                   clk, enable,
    input wire                   is_signed,
    input wire [SHIFT_WIDTH-1:0] shift,
    input wire [WIDTH-1:0]       in,
    input wire [WIDTH-1:0]       ex, // out <= ex ? shit==SHIFT_MAX+1 : ...
    output reg [WIDTH-1:0]       out);


   wire [WIDTH-1:0]        muxin[SHIFT_MAX+1:0];
   wire                    signbit;

   reg                     is_signed_reg;
   reg [SHIFT_WIDTH-1:0]   shift_reg;
   reg [WIDTH-1:0]         in_reg, ex_reg;


   // Check parameters
   initial begin
      if ($clog2(SHIFT_MAX+2) > SHIFT_WIDTH) begin
         $display("Error: %m: parameter SHIFT_WIDTH cannot fit requested SHIFT_MAX value");
         $finish;
      end
   end

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
