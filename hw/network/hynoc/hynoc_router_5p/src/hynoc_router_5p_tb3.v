//                              -*- Mode: Verilog -*-
// Filename        : hynoc_router_5p_tb3.v
// Description     : Testbench of the five ports router
// Author          : Christophe Clienti
// Created On      : Mon Jul  1 13:24:35 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Mon Jul  1 13:24:35 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module hynoc_router_5p_tb3;


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

   localparam integer NB_ADDRESS_FLITS    = 1;
   localparam integer FLIT_RANDOM_SEED    = 556;
   localparam integer NB_FLIT_RANDOM_SEED = 666;
   localparam integer NB_PACKETS          = 1000;
   localparam integer MAX_NB_FLITS        = 1024;
   localparam integer MAX_WAIT            = 2;

`include "hynoc_ingress_routing_list.v"

   localparam addr_flits_width = NB_ADDRESS_FLITS*FLIT_WIDTH;


   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------
   reg                        router_clk;
   reg                        router_srst;

   wire                       port0_ingress_srst;
   wire                       port0_ingress_clk;
   wire                       port0_ingress_write;
   wire [FLIT_WIDTH-1:0]      port0_ingress_data;
   wire                       port0_ingress_full;
   wire [LOG2_FIFO_DEPTH:0]   port0_ingress_fifo_level;
   wire                       port0_egress_srst;
   wire                       port0_egress_clk;
   wire                       port0_egress_write;
   wire [FLIT_WIDTH-1:0]      port0_egress_data;
   wire [LOG2_FIFO_DEPTH:0]   port0_egress_fifo_level;

   wire                       port1_ingress_srst;
   wire                       port1_ingress_clk;
   wire                       port1_ingress_write;
   wire [FLIT_WIDTH-1:0]      port1_ingress_data;
   wire                       port1_ingress_full;
   wire [LOG2_FIFO_DEPTH:0]   port1_ingress_fifo_level;
   wire                       port1_egress_srst;
   wire                       port1_egress_clk;
   wire                       port1_egress_write;
   wire [FLIT_WIDTH-1:0]      port1_egress_data;
   wire [LOG2_FIFO_DEPTH:0]   port1_egress_fifo_level;

   wire                       port2_ingress_srst;
   wire                       port2_ingress_clk;
   wire                       port2_ingress_write;
   wire [FLIT_WIDTH-1:0]      port2_ingress_data;
   wire                       port2_ingress_full;
   wire [LOG2_FIFO_DEPTH:0]   port2_ingress_fifo_level;
   wire                       port2_egress_srst;
   wire                       port2_egress_clk;
   wire                       port2_egress_write;
   wire [FLIT_WIDTH-1:0]      port2_egress_data;
   wire [LOG2_FIFO_DEPTH:0]   port2_egress_fifo_level;

   wire                       port3_ingress_srst;
   wire                       port3_ingress_clk;
   wire                       port3_ingress_write;
   wire [FLIT_WIDTH-1:0]      port3_ingress_data;
   wire                       port3_ingress_full;
   wire [LOG2_FIFO_DEPTH:0]   port3_ingress_fifo_level;
   wire                       port3_egress_srst;
   wire                       port3_egress_clk;
   wire                       port3_egress_write;
   wire [FLIT_WIDTH-1:0]      port3_egress_data;
   wire [LOG2_FIFO_DEPTH:0]   port3_egress_fifo_level;

   wire                       port4_ingress_srst;
   wire                       port4_ingress_clk;
   wire                       port4_ingress_write;
   wire [FLIT_WIDTH-1:0]      port4_ingress_data;
   wire                       port4_ingress_full;
   wire [LOG2_FIFO_DEPTH:0]   port4_ingress_fifo_level;
   wire                       port4_egress_srst;
   wire                       port4_egress_clk;
   wire                       port4_egress_write;
   wire [FLIT_WIDTH-1:0]      port4_egress_data;
   wire [LOG2_FIFO_DEPTH:0]   port4_egress_fifo_level;

   reg                        local_clk;
   reg                        local_srst;
   wire                       local_ingress_write;
   wire [FLIT_WIDTH-1:0]      local_ingress_data;
   wire                       local_ingress_full;
   wire [LOG2_FIFO_DEPTH:0]   local_ingress_fifo_level;
   wire                       local_egress_read;
   wire [FLIT_WIDTH-1:0]      local_egress_data;
   wire                       local_egress_empty;
   wire [LOG2_FIFO_DEPTH:0]   local_egress_fifo_level;

   wire                       packet_received;
   wire                       all_packets_received;
   reg [addr_flits_width-1:0] address_flits;
   wire                       address_sent;
   wire                       packet_sent;
   wire                       all_packets_sent;

   reg                        arst;
   integer                    cpt;


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
      local_clk          = 0;
      router_clk         = 0;
      arst               = 1;
      #10.2 arst         = 1;
      #20.4 arst         = 0;
   end

   always
     #4 router_clk = !router_clk;

   always
     #3 local_clk = !local_clk;

   always @(posedge router_clk) begin
      router_srst <= arst;
   end

   always @(posedge local_clk) begin
      local_srst <= arst;
   end


   //----------------------------------------------------------------
   // Value Change Dump
   //----------------------------------------------------------------
   initial begin
      $dumpfile ("hynoc_router_5p_tb3.vcd");
      $dumpvars;
   end


   //----------------------------------------------------------------
   // Topology
   //----------------------------------------------------------------
   // The router is wired as follow:
   //
   //                        .-------------.
   //                        |             |
   //                        ↓             |
   //                 .-------------.      |
   //                 |      P2     |      |
   //                 |             |      |
   // Tests <-->LI<-->| P3       P1 |<-----'
   //                 |             |
   //          .----->| P4   P0     |
   //          |      '-------------'
   //          |             ↑
   //          |             |
   //          '-------------'
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
   // Local interface
   //----------------------------------------------------------------
   hynoc_local_interface
   #(
      .LOG2_FIFO_DEPTH (LOG2_FIFO_DEPTH),
      .FLIT_WIDTH      (FLIT_WIDTH),
      .SINGLE_CLOCK    (SINGLE_CLOCK_ROUTER)
   )
   hynoc_local_interface_inst
   (
      .port_ingress_srst        (port3_ingress_srst),
      .port_ingress_clk         (port3_ingress_clk),
      .port_ingress_write       (port3_ingress_write),
      .port_ingress_data        (port3_ingress_data),
      .port_ingress_full        (port3_ingress_full),
      .port_ingress_fifo_level  (port3_ingress_fifo_level),
      .port_egress_srst         (port3_egress_srst),
      .port_egress_clk          (port3_egress_clk),
      .port_egress_write        (port3_egress_write),
      .port_egress_data         (port3_egress_data),
      .port_egress_fifo_level   (port3_egress_fifo_level),
      .local_clk                (local_clk),
      .local_srst               (local_srst),
      .local_ingress_write      (local_ingress_write),
      .local_ingress_data       (local_ingress_data),
      .local_ingress_full       (local_ingress_full),
      .local_ingress_fifo_level (local_ingress_fifo_level),
      .local_egress_read        (local_egress_read),
      .local_egress_data        (local_egress_data),
      .local_egress_empty       (local_egress_empty),
      .local_egress_fifo_level  (local_egress_fifo_level)
   );

   //----------------------------------------------------------------
   // Stream Writer
   //----------------------------------------------------------------
   hynoc_stream_writer
   #(
      .WRITER_CHECKER_ID   (3),
      .NB_ADDRESS_FLITS    (NB_ADDRESS_FLITS),
      .FLIT_RANDOM_SEED    (FLIT_RANDOM_SEED),
      .NB_FLIT_RANDOM_SEED (NB_FLIT_RANDOM_SEED),
      .NB_PACKETS          (NB_PACKETS),
      .MAX_NB_FLITS        (MAX_NB_FLITS),
      .MAX_WAIT            (MAX_WAIT),
      .LOG2_FIFO_DEPTH     (LOG2_FIFO_DEPTH),
      .PAYLOAD_WIDTH       (PAYLOAD_WIDTH),
      .FLIT_WIDTH          (FLIT_WIDTH)
   )
   hynoc_stream_writer_inst_3
   (
      .address_flits            (address_flits),
      .address_sent             (address_sent),
      .packet_sent              (packet_sent),
      .all_packets_sent         (all_packets_sent),
      .local_clk                (local_clk),
      .local_srst               (local_srst),
      .local_ingress_write      (local_ingress_write),
      .local_ingress_data       (local_ingress_data),
      .local_ingress_fifo_level (local_ingress_fifo_level)
   );

   //----------------------------------------------------------------
   // Stream Reader
   //----------------------------------------------------------------
   hynoc_stream_reader
   #(
      .READER_CHECKER_ID   (3),
      .WRITER_CHECKER_ID   (3),
      .NB_ADDRESS_FLITS    (NB_ADDRESS_FLITS),
      .FLIT_RANDOM_SEED    (FLIT_RANDOM_SEED),
      .NB_FLIT_RANDOM_SEED (NB_FLIT_RANDOM_SEED),
      .NB_PACKETS          (NB_PACKETS),
      .MAX_NB_FLITS        (MAX_NB_FLITS),
      .MAX_WAIT            (MAX_WAIT),
      .LOG2_FIFO_DEPTH     (LOG2_FIFO_DEPTH),
      .PAYLOAD_WIDTH       (PAYLOAD_WIDTH),
      .FLIT_WIDTH          (FLIT_WIDTH)
   )
   hynoc_stream_reader_inst_3
   (
      .packet_received         (packet_received),
      .all_packets_received    (all_packets_received),
      .local_clk               (local_clk),
      .local_srst              (local_srst),
      .local_egress_read       (local_egress_read),
      .local_egress_data       (local_egress_data),
      .local_egress_fifo_level (local_egress_fifo_level)
   );

   //----------------------------------------------------------------
   // Test Vectors
   //----------------------------------------------------------------
   initial begin
      // Path: P1.out/P2.in ## P0.out/P4.in ## P3.out
      address_flits = {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 28'b00_00_00_00_00_00_00_00_00_10_10_11_0010};
      wait(all_packets_sent);
      wait(all_packets_received);
      $finish;
   end



endmodule
