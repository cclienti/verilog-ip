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
   integer errors = 0;


   asdpmem #(.DEPTH(DEPTH), .WIDTH(WIDTH))
   asdpmem(.clka(clka), .ena(ena), .wea(wea),
           .addra(addra), .dia(dia),
           .addrb(addrb), .dob(dob));

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

   // See dpmemwf_tb: the case-0 arm never executed, leaving ena X and
   // every checked output X. Initialised here instead.
   initial begin
      ena   = 1;
      wea   = 0;
      dia   = 0;
      addra = 0;
      addrb = 1;
   end

   always @ (cpt) begin
      case (cpt)
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
   // Sampled on the falling edge: the stimulus is another always block
   // triggered by the same cpt event, so checking on @(cpt) raced it --
   // at cpt==4 the check could read dob before addrb had moved. The X
   // the old != comparison waved through hid exactly that race.
   always @ (negedge clka) begin
      case (cpt)
         3: begin
            if (dob !== 32'h11223344) begin
               errors = errors + 1;
               $display("Error: dob obtained (32'h%08h) - reference (32'h11223344)", dob);
            end
         end

         4: begin
            if (dob !== 32'h55667788) begin
               errors = errors + 1;
               $display("Error: dob obtained (32'h%08h) - reference (32'h55667788)", dob);
            end
         end

         5: begin
            if (dob !== 32'h55667788) begin
               errors = errors + 1;
               $display("Error: dob obtained (32'h%08h) - reference (32'h55667788)", dob);
            end
         end

         6: begin
            if (errors == 0)
              $display("asdpmem_tb: ALL TESTS PASSED");
            else
              $display("asdpmem_tb: %0d ERROR(S)", errors);
            $finish();
         end
      endcase
   end


endmodule
