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

module prra_tb();

   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------

   localparam WIDTH      = 4;
   localparam LOG2_WIDTH = 2;
   localparam PIPELINE   = 0;

   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------

   reg                   clk;
   reg                   srst;
   reg [WIDTH-1:0]       request;
   wire [LOG2_WIDTH-1:0] state;
   wire [WIDTH-1:0]      grant;

   reg [WIDTH-1:0]       grant_ref;
   reg [WIDTH-1:0]       grant_ref_reg [PIPELINE:0];
   wire [WIDTH-1:0]      grant_check;

   integer               cpt;


   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------

   prra
   #(
      .WIDTH      (WIDTH),
      .LOG2_WIDTH (LOG2_WIDTH),
      .PIPELINE   (PIPELINE)
   )
   prra
   (
      .clk     (clk),
      .srst    (srst),
      .request (request),
      .state   (state),
      .grant   (grant)
   );


   //----------------------------------------------------------------
   // Clock and reset generation
   //----------------------------------------------------------------

   initial begin
      clk       = 0;
      srst      = 1;
      #10 srst  = 1;
      #20 srst  = 0;
   end

   always
     #2 clk = !clk;


   //----------------------------------------------------------------
   // Value Change Dump
   //----------------------------------------------------------------

   initial begin
      $dumpfile ("prra_tb.vcd");
      $dumpvars;
   end


   //----------------------------------------------------------------
   // Some useful information
   //----------------------------------------------------------------

   integer i,j;

   initial begin
      $display("LUT 0:");
      for(j=0 ; j<2**WIDTH ; j=j+1) begin
         $display("\t %b -> %d", j[3:0], prra.lut_gen[0].prra_lut_inst.lut[j]);
      end
      $display("LUT 1:");
      for(j=0 ; j<2**WIDTH ; j=j+1) begin
         $display("\t %b -> %d", j[3:0], prra.lut_gen[1].prra_lut_inst.lut[j]);
      end
      $display("LUT 2:");
      for(j=0 ; j<2**WIDTH ; j=j+1) begin
         $display("\t %b -> %d", j[3:0], prra.lut_gen[2].prra_lut_inst.lut[j]);
      end
      $display("LUT 3:");
      for(j=0 ; j<2**WIDTH ; j=j+1) begin
         $display("\t %b -> %d", j[3:0], prra.lut_gen[3].prra_lut_inst.lut[j]);
      end
   end


   //----------------------------------------------------------------
   // Checks
   //----------------------------------------------------------------

   integer regidx;

   always @(posedge clk) begin
      if(srst == 1'b1) begin
         for(regidx=0 ; regidx<=PIPELINE ; regidx=regidx+1) begin
            grant_ref_reg[regidx] <= 0;
         end
      end
      else begin
         grant_ref_reg[0] <= grant_ref;
         for(regidx=1 ; regidx<=PIPELINE ; regidx=regidx+1) begin
            grant_ref_reg[regidx] <= grant_ref_reg[regidx-1];
         end
      end
   end

   assign grant_check = grant_ref_reg[PIPELINE];

   always @(negedge clk) begin
      if (grant_check !== grant) begin
         $display("Error: %m: bad GRANT signal at cpt=%3d", cpt-1);
         $display("  --> obtained 0x%04X instead of 0x%04X", grant, grant_check);
         //$finish;
      end
   end

   //----------------------------------------------------------------
   // Test vectors
   //----------------------------------------------------------------

   initial
     #400 $finish;

   always @(posedge clk) begin
     if(srst == 1'b1) begin
        cpt <= 0;
     end
     else begin
        cpt <= cpt + 1;
     end
   end

   always @(cpt) begin
      case(cpt)
         0: begin
            request = 4'b0000;
            grant_ref  = 4'b0000;
         end
         8 : begin
            request    = 4'b0100; // granted: 4'b0001
            grant_ref  = 4'b0100;
         end
         10 : begin
            request    = 4'b0110; // granted: 4'b0001
            grant_ref  = 4'b0100;
         end
         14 : begin
            request    = 4'b0010; // granted: 4'b0010
            grant_ref  = 4'b0010;
         end
         16 : begin
            request    = 4'b0111; // granted: 4'b0010
            grant_ref  = 4'b0010;
         end
         18 : begin
            request    = 4'b0101; // granted: 4'b0100
            grant_ref  = 4'b0100;
         end
         22 : begin
            request    = 4'b1001; // granted: 4'b1000
            grant_ref  = 4'b1000;
         end
         26 : begin
            request    = 4'b0110; // granted: 4'b0010
            grant_ref  = 4'b0010;
         end
         32: begin
            request    = 4'b0000; // granted: 4'b0000
            grant_ref  = 4'b0000;
         end
         36: begin
            request    = 4'b1111; // granted: 4'b0100
            grant_ref  = 4'b0100;
         end
         38: begin
            request    = 4'b1011;
            grant_ref  = 4'b1000;
         end
         42: begin
            request    = 4'b0011;
            grant_ref  = 4'b0001;
         end
         44: begin
            request    = 4'b0010;
            grant_ref  = 4'b0010;
         end
         48: begin
            request    = 4'b0000;
            grant_ref  = 4'b0000;
         end
         49: begin
            request    = 4'b1110;
            grant_ref  = 4'b0100;
         end
         52: begin
            request    = 4'b1010;
            grant_ref  = 4'b1000;
         end
         56: begin
            request    = 4'b0010;
            grant_ref  = 4'b0010;
         end
      endcase
   end


endmodule
