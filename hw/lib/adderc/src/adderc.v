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
