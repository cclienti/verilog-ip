//                              -*- Mode: Verilog -*-
// Filename        : rdselh.v
// Description     : Half word read select
// Author          : Christophe Clienti
// Created On      : Sun Feb 17 09:39:17 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Sun Feb 17 09:39:17 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

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
