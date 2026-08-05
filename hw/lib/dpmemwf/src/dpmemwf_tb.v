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

module dpmemwf_tb();

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
   integer          errors = 0;


   dpmemwf #(.DEPTH(DEPTH), .WIDTH(WIDTH),
             .OUTREGA(OUTREGA), .OUTREGB(OUTREGB))
   dpmemwf(.clka(clka), .ena(ena), .wea(wea),
           .addra(addra), .dia(dia), .doa(doa),
           .clkb(clkb), .enb(enb), .web(web),
           .addrb(addrb), .dib(dib), .dob(dob));

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

   // The case-0 arms of the stimulus below never executed: the
   // counters start at 0 and always @(counter) waits for a change, so
   // the first arm to run is 1. The enables therefore stayed X for the
   // whole simulation, the DUT never wrote, and every checked output
   // was X -- which the old != comparisons reported as Ok.
   initial begin
      ena   = 1;
      wea   = 0;
      dia   = 0;
      addra = 0;
      enb   = 1;
      web   = 0;
      dib   = 0;
      addrb = 0;
   end

   always @ (cpta) begin
      case (cpta)
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

        4: begin
           wea = 0;
           dia = 0;
           addra = 2;
        end

         10: begin
            if (errors == 0)
              $display("dpmemwf_tb: ALL TESTS PASSED");
            else
              $display("dpmemwf_tb: %0d ERROR(S)", errors);
            $finish;
         end
      endcase
   end

   always @ (cptb) begin
      case (cptb)
        3: begin
           web = 1;
           dib = 32'hCAFEDECA;
           addrb = 2;
        end

        4: begin
           web = 0;
           dib = 0;
           addrb = 2;
        end
      endcase
   end

   //----------------------------------------------------------------
   // Checker
   //----------------------------------------------------------------
   always @ (posedge clka) begin
      case (cpta)
         3: begin
            if (doa !== 32'h11223344) begin
               errors = errors + 1;
               $display("Error: cpta(%0d) doa(32'h%08h) ref(32'h11223344)", cpta, doa);
            end
         end

         4, 5: begin
            if (doa !== 32'h55667788) begin
               errors = errors + 1;
               $display("Error: cpta(%0d) doa(32'h%08h) ref(32'h55667788)", cpta, doa);
            end
         end

         6: begin
            if (doa !== 32'hCAFEDECA) begin
               errors = errors + 1;
               $display("Error: cpta(%0d) doa(32'h%08h) ref(32'hCAFEDECA)", cpta, doa);
            end
         end
      endcase
   end

   always @ (posedge clkb) begin
      case (cptb)
         4: begin
            if (dob !== 32'hCAFEDECA) begin
               errors = errors + 1;
               $display("Error: cptb(%0d) dob(32'h%08h) ref(32'hCAFEDECA)", cptb, dob);
            end
         end
      endcase
   end

endmodule
