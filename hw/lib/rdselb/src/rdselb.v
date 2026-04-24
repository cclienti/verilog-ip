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

module rdselb
  (input wire         is_signed,
   input wire [1:0]   sel,
   input wire [31:0]  in,
   output wire [31:0] out);



   wire [7:0]    bytesel;
   wire [31:0]   zext, sext;

   assign bytesel = (sel==2'b00) ? in[ 7: 0] :
                    (sel==2'b01) ? in[15: 8] :
                    (sel==2'b10) ? in[23:16] : in[31:24];

   assign sext = { {24{bytesel[7]}}, bytesel };

   assign zext = { {24{1'b0}}, bytesel };

   assign out = (is_signed==1'b0) ? zext : sext;

endmodule // rdselb
