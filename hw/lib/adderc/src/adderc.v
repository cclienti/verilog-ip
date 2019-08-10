//                              -*- Mode: Verilog -*-
// Filename        : adderc.v
// Description     : Adder with carry in/out
// Author          : Christophe Clienti
// Created On      : Sun Feb 16 16:33:00 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Sun Feb 16 16:33:00 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module adderc
  #(parameter IS_REG_OUT = 1,
    parameter WIDTH      = 32)

   (input wire             clk, srst, enable,
    input wire             sub_nadd, cin,
    input wire [WIDTH-1:0] a, b,
    output reg [WIDTH-1:0] out,
    output reg             cout);



   wire [WIDTH:0]     adder_a, adder_b;
   wire [WIDTH:0]     adder_out;
   wire               adder_cout;

   assign adder_a = {1'b0, a};
   assign adder_b = {1'b0, (sub_nadd) ? ~b : b};
   assign adder_out = adder_a + adder_b + {{WIDTH{1'b0}}, cin};


   generate
      if(IS_REG_OUT != 0) begin
         always @ (posedge clk) begin
            if(srst == 1'b1) begin
               out  <= 0;
               cout <= 0;
            end else if(enable == 1'b1) begin
               out  <= adder_out[WIDTH-1:0];
               cout <= adder_out[WIDTH];
            end
         end
      end else begin
         always @(*) begin
            out  = adder_out[WIDTH-1:0];
            cout = adder_out[WIDTH];
         end
      end
   endgenerate

endmodule // adderc
