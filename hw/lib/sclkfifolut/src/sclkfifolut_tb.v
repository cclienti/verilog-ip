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

module sclkfifolut_tb;

   //----------------------------------------------------------------
   //Constants
   //----------------------------------------------------------------
   localparam LOG2_FIFO_DEPTH = 3;
   localparam FIFO_WIDTH      = 32;

   //----------------------------------------------------------------
   //Signals
   //----------------------------------------------------------------
   //DUT signals
   reg                      clk;
   reg                      srst;
   wire [LOG2_FIFO_DEPTH:0] level;
   reg                      ren;
   wire [FIFO_WIDTH-1:0]    rdata;
   wire                     rempty;
   reg                      wen;
   reg [FIFO_WIDTH-1:0]     wdata;
   wire                     wfull;

   // ref signals
   reg [FIFO_WIDTH-1:0]     rdata_ref [127:0];
   reg [LOG2_FIFO_DEPTH:0]  level_ref [127:0];
   reg [FIFO_WIDTH-1:0]     rdata_check;
   reg [LOG2_FIFO_DEPTH:0]  level_check;
   integer                  level_ref_ptr, rdata_ref_ptr;

   // counter
   integer                  cpt;

   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------
   sclkfifolut
   #(
      .LOG2_FIFO_DEPTH (LOG2_FIFO_DEPTH),
      .FIFO_WIDTH      (FIFO_WIDTH)
   )
   sclkfifolut
   (
      .clk    (clk),
      .srst   (srst),
      .level  (level),
      .ren    (ren),
      .rdata  (rdata),
      .rempty (rempty),
      .wen    (wen),
      .wdata  (wdata),
      .wfull  (wfull)
   );

   //----------------------------------------------------------------
   // OUTPUT_REG=1 DUT (registered read output), same stimulus
   //----------------------------------------------------------------
   wire [FIFO_WIDTH-1:0]    rdata_reg;
   wire [LOG2_FIFO_DEPTH:0] level_reg;
   wire                     rempty_reg;
   wire                     wfull_reg;

   sclkfifolut
   #(
      .LOG2_FIFO_DEPTH (LOG2_FIFO_DEPTH),
      .FIFO_WIDTH      (FIFO_WIDTH),
      .OUTPUT_REG      (1)
   )
   sclkfifolut_reg
   (
      .clk    (clk),
      .srst   (srst),
      .level  (level_reg),
      .ren    (ren),
      .rdata  (rdata_reg),
      .rempty (rempty_reg),
      .wen    (wen),
      .wdata  (wdata),
      .wfull  (wfull_reg)
   );

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
   initial  begin
      $dumpfile ("sclkfifolut_tb.vcd");
      $dumpvars;
   end

   //----------------------------------------------------------------
   // Reference
   //----------------------------------------------------------------
   initial begin
      rdata_ref_ptr  = 0;

      rdata_ref[0]   = 32'h1;
      rdata_ref[1]   = 32'h2;
      rdata_ref[2]   = 32'h3;
      rdata_ref[3]   = 32'h4;
      rdata_ref[4]   = 32'h5;
      rdata_ref[5]   = 32'h6;
      rdata_ref[6]   = 32'h7;
      rdata_ref[7]   = 32'h8;
      rdata_ref[8]   = 32'h8;
      rdata_ref[9]   = 32'h19;
      rdata_ref[10]  = 32'h1E;
      rdata_ref[11]  = 32'h1F;
      rdata_ref[12]  = 32'h20;
      rdata_ref[13]  = 32'h21;
   end

   initial begin
      level_ref_ptr = 0;

      level_ref[0]   = 1;
      level_ref[1]   = 2;
      level_ref[2]   = 3;
      level_ref[3]   = 4;
      level_ref[4]   = 5;
      level_ref[5]   = 6;
      level_ref[6]   = 7;
      level_ref[7]   = 8;
      level_ref[8]   = 8;
      level_ref[9]   = 7;
      level_ref[10]  = 6;
      level_ref[11]  = 5;
      level_ref[12]  = 4;
      level_ref[13]  = 3;
      level_ref[14]  = 2;
      level_ref[15]  = 1;
      level_ref[16]  = 0;
      level_ref[17]  = 0;
      level_ref[18]  = 1;
      level_ref[19]  = 1;
      level_ref[20]  = 1;
      level_ref[21]  = 1;
      level_ref[22]  = 1;
   end

   always @(posedge clk) begin
      if((ren == 1'b1) || (wen == 1'b1)) begin
         level_ref_ptr <= level_ref_ptr + 1;
         level_check   <= level_ref[level_ref_ptr];
      end

      if(ren == 1'b1) begin
         rdata_ref_ptr <= rdata_ref_ptr + 1;
         rdata_check   <= rdata_ref[rdata_ref_ptr];
      end
   end

   //----------------------------------------------------------------
   // Checks
   //----------------------------------------------------------------
   always @(posedge clk) begin
      if (cpt > 2)
        if (level !== level_check) begin
           $display("Error: %m: bad 'level' at cpt=%3d", cpt-1);
           $display("  --> obtained 0x%08X instead of 0x%08X", level, level_check);
           $finish;
        end
        else begin
           $display("%m: cpt=%3d, level Ok", cpt-1);
        end
   end

   always @(posedge clk) begin
      // The golden rdata_ref sequence models registered-read semantics, so
      // it is checked against the OUTPUT_REG=1 instance. rdata_check is only
      // meaningful once the first read has issued.
      if ((cpt > 2) && (rdata_ref_ptr > 0))
        if (rdata_reg !== rdata_check) begin
           $display("%m: Error: bad 'rdata' at cpt=%3d", cpt-1);
           $display("  --> obtained 0x%08X instead of 0x%08X", rdata_reg, rdata_check);
           $finish;
        end
        else begin
           $display("%m: cpt=%3d, rdata Ok", cpt-1);
        end
   end


   //----------------------------------------------------------------
   // Test vectors
   //----------------------------------------------------------------
   always @(posedge clk) begin
     if(srst) begin
        cpt <= 0;
     end
     else begin
        cpt <= cpt + 1;
     end
   end

   always @(cpt) begin
      // Write the fifo
      if ((cpt >= 1) && (cpt<=8)) begin
         ren     <= 1'b0;
         wen     <= 1'b1;
         wdata   <= cpt;
      end
      // Try to overflow the fifo with one more write
      else if (cpt == 9) begin
         ren     <= 1'b0;
         wen     <= 1'b1;
         wdata   <= cpt;
      end
      // Dump the fifo
      else if ((cpt >= 12) && (cpt<=19)) begin
         ren       <= 1'b1;
         wen       <= 1'b0;
         wdata     <= 0;
      end
      //try to overflow the fifo with one more read
      else if (cpt == 20) begin
         ren       <= 1'b1;
         wen       <= 1'b0;
         wdata     <= 0;
      end
      // Write one word
      else if (cpt == 25) begin
         ren     <= 1'b0;
         wen     <= 1'b1;
         wdata   <= cpt;
      end
      // Write and read, the level should not change (level == 1)
      else if ((cpt >= 30) && (cpt<=33)) begin
         ren       <= 1'b1;
         wen       <= 1'b1;
         wdata     <= cpt;
      end
      else if (cpt>40) begin
         $finish;
      end
      else begin
	 ren   <= 1'b0;
         wen   <= 1'b0;
         wdata <= 0;
      end
   end



   //----------------------------------------------------------------
   // OUTPUT_REG=1 coverage checks
   //----------------------------------------------------------------
   // The OUTPUT_REG=1 instance (declared above) shares the same stimulus.
   // Because OUTPUT_REG only registers rdata: (a) level, rempty and wfull
   // must match the FWFT instance, and (b) its registered rdata must equal
   // the FWFT rdata captured on each protected read (ren & ~rempty). The
   // golden rdata_ref sequence (registered-read semantics) is checked
   // against this instance above.

   // Reference: FWFT rdata captured on each protected read.
   reg [FIFO_WIDTH-1:0] rdata_reg_check;
   reg                  rdata_reg_valid;

   always @(posedge clk) begin
      if(srst == 1'b1) begin
         rdata_reg_valid <= 1'b0;
      end
      else if((ren == 1'b1) && (rempty == 1'b0)) begin
         rdata_reg_check <= rdata;
         rdata_reg_valid <= 1'b1;
      end
   end

   // The registered instance must not perturb the flow-control flags.
   always @(posedge clk) begin
      if (cpt > 2)
        if ((level_reg !== level) || (rempty_reg !== rempty) || (wfull_reg !== wfull)) begin
           $display("%m: Error: OUTPUT_REG=1 flags differ at cpt=%3d", cpt-1);
           $display("  --> level %0d/%0d rempty %b/%b wfull %b/%b (reg/fwft)",
                    level_reg, level, rempty_reg, rempty, wfull_reg, wfull);
           $finish;
        end

   end

   // The registered read data must equal the FWFT data captured at read.
   always @(posedge clk) begin
      if ((cpt > 2) && (rdata_reg_valid == 1'b1))
        if (rdata_reg !== rdata_reg_check) begin
           $display("%m: Error: bad registered 'rdata' at cpt=%3d", cpt-1);
           $display("  --> obtained 0x%08X instead of 0x%08X", rdata_reg, rdata_reg_check);
           $finish;
        end
        else begin
           $display("%m: cpt=%3d, rdata_reg Ok", cpt-1);
        end
   end


endmodule
