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

module sclkfiforeg_tb;

   //----------------------------------------------------------------
   //Constants
   //----------------------------------------------------------------
   localparam WIDTH = 32;

   //----------------------------------------------------------------
   //Signals
   //----------------------------------------------------------------
   //DUT signals
   reg              clk;
   reg              srst;
   reg              ren;
   wire [WIDTH-1:0] rdata;
   wire             rempty;
   reg              wen;
   reg [WIDTH-1:0]  wdata;
   wire             wfull;

   // ref signals
   reg [WIDTH-1:0]  rdata_check;
   reg              rdata_check_valid = 0;
   reg              level_ref = 0;

   // counter
   integer          cpt = 0;
   integer          errors = 0;

   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------
   sclkfiforeg #(.WIDTH  (WIDTH))
   sclkfiforeg (.clk    (clk),
                .srst   (srst),
                .ren    (ren),
                .rdata  (rdata),
                .rempty (rempty),
                .wen    (wen),
                .wdata  (wdata),
                .wfull  (wfull));

   //----------------------------------------------------------------
   // Clock and Reset Generation
   //----------------------------------------------------------------
   initial begin
      clk       = 0;
      srst      = 1;
      #10 srst  = 1;
      #10 srst  = 0;
   end

   always
     #2 clk = !clk;

   //----------------------------------------------------------------
   // Checks
   //----------------------------------------------------------------
   // Reference model, written from the interface contract rather than
   // from the tables in the DUT: a one-deep fifo is a level bit -- a
   // lone write raises it, a lone read clears it, write and read
   // together leave it unchanged, including both strobes hitting an
   // empty fifo, which cancel out. The datapath contract is that rdata
   // mirrors the written word one cycle after wen.
   always @(posedge clk) begin
      cpt <= cpt + 1;
      rdata_check       <= wdata;
      rdata_check_valid <= wen && !srst;
      if (srst) begin
         level_ref <= 0;
      end
      else begin
         if (wen && !ren)      level_ref <= 1;
         else if (ren && !wen) level_ref <= 0;
      end
   end

   always @(posedge clk) begin
      if (!srst && cpt > 2) begin
         if (wfull !== level_ref || rempty !== ~level_ref) begin
            errors = errors + 1;
            $display("%m: Error: flags at cpt=%3d: wfull %b (ref %b) rempty %b (ref %b)",
                     cpt, wfull, level_ref, rempty, ~level_ref);
            $display("sclkfiforeg_tb: %0d ERROR(S)", errors);
            $finish;
         end
      end
   end

   always @(posedge clk) begin
      if (rdata_check_valid)
        if (rdata !== rdata_check) begin
           $display("%m: Error: bad 'rdata' at cpt=%3d", cpt-1);
           $display("  --> obtained 0x%08X instead of 0x%08X", rdata, rdata_check);
           errors = errors + 1;
           $display("sclkfiforeg_tb: %0d ERROR(S)", errors);
           $finish;
        end
        else begin
           $display("%m: cpt=%3d, rdata Ok", cpt-1);
        end
   end

   //----------------------------------------------------------------
   // Writer
   //----------------------------------------------------------------

   always @(posedge clk) begin
     if(srst) begin
        wdata <= 0;
        wen <= 0;
     end
     else begin
        if (!wfull) begin
           wdata <= wdata + 1;
           wen <= 1;
        end
     end
   end

   always @(posedge clk) begin
     if(srst) begin
        ren <= 0;
     end
     else begin
        if (!rempty) begin
           ren <= 1;
        end
        else begin
           ren <= 0;
        end
     end
   end

   initial begin
      #10000;
      if (errors == 0)
        $display("sclkfiforeg_tb: ALL TESTS PASSED");
      else
        $display("sclkfiforeg_tb: %0d ERROR(S)", errors);
      $finish;
   end

   always @(*) begin
      if (wdata > 128) begin
         if (errors == 0)
           $display("sclkfiforeg_tb: ALL TESTS PASSED");
         else
           $display("sclkfiforeg_tb: %0d ERROR(S)", errors);
         $finish;
      end
   end

endmodule
