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

module rdselh
  (input wire         is_signed,
   input wire         sel,
   input wire [31:0]  in,
   output wire [31:0] out);

   wire [15:0]   bytesel;
   wire [31:0]   zext, sext;

   assign bytesel = (sel==1'b0) ? in[15: 0] : in[31:16];

   assign sext = { {16{bytesel[15]}}, bytesel };

   assign zext = { {16{1'b0}}, bytesel };

   assign out = (is_signed==1'b0) ? zext : sext;

endmodule // rdselh
