//                              -*- Mode: Verilog -*-
// Filename        : dpmemrf_tb.v
// Description     : Read-first dual port RAM testbench
// Author          : Christophe Clienti
// Created On      : Sun Feb 16 16:57:05 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Sun Feb 16 16:57:05 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module dpmemrf_tb();

   parameter DEPTH = 10;
   parameter WIDTH = 32;
   parameter OUTREGA = 1;
   parameter OUTREGB = 0;

   reg              clka, ena, wea;
   reg [DEPTH-1:0]  addra;
   reg [WIDTH-1:0]  dia;
   wire [WIDTH-1:0] doa;

   reg              clkb, enb, web;
   reg [DEPTH-1:0]  addrb;
   reg [WIDTH-1:0]  dib;
   wire [WIDTH-1:0] dob;

   integer          cpta = 0;
   integer          cptb = 0;


   dpmemrf #(.DEPTH(DEPTH), .WIDTH(WIDTH),
             .OUTREGA(OUTREGA), .OUTREGB(OUTREGB))
   dpmemrf(.clka(clka), .ena(ena), .wea(wea),
           .addra(addra), .dia(dia), .doa(doa),
           .clkb(clkb), .enb(enb), .web(web),
           .addrb(addrb), .dib(dib), .dob(dob));

   //----------------------------------------------------------------
   // VCD
   //----------------------------------------------------------------
   initial begin
      $dumpfile("dpmemrf_tb.vcd");
      $dumpvars(0, dpmemrf_tb);
   end

   //----------------------------------------------------------------
   // Clock generation
   //----------------------------------------------------------------
   initial begin
      clka = 1'b1;
      clkb = 1'b1;
   end

   always fork
      #4 clka = ~clka;
      #5 clkb = ~clkb;
   join

   //----------------------------------------------------------------
   // Test Vectors
   //----------------------------------------------------------------
   always @ (posedge clka) begin
      cpta <= cpta + 1;
   end

   always @ (posedge clkb) begin
      cptb <= cptb + 1;
   end

   always @ (cpta) begin
      case (cpta)
         0: begin
            ena = 1;
            wea = 0;
            dia = 0;
            addra = 0;
         end

         1: begin
            wea = 1;
            dia = 32'h11223344;
            addra = 1;
         end

         2: begin
            wea = 1;
            dia = 32'h55667788;
            addra = 2;
         end

         3: begin
            wea = 0;
            dia = 0;
            addra = 2;
         end

         10: begin
            $finish;
         end
      endcase
   end

   always @ (cptb) begin
      case (cptb)
         0: begin
            enb = 0;
            web = 0;
            dib = 0;
            addrb = 0;
         end

         3: begin
            enb = 1;
            web = 1;
            dib = 32'hCAFEDECA;
            addrb = 2;
         end
      endcase
   end

   //----------------------------------------------------------------
   // Reference
   //----------------------------------------------------------------
   always @ (posedge clka) begin
      case (cpta)
         5: begin
            if (doa != 32'h55667788) begin
               $display("Error: cpta(%0d) doa(32'h%08h) ref(32'h55667788)", cpta, doa);
            end
         end

         6: begin
            if (doa != 32'hCAFEDECA) begin
               $display("Error: cpta(%0d) doa(32'h%08h) ref(32'hCAFEDECA)", cpta, doa);
            end
         end
      endcase
   end

   always @ (posedge clkb) begin
      case (cptb)
         4: begin
            if (dob != 32'h55667788) begin
               $display("Error: cptb(%0d) dob(32'h%08h) ref(32'h55667788)", cptb, dob);
            end
         end

         5: begin
            if (dob != 32'hCAFEDECA) begin
               $display("Error: cptb(%0d) dob(32'h%08h) ref(32'hCAFEDECA)", cptb, dob);
            end
         end
      endcase
   end

endmodule
