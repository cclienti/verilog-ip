//                              -*- Mode: Verilog -*-
// Filename        : hynoc_local_interface.v
// Description     : HyNoC local interface
// Author          : Christophe Clienti
// Created On      : Tue Jul  2 10:17:18 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Tue Jul  2 10:17:18 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module hynoc_local_interface
  #(parameter integer LOG2_FIFO_DEPTH = 5,  //log2 depth of the ingress fifo
    parameter integer FLIT_WIDTH      = 33,
    parameter integer SINGLE_CLOCK    = 0)

   (// Router side
    output wire                     port_ingress_srst,
    output wire                     port_ingress_clk,
    output wire                     port_ingress_write,
    output wire [FLIT_WIDTH-1:0]    port_ingress_data,
    input wire                      port_ingress_full,
    input wire [LOG2_FIFO_DEPTH:0]  port_ingress_fifo_level,

    input wire                      port_egress_srst,
    input wire                      port_egress_clk,
    input wire                      port_egress_write,
    input wire [FLIT_WIDTH-1:0]     port_egress_data,
    output wire [LOG2_FIFO_DEPTH:0] port_egress_fifo_level,

    // Client side
    input wire                      local_clk,
    input wire                      local_srst,

    input wire                      local_ingress_write,
    input wire [FLIT_WIDTH-1:0]     local_ingress_data,
    output wire                     local_ingress_full,
    output wire [LOG2_FIFO_DEPTH:0] local_ingress_fifo_level,

    input wire                      local_egress_read,
    output wire [FLIT_WIDTH-1:0]    local_egress_data,
    output wire                     local_egress_empty,
    output wire [LOG2_FIFO_DEPTH:0] local_egress_fifo_level);


   //----------------------------------------------------------------
   // local_egress fifo instance
   //----------------------------------------------------------------

   generate
      if (SINGLE_CLOCK != 0) begin

         sclkfifolut
         #(
            .LOG2_FIFO_DEPTH (LOG2_FIFO_DEPTH),
            .FIFO_WIDTH      (FLIT_WIDTH)
         )
         sclkfifolut_inst
         (
            .clk    (local_clk),
            .srst   (local_srst),
            .level  (local_egress_fifo_level),
            .ren    (local_egress_read),
            .rdata  (local_egress_data),
            .rempty (local_egress_empty),
            .wen    (port_egress_write),
            .wdata  (port_egress_data),
            .wfull  ()
         );

         assign port_egress_fifo_level = local_egress_fifo_level;

      end
      else begin

         dclkfifolut
         #(
            .LOG2_FIFO_DEPTH (LOG2_FIFO_DEPTH),
            .FIFO_WIDTH      (FLIT_WIDTH)
         )
         dclkfifolut_inst
         (
            .rsrst   (local_srst),
            .rclk    (local_clk),
            .ren     (local_egress_read),
            .rdata   (local_egress_data),
            .rlevel  (local_egress_fifo_level),
            .rempty  (local_egress_empty),
            .wsrst   (port_egress_srst),
            .wclk    (port_egress_clk),
            .wen     (port_egress_write),
            .wdata   (port_egress_data),
            .wlevel  (port_egress_fifo_level),
            .wfull   ()
         );

      end
   endgenerate


   //----------------------------------------------------------------
   // Forward ingress local to port
   //----------------------------------------------------------------

   assign port_ingress_srst        = local_srst;
   assign port_ingress_clk         = local_clk;
   assign port_ingress_write       = local_ingress_write;
   assign port_ingress_data        = local_ingress_data;
   assign local_ingress_full       = port_ingress_full;
   assign local_ingress_fifo_level = port_ingress_fifo_level;


endmodule
