//                              -*- Mode: Verilog -*-
// Filename        : dclkfifolut.v
// Description     : Dual Clock Fifo based on LUT memory
// Author          : Christophe Clienti
// Created On      : Wed Jun 12 22:26:09 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Wed Jun 12 22:26:09 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

// Implemented using: Simulation and Synthesis Techniques for
// Asynchronous FIFO Design, Clifford E. Cummings, SNUG 2002

module dclkfifolut
  #(parameter LOG2_FIFO_DEPTH = 3,
    parameter FIFO_WIDTH      = 8)

   (input wire                     rsrst,
    input wire                     rclk,
    input wire                     ren,
    output reg [FIFO_WIDTH-1:0]    rdata,
    output reg [LOG2_FIFO_DEPTH:0] rlevel,
    output reg                     rempty,

    input wire                     wsrst,
    input wire                     wclk,
    input wire                     wen,
    input wire [FIFO_WIDTH-1:0]    wdata,
    output reg [LOG2_FIFO_DEPTH:0] wlevel,
    output reg                     wfull);


   //----------------------------------------------------------------
   // Signals declaration
   //----------------------------------------------------------------
   wire [LOG2_FIFO_DEPTH:0] wptrbin_comb, rptrbin_comb;
   wire [LOG2_FIFO_DEPTH:0] wptrgray_comb, rptrgray_comb;

   reg [LOG2_FIFO_DEPTH:0]  wptrbin, rptrbin;
   reg [LOG2_FIFO_DEPTH:0]  wptrgray, rptrgray;

   reg [LOG2_FIFO_DEPTH:0]  wptrgray_to_r1;
   reg [LOG2_FIFO_DEPTH:0]  wptrgray_to_r2;
   wire [LOG2_FIFO_DEPTH:0]  wptrbin_in_r;

   reg [LOG2_FIFO_DEPTH:0]  rptrgray_to_w1;
   reg [LOG2_FIFO_DEPTH:0]  rptrgray_to_w2;
   wire [LOG2_FIFO_DEPTH:0]  rptrbin_in_w;

   // (* ramstyle = "logic" *) /* Altera */
   (* ram_style = "distributed" *) /* Xilinx */
   reg [FIFO_WIDTH-1:0]     ram[2**LOG2_FIFO_DEPTH-1:0];

   wire                     rempty_comb, wfull_comb;
   wire                     raempty_comb, wafull_comb;
   reg                      wen_protect, ren_protect;


   //----------------------------------------------------------------
   // Protect read and write signals
   //----------------------------------------------------------------

   // read domain
   always @(*) begin
      ren_protect = ren & ~rempty;
   end

   // write domain
   always @(*) begin
      wen_protect = wen & ~wfull;
   end


   //----------------------------------------------------------------
   // Infer internal memory
   //----------------------------------------------------------------

   // write domain
   always @(posedge wclk) begin
      if(wen_protect == 1'b1) begin
         ram[wptrbin[LOG2_FIFO_DEPTH-1:0]] <= wdata;
      end
   end

   // read domain
   always @(posedge rclk) begin
      if(ren_protect == 1'b1) begin
         rdata <= ram[rptrbin[LOG2_FIFO_DEPTH-1:0]];
      end
   end


   //----------------------------------------------------------------
   // Manage pointers
   //----------------------------------------------------------------

   // read domain
   assign rptrbin_comb = rptrbin + {{(LOG2_FIFO_DEPTH-1){1'b0}}, ren_protect};

   bin2gray
     #(.WIDTH(LOG2_FIFO_DEPTH+1))
   read_ptr_gray
     (.bin(rptrbin_comb), .gray(rptrgray_comb));


   always @(posedge rclk) begin
      if(rsrst == 1'b1) begin
         rptrbin  <= 0;
         rptrgray <= 0;
      end
      else begin
         rptrbin  <= rptrbin_comb;
         rptrgray <= rptrgray_comb;
      end
   end

   // write domain
   assign wptrbin_comb = wptrbin + {{(LOG2_FIFO_DEPTH-1){1'b0}}, wen_protect};

   bin2gray
     #(.WIDTH (LOG2_FIFO_DEPTH+1))
   write_ptr_gray
     (.bin(wptrbin_comb), .gray(wptrgray_comb));


   always @(posedge wclk) begin
      if(wsrst == 1'b1) begin
         wptrbin  <= 0;
         wptrgray <= 0;
      end
      else begin
         wptrbin  <= wptrbin_comb;
         wptrgray <= wptrgray_comb;
      end
   end


   //----------------------------------------------------------------
   // Write and read gray pointer synchronization
   //----------------------------------------------------------------

   // read domain
   always @(posedge rclk) begin
      if(rsrst == 1'b1) begin
         wptrgray_to_r1 <= 0;
         wptrgray_to_r2 <= 0;
      end
      else begin
         wptrgray_to_r1 <= wptrgray;
         wptrgray_to_r2 <= wptrgray_to_r1;
      end
   end

   // write domain
   always @(posedge wclk) begin
      if(wsrst == 1'b1) begin
         rptrgray_to_w1 <= 0;
         rptrgray_to_w2 <= 0;
      end
      else begin
         rptrgray_to_w1 <= rptrgray;
         rptrgray_to_w2 <= rptrgray_to_w1;
      end
   end


   //----------------------------------------------------------------
   // full and empty detections
   //----------------------------------------------------------------

   // read domain
   assign rempty_comb = (rptrgray_comb == wptrgray_to_r2);

   always @(posedge rclk) begin
      if(rsrst == 1'b1) begin
         rempty <= 1'b1;
      end
      else begin
         rempty <= rempty_comb;
      end
   end

   // write domain
   assign wfull_comb = (wptrgray_comb == {~rptrgray_to_w2[LOG2_FIFO_DEPTH:LOG2_FIFO_DEPTH-1],
                                          rptrgray_to_w2[LOG2_FIFO_DEPTH-2:0]});

   always @(posedge wclk) begin
      if(wsrst == 1'b1) begin
         wfull <= 1'b0;
      end
      else begin
         wfull <= wfull_comb;
      end
   end


   //----------------------------------------------------------------
   // Level detection
   //----------------------------------------------------------------

   // read domain
   gray2bin
     #(.WIDTH(LOG2_FIFO_DEPTH+1))
   write_ptr_bin
     (.gray (wptrgray_to_r2),
      .bin  (wptrbin_in_r));

   always @(posedge rclk) begin
      if(rsrst == 1'b1) begin
         rlevel <= 0;
      end
      else begin
         rlevel <= wptrbin_in_r - rptrbin_comb;
      end
   end

   // write domain
   gray2bin
     #(.WIDTH(LOG2_FIFO_DEPTH+1))
   read_ptr_bin
     (.gray (rptrgray_to_w2),
      .bin  (rptrbin_in_w));

   always @(posedge wclk) begin
      if(wsrst == 1'b1) begin
         wlevel <= 0;
      end
      else begin
         wlevel <= wptrbin_comb - rptrbin_in_w;
      end
   end

endmodule
