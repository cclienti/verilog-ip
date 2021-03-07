// Copyright (C) 2020 Christophe Clienti - All Rights Reserved

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
   reg [WIDTH-1:0]  rdata_ref [127:0];
   reg [WIDTH-1:0]  rdata_check;
   integer          rdata_ref_ptr;

   // counter
   integer          cpt;

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
   // Value Change Dump
   //----------------------------------------------------------------
   initial begin
      $dumpfile ("sclkfiforeg_tb.vcd");
      $dumpvars;
   end

   //----------------------------------------------------------------
   // Checks
   //----------------------------------------------------------------
   always @(posedge clk) begin
      if (cpt > 2)
        if (rdata !== rdata_check) begin
           $display("%m: Error: bad 'rdata' at cpt=%3d", cpt-1);
           $display("  --> obtained 0x%08X instead of 0x%08X", rdata, rdata_check);
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
      #10000 $finish;
   end

   always @(*) begin
      if (wdata > 128) $finish;
   end

endmodule
