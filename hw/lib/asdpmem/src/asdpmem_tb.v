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

module asdpmem_tb();

   parameter DEPTH = 6;
   parameter WIDTH = 32;

   reg              clka, ena, wea;
   reg [DEPTH-1:0]  addra;
   reg [WIDTH-1:0]  dia;

   reg [DEPTH-1:0]  addrb;
   wire [WIDTH-1:0] dob;

   integer          cpt = 0;


   asdpmem #(.DEPTH(DEPTH), .WIDTH(WIDTH))
   asdpmem(.clka(clka), .ena(ena), .wea(wea),
           .addra(addra), .dia(dia),
           .addrb(addrb), .dob(dob));

   //----------------------------------------------------------------
   // VCD
   //----------------------------------------------------------------
   initial begin
      $dumpfile("asdpmem_tb.vcd");
      $dumpvars(0,asdpmem_tb);
   end

   //----------------------------------------------------------------
   // Clock generation
   //----------------------------------------------------------------
   initial begin
      clka = 0;
   end

   always begin
      #5 clka = ~clka;
   end

   //----------------------------------------------------------------
   // Test Vectors
   //----------------------------------------------------------------
   always @ (posedge clka) begin
      cpt <= cpt + 1;
   end

   always @ (cpt) begin
      case (cpt)
         0: begin
            ena = 1;
            wea = 0;
            dia = 0;
            addra = 0;
            addrb = 1;
         end

         2: begin
            wea = 1;
            dia = 32'h11223344;
            addra = 1;
         end

         3: begin
            wea = 1;
            dia = 32'h55667788;
            addra = 2;
         end

         4: begin
            wea = 0;
            dia = 0;
            addra = 0;
            addrb = 2;
         end
      endcase // case (cpt)
   end

   //----------------------------------------------------------------
   // Reference
   //----------------------------------------------------------------
   always @ (cpt) begin
      case (cpt)
         3: begin
            if (dob != 32'h11223344) begin
               $display("Error: dob obtained (32'h%08h) - reference (32'h11223344)", dob);
            end
         end

         4: begin
            if (dob != 32'h55667788) begin
               $display("Error: dob obtained (32'h%08h) - reference (32'h55667788)", dob);
            end
         end

         5: begin
            if (dob != 32'h55667788) begin
               $display("Error: dob obtained (32'h%08h) - reference (32'h55667788)", dob);
            end
         end

         6: begin
            $finish();
         end
      endcase
   end


endmodule
