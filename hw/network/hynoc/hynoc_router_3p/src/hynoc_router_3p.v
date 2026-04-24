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

module hynoc_router_3p
  #(parameter integer INDEX_WIDTH          = 5,  //width of header index
    parameter integer LOG2_FIFO_DEPTH      = 5,  //log2 depth of the ingress fifo
    parameter integer PAYLOAD_WIDTH        = 32, //payload width
    parameter integer FLIT_WIDTH           = (PAYLOAD_WIDTH+1), //payload width
    parameter integer PRRA_PIPELINE        = 0,  //2-cycle prra response when pipeline
                                                 //is 0 else 3-cycle response
    parameter integer SINGLE_CLOCK_ROUTER  = 0,
    parameter integer ENABLE_MCAST_ROUTING = 1)

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
    input wire [LOG2_FIFO_DEPTH:0]  port2_egress_fifo_level);


   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------
   localparam LEVEL_WIDTH = LOG2_FIFO_DEPTH+1;
   localparam ENABLE_XY_ROUTING = 0;
   localparam NB_PORTS = 3;


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
   assign port_ingress_srst = {port2_ingress_srst,
                               port1_ingress_srst,
                               port0_ingress_srst};

   assign port_ingress_clk = {port2_ingress_clk,
                              port1_ingress_clk,
                              port0_ingress_clk};

   assign port_ingress_write = {port2_ingress_write,
                                port1_ingress_write,
                                port0_ingress_write};

   assign port_ingress_data = {port2_ingress_data,
                               port1_ingress_data,
                               port0_ingress_data};

   assign port_egress_fifo_level = {port2_egress_fifo_level,
                                    port1_egress_fifo_level,
                                    port0_egress_fifo_level};

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

endmodule
