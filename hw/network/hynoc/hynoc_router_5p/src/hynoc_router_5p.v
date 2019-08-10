//                              -*- Mode: Verilog -*-
// Filename        : hynoc_router_5p.v
// Description     : 5 ports HyNoC Router
// Author          : Christophe
// Created On      : Sat Jun 29 18:41:44 2013
// Last Modified By: Christophe
// Last Modified On: Sat Jun 29 18:41:44 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module hynoc_router_5p
  #(parameter integer INDEX_WIDTH          = 4,  //width of header index
    parameter integer LOG2_FIFO_DEPTH      = 5,  //log2 depth of the ingress fifo
    parameter integer PAYLOAD_WIDTH        = 32, //payload width
    parameter integer FLIT_WIDTH           = (PAYLOAD_WIDTH+1), //payload width
    parameter integer PRRA_PIPELINE        = 0,  //2-cycle prra response when pipeline is 0 else 3-cycle response
    parameter integer SINGLE_CLOCK_ROUTER  = 0,
    parameter integer ENABLE_MCAST_ROUTING = 1,
    parameter integer ENABLE_XY_ROUTING    = 1)

   (input wire                      router_clk,
    input wire                      router_srst,

    input wire                      port0_ingress_srst,
    input wire                      port0_ingress_clk,
    input wire                      port0_ingress_write,
    input wire [FLIT_WIDTH-1:0]     port0_ingress_data,
    output wire                     port0_ingress_full,
    output wire [LOG2_FIFO_DEPTH:0] port0_ingress_fifo_level,
    output wire                     port0_egress_srst,
    output wire                     port0_egress_clk,
    output wire                     port0_egress_write,
    output wire [FLIT_WIDTH-1:0]    port0_egress_data,
    input wire [LOG2_FIFO_DEPTH:0]  port0_egress_fifo_level,

    input wire                      port1_ingress_srst,
    input wire                      port1_ingress_clk,
    input wire                      port1_ingress_write,
    input wire [FLIT_WIDTH-1:0]     port1_ingress_data,
    output wire                     port1_ingress_full,
    output wire [LOG2_FIFO_DEPTH:0] port1_ingress_fifo_level,
    output wire                     port1_egress_srst,
    output wire                     port1_egress_clk,
    output wire                     port1_egress_write,
    output wire [FLIT_WIDTH-1:0]    port1_egress_data,
    input wire [LOG2_FIFO_DEPTH:0]  port1_egress_fifo_level,

    input wire                      port2_ingress_srst,
    input wire                      port2_ingress_clk,
    input wire                      port2_ingress_write,
    input wire [FLIT_WIDTH-1:0]     port2_ingress_data,
    output wire                     port2_ingress_full,
    output wire [LOG2_FIFO_DEPTH:0] port2_ingress_fifo_level,
    output wire                     port2_egress_srst,
    output wire                     port2_egress_clk,
    output wire                     port2_egress_write,
    output wire [FLIT_WIDTH-1:0]    port2_egress_data,
    input wire [LOG2_FIFO_DEPTH:0]  port2_egress_fifo_level,

    input wire                      port3_ingress_srst,
    input wire                      port3_ingress_clk,
    input wire                      port3_ingress_write,
    input wire [FLIT_WIDTH-1:0]     port3_ingress_data,
    output wire                     port3_ingress_full,
    output wire [LOG2_FIFO_DEPTH:0] port3_ingress_fifo_level,
    output wire                     port3_egress_srst,
    output wire                     port3_egress_clk,
    output wire                     port3_egress_write,
    output wire [FLIT_WIDTH-1:0]    port3_egress_data,
    input wire [LOG2_FIFO_DEPTH:0]  port3_egress_fifo_level,

    input wire                      port4_ingress_srst,
    input wire                      port4_ingress_clk,
    input wire                      port4_ingress_write,
    input wire [FLIT_WIDTH-1:0]     port4_ingress_data,
    output wire                     port4_ingress_full,
    output wire [LOG2_FIFO_DEPTH:0] port4_ingress_fifo_level,
    output wire                     port4_egress_srst,
    output wire                     port4_egress_clk,
    output wire                     port4_egress_write,
    output wire [FLIT_WIDTH-1:0]    port4_egress_data,
    input wire [LOG2_FIFO_DEPTH:0]  port4_egress_fifo_level);


   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------
   localparam LEVEL_WIDTH = LOG2_FIFO_DEPTH+1;


   //----------------------------------------------------------------
   // Constants for the 5 ports router
   //----------------------------------------------------------------
   localparam NB_PORTS = 5;


   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------
   wire [NB_PORTS-1:0]                     port_ingress_srst;
   wire [NB_PORTS-1:0]                     port_ingress_clk;
   wire [NB_PORTS-1:0]                     port_ingress_write;
   wire [NB_PORTS*FLIT_WIDTH-1:0]          port_ingress_data;
   wire [NB_PORTS-1:0]                     port_ingress_full;
   wire [NB_PORTS*(LOG2_FIFO_DEPTH+1)-1:0] port_ingress_fifo_level;
   wire [NB_PORTS-1:0]                     port_egress_srst;
   wire [NB_PORTS-1:0]                     port_egress_clk;
   wire [NB_PORTS-1:0]                     port_egress_write;
   wire [NB_PORTS*FLIT_WIDTH-1:0]          port_egress_data;
   wire [NB_PORTS*(LOG2_FIFO_DEPTH+1)-1:0] port_egress_fifo_level;


   //----------------------------------------------------------------
   // Generic Router Base Instance
   //----------------------------------------------------------------
   hynoc_router_base
   #(
      .NB_PORTS             (NB_PORTS),
      .INDEX_WIDTH          (INDEX_WIDTH),
      .LOG2_FIFO_DEPTH      (LOG2_FIFO_DEPTH),
      .PAYLOAD_WIDTH        (PAYLOAD_WIDTH),
      .FLIT_WIDTH           (FLIT_WIDTH),
      .PRRA_PIPELINE        (PRRA_PIPELINE),
      .SINGLE_CLOCK_ROUTER  (SINGLE_CLOCK_ROUTER),
      .ENABLE_MCAST_ROUTING (ENABLE_MCAST_ROUTING),
      .ENABLE_XY_ROUTING    (ENABLE_XY_ROUTING)
   )
   hynoc_router_base_inst
   (
      .router_clk              (router_clk),
      .router_srst             (router_srst),
      .port_ingress_srst       (port_ingress_srst),
      .port_ingress_clk        (port_ingress_clk),
      .port_ingress_write      (port_ingress_write),
      .port_ingress_data       (port_ingress_data),
      .port_ingress_full       (port_ingress_full),
      .port_ingress_fifo_level (port_ingress_fifo_level),
      .port_egress_srst        (port_egress_srst),
      .port_egress_clk         (port_egress_clk),
      .port_egress_write       (port_egress_write),
      .port_egress_data        (port_egress_data),
      .port_egress_fifo_level  (port_egress_fifo_level)
   );


   //----------------------------------------------------------------
   // Wrap the Router Base Instance
   //----------------------------------------------------------------
   assign port_ingress_srst = {port4_ingress_srst, port3_ingress_srst, port2_ingress_srst,
                               port1_ingress_srst, port0_ingress_srst};

   assign port_ingress_clk = {port4_ingress_clk, port3_ingress_clk, port2_ingress_clk,
                              port1_ingress_clk, port0_ingress_clk};

   assign port_ingress_write = {port4_ingress_write, port3_ingress_write, port2_ingress_write,
                                port1_ingress_write, port0_ingress_write};

   assign port_ingress_data = {port4_ingress_data, port3_ingress_data, port2_ingress_data,
                               port1_ingress_data, port0_ingress_data};

   assign port_egress_fifo_level = {port4_egress_fifo_level, port3_egress_fifo_level, port2_egress_fifo_level,
                                    port1_egress_fifo_level, port0_egress_fifo_level};

   assign port0_ingress_full       = port_ingress_full[0];
   assign port0_ingress_fifo_level = port_ingress_fifo_level[0*LEVEL_WIDTH +: LEVEL_WIDTH];
   assign port0_egress_srst        = port_egress_srst[0];
   assign port0_egress_clk         = port_egress_clk[0];
   assign port0_egress_write       = port_egress_write[0];
   assign port0_egress_data        = port_egress_data[FLIT_WIDTH-1:0];

   assign port1_ingress_full       = port_ingress_full[1];
   assign port1_ingress_fifo_level = port_ingress_fifo_level[1*LEVEL_WIDTH +: LEVEL_WIDTH];
   assign port1_egress_srst        = port_egress_srst[1];
   assign port1_egress_clk         = port_egress_clk[1];
   assign port1_egress_write       = port_egress_write[1];
   assign port1_egress_data        = port_egress_data[1*FLIT_WIDTH +: FLIT_WIDTH];

   assign port2_ingress_full       = port_ingress_full[2];
   assign port2_ingress_fifo_level = port_ingress_fifo_level[2*LEVEL_WIDTH +: LEVEL_WIDTH];
   assign port2_egress_srst        = port_egress_srst[2];
   assign port2_egress_clk         = port_egress_clk[2];
   assign port2_egress_write       = port_egress_write[2];
   assign port2_egress_data        = port_egress_data[2*FLIT_WIDTH +: FLIT_WIDTH];

   assign port3_ingress_full       = port_ingress_full[3];
   assign port3_ingress_fifo_level = port_ingress_fifo_level[3*LEVEL_WIDTH +: LEVEL_WIDTH];
   assign port3_egress_srst        = port_egress_srst[3];
   assign port3_egress_clk         = port_egress_clk[3];
   assign port3_egress_write       = port_egress_write[3];
   assign port3_egress_data        = port_egress_data[3*FLIT_WIDTH +: FLIT_WIDTH];

   assign port4_ingress_full       = port_ingress_full[4];
   assign port4_ingress_fifo_level = port_ingress_fifo_level[4*LEVEL_WIDTH +: LEVEL_WIDTH];
   assign port4_egress_srst        = port_egress_srst[4];
   assign port4_egress_clk         = port_egress_clk[4];
   assign port4_egress_write       = port_egress_write[4];
   assign port4_egress_data        = port_egress_data[4*FLIT_WIDTH +: FLIT_WIDTH];

endmodule
