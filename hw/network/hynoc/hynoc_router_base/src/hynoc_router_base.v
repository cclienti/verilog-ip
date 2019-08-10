//                              -*- Mode: Verilog -*-
// Filename        : hynoc_router_base.v
// Description     : N Ports HyNoC Router
// Author          : Christophe
// Created On      : Sat Jun 29 18:41:44 2013
// Last Modified By: Christophe
// Last Modified On: Sat Jun 29 18:41:44 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module hynoc_router_base
  #(parameter integer NB_PORTS             = 5,  //nb ports
    parameter integer INDEX_WIDTH          = 4,  //width of header index
    parameter integer LOG2_FIFO_DEPTH      = 5,  //log2 depth of the ingress fifo
    parameter integer PAYLOAD_WIDTH        = 32, //payload width
    parameter integer FLIT_WIDTH           = (PAYLOAD_WIDTH+1),
    parameter integer PRRA_PIPELINE        = 0,  //2-cycle prra response when pipeline is 0 else 3-cycle response
    parameter integer SINGLE_CLOCK_ROUTER  = 0,  //all clocks are the same
    parameter integer ENABLE_MCAST_ROUTING = 1,  //enable multicast protocol
    parameter integer ENABLE_XY_ROUTING    = 1)  //enable XY protocol (not supported)

   (input wire                                     router_clk,
    input wire                                     router_srst,

    input wire [NB_PORTS-1:0]                      port_ingress_srst,
    input wire [NB_PORTS-1:0]                      port_ingress_clk,
    input wire [NB_PORTS-1:0]                      port_ingress_write,
    input wire [NB_PORTS*FLIT_WIDTH-1:0]           port_ingress_data,
    output wire [NB_PORTS-1:0]                     port_ingress_full,
    output wire [NB_PORTS*(LOG2_FIFO_DEPTH+1)-1:0] port_ingress_fifo_level,

    output wire [NB_PORTS-1:0]                     port_egress_srst,
    output wire [NB_PORTS-1:0]                     port_egress_clk,
    output wire [NB_PORTS-1:0]                     port_egress_write,
    output wire [NB_PORTS*FLIT_WIDTH-1:0]          port_egress_data,
    input wire [NB_PORTS*(LOG2_FIFO_DEPTH+1)-1:0]  port_egress_fifo_level);


   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------
   localparam PRRA_WIDTH       = NB_PORTS-1;
   localparam MUX_INPUT_WIDTH  = PRRA_WIDTH*FLIT_WIDTH;
   localparam LEVEL_WIDTH      = LOG2_FIFO_DEPTH+1;


   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------
   wire [FLIT_WIDTH-1:0]    ingress_data [NB_PORTS-1:0];
   wire [LOG2_FIFO_DEPTH:0] ingress_level [NB_PORTS-1:0];
   wire [FLIT_WIDTH-1:0]    egress_data [NB_PORTS-1:0];
   wire [LOG2_FIFO_DEPTH:0] egress_level [NB_PORTS-1:0];

   wire [NB_PORTS-2:0]      from_egress_grant [NB_PORTS-1:0];
   wire [NB_PORTS-2:0]      from_egress_afull [NB_PORTS-1:0];
   wire [NB_PORTS-2:0]      to_egress_request [NB_PORTS-1:0];
   wire                     to_egress_write [NB_PORTS-1:0];
   wire [FLIT_WIDTH-1:0]    to_egress_data [NB_PORTS-1:0];

   wire [NB_PORTS-2:0]        to_ingress_grant [NB_PORTS-1:0];
   wire [NB_PORTS-2:0]        to_ingress_afull [NB_PORTS-1:0];

   wire [NB_PORTS-2:0]        from_ingress_request [NB_PORTS-1:0];
   wire [NB_PORTS-2:0]        from_ingress_write [NB_PORTS-1:0];
   wire [MUX_INPUT_WIDTH-1:0] from_ingress_data [NB_PORTS-1:0];

   genvar i,j;


   //----------------------------------------------------------------
   // Arrays to handle data and fifo level
   //----------------------------------------------------------------
   generate
      for(i=0; i<NB_PORTS; i=i+1) begin: gen_arrays
         assign ingress_data[i] = port_ingress_data[i*FLIT_WIDTH +: FLIT_WIDTH];
         assign egress_level[i] = port_egress_fifo_level[i*LEVEL_WIDTH +: LEVEL_WIDTH];
         assign port_ingress_fifo_level[i*LEVEL_WIDTH +: LEVEL_WIDTH] = ingress_level[i];
         assign port_egress_data[i*FLIT_WIDTH +: FLIT_WIDTH] = egress_data[i];
      end
   endgenerate


   //----------------------------------------------------------------
   // Instantiate ingress and egress modules
   //----------------------------------------------------------------
   generate
      for(i=0; i<NB_PORTS; i=i+1) begin: gen_modules
         hynoc_ingress
           #(.NB_PORTS             (NB_PORTS),
             .INDEX_WIDTH          (INDEX_WIDTH),
             .LOG2_FIFO_DEPTH      (LOG2_FIFO_DEPTH),
             .PAYLOAD_WIDTH        (PAYLOAD_WIDTH),
             .FLIT_WIDTH           (FLIT_WIDTH),
             .SINGLE_CLOCK_PORT    (SINGLE_CLOCK_ROUTER),
             .ENABLE_MCAST_ROUTING (ENABLE_MCAST_ROUTING),
             .ENABLE_XY_ROUTING    (ENABLE_XY_ROUTING))
         hynoc_ingress_inst
            (.wsrst             (port_ingress_srst[i]),
             .wclk              (port_ingress_clk[i]),
             .wen               (port_ingress_write[i]),
             .wdata             (ingress_data[i]),
             .wfull             (port_ingress_full[i]),
             .wlevel            (ingress_level[i]),
             .router_srst       (router_srst),
             .router_clk        (router_clk),
             .from_egress_grant (from_egress_grant[i]),
             .from_egress_afull (from_egress_afull[i]),
             .to_egress_request (to_egress_request[i]),
             .to_egress_write   (to_egress_write[i]),
             .to_egress_data    (to_egress_data[i]));

         hynoc_egress
           #(.NB_PORTS         (NB_PORTS),
             .LOG2_FIFO_DEPTH  (LOG2_FIFO_DEPTH),
             .PAYLOAD_WIDTH    (PAYLOAD_WIDTH),
             .PRRA_PIPELINE    (PRRA_PIPELINE),
             .FLIT_WIDTH       (FLIT_WIDTH),
             .MUX_INPUT_WIDTH  (MUX_INPUT_WIDTH))
         hynoc_egress_inst
           (.wsrst                (port_egress_srst[i]),
            .wclk                 (port_egress_clk[i]),
            .wen                  (port_egress_write[i]),
            .wdata                (egress_data[i]),
            .wlevel               (egress_level[i]),
            .router_srst          (router_srst),
            .router_clk           (router_clk),
            .to_ingress_grant     (to_ingress_grant[i]),
            .to_ingress_afull     (to_ingress_afull[i]),
            .from_ingress_request (from_ingress_request[i]),
            .from_ingress_write   (from_ingress_write[i]),
            .from_ingress_data    (from_ingress_data[i]));
      end
   endgenerate



   //----------------------------------------------------------------
   // Connections
   //----------------------------------------------------------------
   generate
      for(j=0; j<NB_PORTS; j=j+1) begin: gen_iter_module
         for(i=0; i<PRRA_WIDTH; i=i+1) begin: gen_iter_bits
            assign from_egress_grant[j][i] = to_ingress_grant[(i+1+j)%NB_PORTS][PRRA_WIDTH-1-i];
            assign from_egress_afull[j][i] = to_ingress_afull[(i+1+j)%NB_PORTS][PRRA_WIDTH-1-i];
            assign from_ingress_request[j][i] = to_egress_request[(i+1+j)%NB_PORTS][PRRA_WIDTH-1-i];

            assign from_ingress_write[j][i] = to_egress_write[(i+1+j)%NB_PORTS];

            assign from_ingress_data[j][i*FLIT_WIDTH +: FLIT_WIDTH] = to_egress_data[(i+1+j)%NB_PORTS];
         end
      end
   endgenerate



endmodule
