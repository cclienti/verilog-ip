//                              -*- Mode: Verilog -*-
// Filename        : hynoc_router_5p_tb2.v
// Description     : Testbench of the five ports router
// Author          : Christophe Clienti
// Created On      : Mon Jul  1 13:24:35 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Mon Jul  1 13:24:35 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module hynoc_router_5p_tb2;


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

   reg                      port0_ingress_srst;
   reg                      port0_ingress_clk;
   reg                      port0_ingress_write;
   reg [FLIT_WIDTH-1:0]     port0_ingress_data;
   wire                     port0_ingress_full;
   wire [LOG2_FIFO_DEPTH:0] port0_ingress_fifo_level;
   wire                     port0_egress_srst;
   wire                     port0_egress_clk;
   wire                     port0_egress_write;
   wire [FLIT_WIDTH-1:0]    port0_egress_data;
   reg [LOG2_FIFO_DEPTH:0]  port0_egress_fifo_level;

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

   reg                      port4_ingress_srst;
   reg                      port4_ingress_clk;
   reg                      port4_ingress_write;
   reg [FLIT_WIDTH-1:0]     port4_ingress_data;
   wire                     port4_ingress_full;
   wire [LOG2_FIFO_DEPTH:0] port4_ingress_fifo_level;
   wire                     port4_egress_srst;
   wire                     port4_egress_clk;
   wire                     port4_egress_write;
   wire [FLIT_WIDTH-1:0]    port4_egress_data;
   reg [LOG2_FIFO_DEPTH:0]  port4_egress_fifo_level;

   reg                      arst;

   integer                  p3_cpt;
   integer                  p4_cpt;
   integer                  p0_cpt;


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
   // Clock and Reset Generation
   //----------------------------------------------------------------

   initial begin
      router_clk         = 0;
      port3_ingress_clk  = 0;
      port4_ingress_clk  = 0;
      port0_ingress_clk  = 0;
      arst               = 1;
      #10.2 arst         = 1;
      #13.4 arst         = 0;
   end

   always
     #2 router_clk = !router_clk;

   always
     #3 port3_ingress_clk = !port3_ingress_clk;

   always
     #3 port4_ingress_clk = !port4_ingress_clk;

   always
     #3 port0_ingress_clk = !port0_ingress_clk;

   always @(posedge router_clk) begin
      router_srst <= arst;
   end

   always @(posedge port3_ingress_clk) begin
      port3_ingress_srst <= arst;
   end

   always @(posedge port4_ingress_clk) begin
      port4_ingress_srst <= arst;
   end

   always @(posedge port0_ingress_clk) begin
      port0_ingress_srst <= arst;
   end


   //----------------------------------------------------------------
   // Value Change Dump
   //----------------------------------------------------------------

   initial begin
      $dumpfile ("hynoc_router_5p_tb2.vcd");
      $dumpvars;
   end


   //----------------------------------------------------------------
   // Topology
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
   // Tests <--->| P4   P0     |
   //            '-------------'
   //                   ↑
   //                   |
   //                   ↓
   //                 Tests


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



   //----------------------------------------------------------------
   // Test Vectors
   //----------------------------------------------------------------

   initial
     #2000 $finish;

   always @(posedge port3_ingress_clk) begin
     if(port3_ingress_srst) begin
        p3_cpt <= 0;
     end
     else begin
        p3_cpt <= p3_cpt + 1;
     end
   end

   always @(posedge port4_ingress_clk) begin
     if(port4_ingress_srst) begin
        p4_cpt <= 0;
     end
     else begin
        p4_cpt <= p4_cpt + 1;
     end
   end

   always @(posedge port0_ingress_clk) begin
     if(port0_ingress_srst) begin
        p0_cpt <= 0;
     end
     else begin
        p0_cpt <= p0_cpt + 1;
     end
   end

   initial begin
      port3_egress_fifo_level = 0;
      port4_egress_fifo_level = 0;
      port0_egress_fifo_level = 0;
   end

   // write to port3 input the fifo
   always @(p3_cpt) begin
      // ------ TEST 1: 1 Header Flit (HF) and 1 Payload Close Flit (PCF) ---------
      // Path: P3.in/P1.out ## P2.in/P0.out
      if(p3_cpt == 8) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b0, 1'b0, 31'b0_00_00_00_00_00_00_00_00_00_00_00_10_10_0001};
      end
      else if(p3_cpt == 9) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b1, 32'hCAFE_0003};
      end

      // ------ TEST 2: 1 Header Flit (HF) and 1 Payload Close Flit (PCF) ---------
      // Path: P3.in/P1.out ## P2.in/P0.out
      else if(p3_cpt == 10) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b0, 1'b0, 31'b0_00_00_00_00_00_00_00_00_00_00_00_10_10_0001};
      end
      else if(p3_cpt == 11) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b1, 32'hCAFE_0030};
      end

      // ------ TEST 3: 1 HF, more than 32 PF, multiple PCF ---------
      // Path: P3.in/P1.out ## P2.in/P3.out
      else if(p3_cpt == 12) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b0, 1'b0, 31'b0_00_00_00_00_00_00_00_00_00_00_00_10_10_0001};
      end
      else if(p3_cpt == 13) begin
         port3_ingress_write = 1'b1;
         port3_ingress_data  = {1'b0, 32'h0000_0000};
      end
      else if((p3_cpt >= 14) && (p3_cpt < 34)) begin
         port3_ingress_write = (port3_ingress_fifo_level<(2**LOG2_FIFO_DEPTH-2));
         port3_ingress_data  = {1'b0, 32'h3000_0000 | p3_cpt};
      end
      else if((p3_cpt >= 34) && (p3_cpt < 38)) begin
         port3_ingress_write = (port3_ingress_fifo_level<(2**LOG2_FIFO_DEPTH-2));
         port3_ingress_data  = {1'b1, 32'h3000_0000};
      end

      else begin
         port3_ingress_write = 1'b0;
         port3_ingress_data  = {1'b0, 32'h0000_0000};
      end
   end

   // write to port4 input the fifo
   always @(p4_cpt) begin
      // ------ TEST 1: 1 Header Flit (HF) and 1 Payload Close Flit (PCF) ---------
      // Path: P4.in/P1.out ## P2.in/P0.out
      if(p4_cpt == 8) begin
         port4_ingress_write = 1'b1;
         port4_ingress_data  = {1'b0, 1'b0, 31'b0_00_00_00_00_00_00_00_00_00_00_00_01_10_0001};
      end
      else if(p4_cpt == 9) begin
         port4_ingress_write = 1'b1;
         port4_ingress_data  = {1'b1, 32'hCAFE_0004};
      end

      // ------ TEST 2: 1 Header Flit (HF) and 1 Payload Close Flit (PCF) ---------
      // Path: P4.in/P1.out ## P2.in/P0.out
      else if(p4_cpt == 10) begin
         port4_ingress_write = 1'b1;
         port4_ingress_data  = {1'b0, 1'b0, 31'b0_00_00_00_00_00_00_00_00_00_00_00_01_10_0001};
      end
      else if(p4_cpt == 11) begin
         port4_ingress_write = 1'b1;
         port4_ingress_data  = {1'b1, 32'hCAFE_0040};
      end

      // ------ TEST 3: 1 HF, more than 32 PF, multiple PCF --------
      // Path: P4.in/P1.out ## P2.in/P0.out
      else if(p4_cpt == 12) begin
         port4_ingress_write = 1'b1;
         port4_ingress_data  = {1'b0, 1'b0, 31'b0_00_00_00_00_00_00_00_00_00_00_00_01_10_0001};
      end
      else if(p4_cpt == 13) begin
         port4_ingress_write = 1'b1;
         port4_ingress_data  = {1'b0, 32'h0000_0000};
      end
      else if((p4_cpt >= 14) && (p4_cpt < 35)) begin
         port4_ingress_write = (port4_ingress_fifo_level<(2**LOG2_FIFO_DEPTH-2));
         port4_ingress_data  = {1'b0, 32'h4000_0000 | p4_cpt};
      end
      else if((p4_cpt >= 35) && (p4_cpt < 55)) begin
         port4_ingress_write = (port4_ingress_fifo_level<(2**LOG2_FIFO_DEPTH-2));
         port4_ingress_data  = {1'b1, 32'h4000_0000};
      end

      else begin
         port4_ingress_write = 1'b0;
         port4_ingress_data  = {1'b0, 32'h0000_0000};
      end
   end

   // write to port0 input the fifo
   always @(p0_cpt) begin
      // ------ TEST 1: 1 Header Flit (HF) and 1 Payload Close Flit (PCF) ---------
      // Path: P0.in/P1.out ## P2.in/P0.out
      if(p0_cpt == 8) begin
         port0_ingress_write = 1'b1;
         port0_ingress_data  = {1'b0, 1'b0, 31'b0_00_00_00_00_00_00_00_00_00_00_00_00_10_0001};
      end
      else if(p0_cpt == 9) begin
         port0_ingress_write = 1'b1;
         port0_ingress_data  = {1'b1, 32'hCAFE_0000};
      end

      // ------ TEST 2: 1 HF, more than 32 PF, multiple PCF --------
      // Path: P0.in/P2.out ## P1.in/P0.out In this test, the packet
      // go through another path than the previous one, so the port 0
      // arbitration is right
      else if(p0_cpt == 10) begin
         port0_ingress_write = 1'b1;
         port0_ingress_data  = {1'b0, 1'b0, 31'b0_00_00_00_00_00_00_00_00_00_00_00_01_11_0001};
      end
      else if(p0_cpt == 11) begin
         port0_ingress_write = 1'b1;
         port0_ingress_data  = {1'b0, 32'h0000_0000};
      end
      else if((p0_cpt >= 12) && (p0_cpt < 120)) begin
         port0_ingress_write = (port0_ingress_fifo_level<(2**LOG2_FIFO_DEPTH-2));
         port0_ingress_data  = {1'b0, p0_cpt};
      end
      else if((p0_cpt >= 120) && (p0_cpt < 130)) begin
         port0_ingress_write = (port0_ingress_fifo_level<(2**LOG2_FIFO_DEPTH-2));
         port0_ingress_data  = {1'b1, 32'h0000_0000};
      end

      else begin
         port0_ingress_write = 1'b0;
         port0_ingress_data  = {1'b0, 32'h0000_0000};
      end
   end


endmodule
