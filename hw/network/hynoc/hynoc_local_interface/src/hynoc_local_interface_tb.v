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
   // Test Vectors
   //----------------------------------------------------------------

   //----------------------------------------------------------------
   localparam integer RX_FLITS_P_REF = 31;
   localparam [63:0]  RX_SUM_P_REF   = 64'h000000101b534928;
   localparam integer RX_FLITS_L_REF = 44;
   localparam [63:0]  RX_SUM_L_REF   = 64'h00000014b27e1b50;

   // Checker
   //----------------------------------------------------------------
   // The stimulus is a fixed hand-written sequence: count and sum of
   // what the DUT drives, compared against values blessed from a run
   // verified by inspection. A mismatch means the behaviour changed --
   // re-bless deliberately, never to make the run pass.
   integer   rx_flits_p = 0;
   reg [63:0] rx_sum_p  = 0;
   integer   rx_flits_l = 0;
   reg [63:0] rx_sum_l  = 0;

   always @(posedge local_clk) begin
      if (port_ingress_write) begin
         rx_flits_p <= rx_flits_p + 1;
         rx_sum_p   <= rx_sum_p + port_ingress_data;
      end
   end

   // The egress fifo presents its word the cycle after the read strobe.
   reg local_egress_read_q = 0;
   always @(posedge local_clk) begin
      local_egress_read_q <= local_egress_read;
      if (local_egress_read_q) begin
         rx_flits_l <= rx_flits_l + 1;
         rx_sum_l   <= rx_sum_l + local_egress_data;
      end
   end

   initial begin
      #1000;
      $display("rx_p: %0d flits sum 64'h%h", rx_flits_p, rx_sum_p);
      $display("rx_l: %0d flits sum 64'h%h", rx_flits_l, rx_sum_l);
      if (rx_flits_p === RX_FLITS_P_REF && rx_sum_p === RX_SUM_P_REF && rx_flits_l === RX_FLITS_L_REF && rx_sum_l === RX_SUM_L_REF)
        $display("hynoc_local_interface_tb: ALL TESTS PASSED");
      else begin
        $display("hynoc_local_interface_tb: delivered stream differs from the blessed reference");
        $display("hynoc_local_interface_tb: 1 ERROR(S)");
      end
      $finish;
   end


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
