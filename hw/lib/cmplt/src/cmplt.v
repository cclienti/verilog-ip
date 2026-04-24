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



//Inspired from the RTL Hardware Design Using VHDL book

`timescale 1 ns / 100 ps

module cmplt
  #(parameter WIDTH = 32)

   (input wire [WIDTH-1:0] a, b,
    input wire             is_signed,
    output wire            out);


   wire sign_a, sign_b;
   wire sign, cmpabs;

   assign sign_a = a[WIDTH-1];
   assign sign_b = b[WIDTH-1];

   assign sign = sign_b & (~sign_a);

   assign cmpabs = (a[WIDTH-2:0] < b[WIDTH-2:0]) ? 1'b1 : 1'b0;

   assign out = (sign_a == sign_b)  ? cmpabs :
                (is_signed == 1'b0) ? sign : ~sign;

endmodule
