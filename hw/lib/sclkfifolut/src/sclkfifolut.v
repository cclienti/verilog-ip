//                              -*- Mode: Verilog -*-
// Filename        : sclkfifolut.v
// Description     : Single Clock Fifo based on LUT memory
// Author          : Christophe Clienti
// Created On      : Tue Jun 11 08:55:36 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Tue Jun 11 08:55:36 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module sclkfifolut
  #(parameter LOG2_FIFO_DEPTH = 5,
    parameter FIFO_WIDTH      = 32)

   (input wire                     clk,
    input wire                     srst,

    output reg [LOG2_FIFO_DEPTH:0] level,

    input wire                     ren,
    output reg [FIFO_WIDTH-1:0]    rdata,
    output reg                     rempty,

    input wire                     wen,
    input wire [FIFO_WIDTH-1:0]    wdata,
    output reg                     wfull);

   //----------------------------------------------------------------
   // Signals declaration
   //----------------------------------------------------------------
   reg [LOG2_FIFO_DEPTH-1:0] wptr, rptr;
   reg [LOG2_FIFO_DEPTH:0]   level_comb;
   reg                       rempty_comb, wfull_comb;

   reg [FIFO_WIDTH-1:0]      ram[2**LOG2_FIFO_DEPTH-1:0];

   reg wen_protect, ren_protect;

   //----------------------------------------------------------------
   // Protect read and write signals
   //----------------------------------------------------------------

   always @(*) begin
      ren_protect = ren & ~rempty;
   end

   always @(*) begin
      wen_protect = wen & ~wfull;
   end


   //----------------------------------------------------------------
   // Infer internal memory
   //----------------------------------------------------------------
   always @(posedge clk) begin
      if(wen_protect == 1'b1) begin
         ram[wptr] <= wdata;
      end
   end

   always @(posedge clk) begin
      if(ren_protect  == 1'b1) begin
         rdata <= ram[rptr];
      end
   end

   //----------------------------------------------------------------
   // Manage pointers
   //----------------------------------------------------------------
   always @(posedge clk) begin
      if(srst == 1'b1) begin
         rptr <= 0;
      end
      else begin
         if(ren_protect == 1'b1) begin
            rptr <= rptr + 1;
         end
      end
   end

   always @(posedge clk) begin
      if(srst == 1'b1) begin
         wptr <= 0;
      end
      else begin
         if(wen_protect == 1'b1) begin
            wptr <= wptr + 1;
         end
      end
   end

   //----------------------------------------------------------------
   // Level detections
   //----------------------------------------------------------------
   always @(*) begin
      if((ren_protect == 1'b0) && (wen_protect == 1'b1)) begin
         level_comb = level + 1;
      end
      else if ((ren_protect == 1'b1) && (wen_protect == 1'b0)) begin
         level_comb = level - 1;
      end
      else begin
        level_comb = level;
      end
   end

   always @(posedge clk) begin
      if(srst == 1'b1) begin
         level <= 0;
      end
      else begin
         level <= level_comb;
      end
   end

   //----------------------------------------------------------------
   // full and empty detections
   //----------------------------------------------------------------
   always @(*) begin
      rempty_comb = (level_comb == 0) ? 1'b1: 1'b0;
      wfull_comb  = level_comb[LOG2_FIFO_DEPTH];
   end

   always @(posedge clk) begin
      if(srst == 1'b1) begin
         rempty <= 1'b1;
         wfull  <= 1'b0;
      end
      else begin
         rempty <= rempty_comb;
         wfull  <= wfull_comb;
      end
   end


endmodule
