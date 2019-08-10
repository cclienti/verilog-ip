//                              -*- Mode: Verilog -*-
// Filename        : hynoc_local_interface.v
// Description     : Testbench of the HyNoC local interface
// Author          : Christophe Clienti
// Created On      : Tue Jul  2 10:17:18 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Tue Jul  2 10:17:18 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module hynoc_local_interface_tb();

  //----------------------------------------------------------------
  // Constants
  //----------------------------------------------------------------

   parameter integer SINGLE_CLOCK = 1;
   localparam integer LOG2_FIFO_DEPTH = 5;
   localparam integer FLIT_WIDTH      = 33;


   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------
   wire                     port_ingress_srst;
   wire                     port_ingress_clk;
   wire                     port_ingress_write;
   wire [FLIT_WIDTH-1:0]    port_ingress_data;
   wire                     port_ingress_full;
   wire [LOG2_FIFO_DEPTH:0] port_ingress_fifo_level;

   reg                      port_egress_srst;
   reg                      port_egress_clk;
   reg                      port_egress_write;
   reg [FLIT_WIDTH-1:0]     port_egress_data;
   wire [LOG2_FIFO_DEPTH:0] port_egress_fifo_level;

   reg                      local_clk;
   reg                      local_srst;

   reg                      local_ingress_write;
   reg [FLIT_WIDTH-1:0]     local_ingress_data;
   wire                     local_ingress_full;
   wire [LOG2_FIFO_DEPTH:0] local_ingress_fifo_level;

   wire                     local_egress_read;
   wire [FLIT_WIDTH-1:0]    local_egress_data;
   wire                     local_egress_empty;
   wire [LOG2_FIFO_DEPTH:0] local_egress_fifo_level;

   integer                  cpt;


   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------
   hynoc_local_interface
   #(
      .LOG2_FIFO_DEPTH   (LOG2_FIFO_DEPTH),
      .FLIT_WIDTH        (FLIT_WIDTH),
      .SINGLE_CLOCK      (SINGLE_CLOCK)
   )
   hynoc_local_interface_inst
   (
      .port_ingress_srst        (port_ingress_srst),
      .port_ingress_clk         (port_ingress_clk),
      .port_ingress_write       (port_ingress_write),
      .port_ingress_data        (port_ingress_data),
      .port_ingress_full        (port_ingress_full),
      .port_ingress_fifo_level  (port_ingress_fifo_level),
      .port_egress_srst         (port_egress_srst),
      .port_egress_clk          (port_egress_clk),
      .port_egress_write        (port_egress_write),
      .port_egress_data         (port_egress_data),
      .port_egress_fifo_level   (port_egress_fifo_level),
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
   // Clock and Reset Generation
   //----------------------------------------------------------------

   initial begin
      local_clk         = 0;
      local_srst        = 1;
      port_egress_clk   = 0;
      port_egress_srst  = 1;

      #10 local_srst    = 1;
      port_egress_srst  = 1;

      #20 local_srst    = 0;
      port_egress_srst  = 0;
   end

   generate
      if (SINGLE_CLOCK != 0) begin
         always @(*) local_clk = port_egress_clk;
      end
      else begin
         always
           #2 local_clk = !local_clk;
      end
   endgenerate

   always
     #3 port_egress_clk = !port_egress_clk;


   //----------------------------------------------------------------
   // Value Change Dump
   //----------------------------------------------------------------

   initial begin
      $dumpfile ("hynoc_local_interface_tb.vcd");
      $dumpvars;
   end


   //----------------------------------------------------------------
   // Test Vectors
   //----------------------------------------------------------------

   initial
     #1000 $finish;


   assign port_ingress_fifo_level = 15;
   assign port_ingress_full = 1'b0;

   always @(posedge port_egress_clk) begin
      if(port_egress_srst == 1'b1) begin
         port_egress_write <= 1'b0;
         port_egress_data  <= 0;
      end
      else begin
         port_egress_write <= ({$random} % 4) == 0 ? !port_egress_fifo_level[LOG2_FIFO_DEPTH] : 1'b0;
         port_egress_data  <= {$random};
      end
   end


   always @(posedge local_clk) begin
      if(local_srst == 1'b1) begin
         local_ingress_write <= 1'b0;
         local_ingress_data  <= 0;
      end
      else begin
         local_ingress_write <= ({$random} % 4) == 0;
         local_ingress_data  <= {$random};
      end
   end


   assign local_egress_read = (local_egress_fifo_level != 0) ? 1'b1 : 1'b0;



endmodule
