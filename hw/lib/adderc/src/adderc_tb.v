//                              -*- Mode: Verilog -*-
// Filename        : adderc_tb.v
// Description     : Adderc testbench
// Author          : Christophe Clienti
// Created On      : Sun Feb 16 16:33:30 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Sun Feb 16 16:33:30 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module adderc_tb () ;
   parameter IS_REG_OUT = 1;
   parameter WIDTH = 16;

   reg              clk, srst, enable;
   reg              sub_nadd, cin;
   reg [WIDTH-1:0]  a, b;

   wire [WIDTH-1:0] out;
   wire             cout;

   integer          cpt=0;


   adderc #(.IS_REG_OUT(IS_REG_OUT),
            .WIDTH(WIDTH))
   DUT(.out(out), .cout(cout),
       .clk(clk), .srst(srst), .enable(enable),
       .sub_nadd(sub_nadd) , .cin(cin), .a(a), .b(b));

   initial begin
      clk = 0;
      srst = 1;
      enable = 1;
      #10 srst = 1;
      #10 srst = 0;
   end

   always
     #2 clk = !clk;

   initial  begin
      $dumpfile ("adderc_tb.vcd");
      $dumpvars;
   end

   initial
     #1000 $finish;

   always @(posedge clk)
     if(srst) begin
        cpt <= 0;
     end else begin
        cpt <= cpt + 1;
     end


   always @ (cpt)
     begin
        case (cpt)
          0: begin
             a = 0;
             b = 0;
             sub_nadd = 0;
             cin = 0;
          end
          1: begin
             a = 1;
             b = 2;
             sub_nadd = 0;
             cin = 1;
          end
          2: begin
             a = 1;
             b = 2;
             sub_nadd = 1;
             cin = 1;
          end
          3: begin
             a = -1;
             b = -1;
             sub_nadd = 0;
             cin = 0;
          end
          4: begin
             a = -1;
             b = 1;
             sub_nadd = 1;
             cin = 1;
          end
        endcase // case (cpt)
     end

endmodule // adderc_tb
