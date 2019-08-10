//                              -*- Mode: Verilog -*-
// Filename        : rdselb.v
// Description     : Byte read select
// Author          : Christophe Clienti
// Created On      : Sun Feb 17 09:39:17 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Sun Feb 17 09:39:17 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

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
