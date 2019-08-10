//                              -*- Mode: Verilog -*-
// Filename        : cmplt.v
// Description     : Signed-unsigned dual-mode comparator
// Author          : Christophe Clienti
// Created On      : Wed Feb 16 13:03:45 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Wed Feb 16 13:03:45 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

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
