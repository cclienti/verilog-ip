//                              -*- Mode: Verilog -*-
// Filename        : hynoc_router_5p_tb.v
// Description     : Testbench of the five ports router
// Author          : Christophe Clienti
// Created On      : Mon Jul  1 13:24:35 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Mon Jul  1 13:24:35 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module hynoc_router_5p_tb;



   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------

   localparam integer INDEX_WIDTH          = 4;
   localparam integer LOG2_FIFO_DEPTH      = 5;
   localparam integer PAYLOAD_WIDTH        = 32;
   localparam integer FLIT_WIDTH           = (PAYLOAD_WIDTH+1);
   localparam integer PRRA_PIPELINE        = 0;
   localparam integer SINGLE_CLOCK_ROUTER  = 0;
   localparam integer ENABLE_MCAST_ROUTING = 1;
   localparam integer ENABLE_XY_ROUTING    = 1;


   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------

   reg                      router_clk;
   reg                      router_srst;

   wire                     port0_ingress_srst;
   wire                     port0_ingress_clk;
   wire                     port0_ingress_write;
   wire [FLIT_WIDTH-1:0]    port0_ingress_data;
   wire                     port0_ingress_full;
   wire [LOG2_FIFO_DEPTH:0] port0_ingress_fifo_level;
   wire                     port0_egress_srst;
   wire                     port0_egress_clk;
   wire                     port0_egress_write;
   wire [FLIT_WIDTH-1:0]    port0_egress_data;
   wire [LOG2_FIFO_DEPTH:0] port0_egress_fifo_level;

   wire                     port1_ingress_srst;
   wire                     port1_ingress_clk;
   wire                     port1_ingress_write;
   wire [FLIT_WIDTH-1:0]    port1_ingress_data;
   wire                     port1_ingress_full;
   wire [LOG2_FIFO_DEPTH:0] port1_ingress_fifo_level;
   wire                     port1_egress_srst;
   wire                     port1_egress_clk;
   wire                     port1_egress_write;
   wire [FLIT_WIDTH-1:0]    port1_egress_data;
   wire [LOG2_FIFO_DEPTH:0] port1_egress_fifo_level;

   wire                     port2_ingress_srst;
   wire                     port2_ingress_clk;
   wire                     port2_ingress_write;
   wire [FLIT_WIDTH-1:0]    port2_ingress_data;
   wire                     port2_ingress_full;
   wire [LOG2_FIFO_DEPTH:0] port2_ingress_fifo_level;
   wire                     port2_egress_srst;
   wire                     port2_egress_clk;
   wire                     port2_egress_write;
   wire [FLIT_WIDTH-1:0]    port2_egress_data;
   wire [LOG2_FIFO_DEPTH:0] port2_egress_fifo_level;

   reg                      port3_ingress_srst;
   reg                      port3_ingress_clk;
   reg                      port3_ingress_write;
   reg [FLIT_WIDTH-1:0]     port3_ingress_data;
   wire                     port3_ingress_full;
   wire [LOG2_FIFO_DEPTH:0] port3_ingress_fifo_level;
   wire                     port3_egress_srst;
   wire                     port3_egress_clk;
   wire                     port3_egress_write;
   wire [FLIT_WIDTH-1:0]    port3_egress_data;
   reg [LOG2_FIFO_DEPTH:0]  port3_egress_fifo_level;

   wire                     port4_ingress_srst;
   wire                     port4_ingress_clk;
   wire                     port4_ingress_write;
   wire [FLIT_WIDTH-1:0]    port4_ingress_data;
   wire                     port4_ingress_full;
   wire [LOG2_FIFO_DEPTH:0] port4_ingress_fifo_level;
   wire                     port4_egress_srst;
   wire                     port4_egress_clk;
   wire                     port4_egress_write;
   wire [FLIT_WIDTH-1:0]    port4_egress_data;
   wire [LOG2_FIFO_DEPTH:0] port4_egress_fifo_level;

   reg                      arst;
   integer                  cpt;


   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------

   hynoc_router_5p
   #(
      .INDEX_WIDTH          (INDEX_WIDTH),
      .LOG2_FIFO_DEPTH      (LOG2_FIFO_DEPTH),
      .PAYLOAD_WIDTH        (PAYLOAD_WIDTH),
      .FLIT_WIDTH           (FLIT_WIDTH),
      .PRRA_PIPELINE        (PRRA_PIPELINE),
      .SINGLE_CLOCK_ROUTER  (SINGLE_CLOCK_ROUTER),
      .ENABLE_MCAST_ROUTING (ENABLE_MCAST_ROUTING),
      .ENABLE_XY_ROUTING    (ENABLE_XY_ROUTING)
   )
   hynoc_router_5p_inst
   (
      .router_clk               (router_clk),
      .router_srst              (router_srst),
      .port0_ingress_srst       (port0_ingress_srst),
      .port0_ingress_clk        (port0_ingress_clk),
      .port0_ingress_write      (port0_ingress_write),
      .port0_ingress_data       (port0_ingress_data),
      .port0_ingress_full       (port0_ingress_full),
      .port0_ingress_fifo_level (port0_ingress_fifo_level),
      .port0_egress_srst        (port0_egress_srst),
      .port0_egress_clk         (port0_egress_clk),
      .port0_egress_write       (port0_egress_write),
      .port0_egress_data        (port0_egress_data),
      .port0_egress_fifo_level  (port0_egress_fifo_level),
      .port1_ingress_srst       (port1_ingress_srst),
      .port1_ingress_clk        (port1_ingress_clk),
      .port1_ingress_write      (port1_ingress_write),
      .port1_ingress_data       (port1_ingress_data),
      .port1_ingress_full       (port1_ingress_full),
      .port1_ingress_fifo_level (port1_ingress_fifo_level),
      .port1_egress_srst        (port1_egress_srst),
      .port1_egress_clk         (port1_egress_clk),
      .port1_egress_write       (port1_egress_write),
      .port1_egress_data        (port1_egress_data),
      .port1_egress_fifo_level  (port1_egress_fifo_level),
      .port2_ingress_srst       (port2_ingress_srst),
      .port2_ingress_clk        (port2_ingress_clk),
      .port2_ingress_write      (port2_ingress_write),
      .port2_ingress_data       (port2_ingress_data),
      .port2_ingress_full       (port2_ingress_full),
      .port2_ingress_fifo_level (port2_ingress_fifo_level),
      .port2_egress_srst        (port2_egress_srst),
      .port2_egress_clk         (port2_egress_clk),
      .port2_egress_write       (port2_egress_write),
      .port2_egress_data        (port2_egress_data),
      .port2_egress_fifo_level  (port2_egress_fifo_level),
      .port3_ingress_srst       (port3_ingress_srst),
      .port3_ingress_clk        (port3_ingress_clk),
      .port3_ingress_write      (port3_ingress_write),
      .port3_ingress_data       (port3_ingress_data),
      .port3_ingress_full       (port3_ingress_full),
      .port3_ingress_fifo_level (port3_ingress_fifo_level),
      .port3_egress_srst        (port3_egress_srst),
      .port3_egress_clk         (port3_egress_clk),
      .port3_egress_write       (port3_egress_write),
      .port3_egress_data        (port3_egress_data),
      .port3_egress_fifo_level  (port3_egress_fifo_level),
      .port4_ingress_srst       (port4_ingress_srst),
      .port4_ingress_clk        (port4_ingress_clk),
      .port4_ingress_write      (port4_ingress_write),
      .port4_ingress_data       (port4_ingress_data),
      .port4_ingress_full       (port4_ingress_full),
      .port4_ingress_fifo_level (port4_ingress_fifo_level),
      .port4_egress_srst        (port4_egress_srst),
      .port4_egress_clk         (port4_egress_clk),
      .port4_egress_write       (port4_egress_write),
      .port4_egress_data        (port4_egress_data),
      .port4_egress_fifo_level  (port4_egress_fifo_level)
   );

   //----------------------------------------------------------------
   // Clock and reset generation
   //----------------------------------------------------------------

   initial begin
      router_clk         = 0;
      port3_ingress_clk  = 0;
      arst               = 1;
      #10.2 arst         = 1;
      #13.4 arst         = 0;
   end

   always
     #4 router_clk = !router_clk;

   always
     #3 port3_ingress_clk = !port3_ingress_clk;

   always @(posedge router_clk) begin
      router_srst <= arst;
   end

   always @(posedge port3_ingress_clk) begin
      port3_ingress_srst <= arst;
   end


   //----------------------------------------------------------------
   // Value Change Dump
   //----------------------------------------------------------------

   initial begin
      $dumpfile ("hynoc_router_5p_tb.vcd");
      $dumpvars;
   end

   //----------------------------------------------------------------
   // Network topology
   //----------------------------------------------------------------

   // The router is wired as follow:
   //
   //                   .-------------.
   //                   |             |
   //                   ↓             |
   //            .-------------.      |
   //            |      P2     |      |
   //            |             |      |
   // Tests <--->| P3       P1 |<-----'
   //            |             |
   //     .----->| P4   P0     |
   //     |      '-------------'
   //     |             ↑
   //     |             |
   //     '-------------'
   //


   assign port1_ingress_srst      = port2_egress_srst;
   assign port1_ingress_clk       = port2_egress_clk;
   assign port1_ingress_write     = port2_egress_write;
   assign port1_ingress_data      = port2_egress_data;
   assign port2_egress_fifo_level = port1_ingress_fifo_level;

   assign port2_ingress_srst      = port1_egress_srst;
   assign port2_ingress_clk       = port1_egress_clk;
   assign port2_ingress_write     = port1_egress_write;
   assign port2_ingress_data      = port1_egress_data;
   assign port1_egress_fifo_level = port2_ingress_fifo_level;

   assign port0_ingress_srst      = port4_egress_srst;
   assign port0_ingress_clk       = port4_egress_clk;
   assign port0_ingress_write     = port4_egress_write;
   assign port0_ingress_data      = port4_egress_data;
   assign port4_egress_fifo_level = port0_ingress_fifo_level;

   assign port4_ingress_srst      = port0_egress_srst;
   assign port4_ingress_clk       = port0_egress_clk;
   assign port4_ingress_write     = port0_egress_write;
   assign port4_ingress_data      = port0_egress_data;
   assign port0_egress_fifo_level = port4_ingress_fifo_level;


   //----------------------------------------------------------------
   // Test vectors
   //----------------------------------------------------------------

   initial
     #8000 $finish;

   always @(posedge port3_ingress_clk) begin
     if(port3_ingress_srst) begin
        cpt <= 0;
     end
     else begin
        cpt <= cpt + 1;
     end
   end

   initial begin
      port3_egress_fifo_level = 0;
   end

   // write to port3 input the fifo
   always @(cpt) begin
      // ------ TEST 1: 1 Header Flit (HF) and 1 Payload Close Flit (PCF) ---------
      // Path: P1.out/P2.in ## P0.out/P4.in ## P3.out
      if(cpt == 8) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b0, 1'b0, 31'b0_00_00_00_00_00_00_00_00_00_00_10_10_11_0010};
      end
      else if(cpt == 9) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b1, 32'hCAFE_DECA};
      end

      // ------ TEST 2: 3 HF, 2 PF, 1 CF (Close Flit)
      // Path: P1.out/P2.in ## P0.out/P4.in ## P3.out
      else if(cpt == 10) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b0, 1'b0, 31'b0_00_00_00_00_00_00_00_00_00_00_00_00_10_0000};
      end
      else if(cpt == 11) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b0, 1'b0, 31'b0_00_00_00_00_00_00_00_00_00_00_00_00_10_0000};
      end
      else if(cpt == 12) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b0, 1'b0, 31'b0_00_00_00_00_00_00_00_00_00_00_00_00_11_0000};
      end
      else if(cpt == 13) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b0, 32'h0123_4567};
      end
      else if(cpt == 14) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b0, 32'h89ab_cdef};
      end
      else if(cpt == 15) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b1, 32'h0000_0000};
      end

      // ------ TEST 3: 1 HF, 2 PF, 1 PCF, keep channel openned ---------
      // Path: P1.out/P2.in ## P0.out/P4.in ## P3.out
      else if(cpt == 16) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b0, 1'b0, 31'b0_00_00_00_00_00_00_00_00_00_00_10_10_11_0010};
      end
      else if(cpt == 40) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b0, 32'h1122_3344};
      end
      else if(cpt == 60) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b0, 32'h5566_7788};
      end
      else if(cpt == 80) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b0, 32'h99aa_bbcc};
      end
      else if((cpt > 100) && (cpt < 1000)) begin
         port3_ingress_write = (port3_ingress_fifo_level<(2**LOG2_FIFO_DEPTH-2));
         port3_ingress_data  = {1'b0, cpt};
      end
      else if(cpt == 1032) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b1, 32'h0000_0000};
      end

      else begin
         port3_ingress_write = 1'b0;
         port3_ingress_data  = {1'b0, 32'h0000_0000};
      end
   end

endmodule
