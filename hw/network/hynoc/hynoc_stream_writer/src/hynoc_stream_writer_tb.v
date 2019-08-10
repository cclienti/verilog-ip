//                              -*- Mode: Verilog -*-
// Filename        : hynoc_stream_writer_tb.v
// Description     : testbench of hynoc_stream_writer
// Author          : Christophe
// Created On      : Sun Feb 23 17:24:39 2014
// Last Modified By: Christophe
// Last Modified On: Sun Feb 23 17:24:39 2014
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module hynoc_stream_writer_tb();

   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------
   localparam integer WRITER_CHECKER_ID = 0;
   localparam integer NB_ADDRESS_FLITS = 2;
   localparam integer FLIT_RANDOM_SEED = 556;
   localparam integer NB_FLIT_RANDOM_SEED = 666;
   localparam integer NB_PACKETS = 100;
   localparam integer MAX_NB_FLITS = 1024;
   localparam integer MAX_WAIT = 1024;
   localparam integer LOG2_FIFO_DEPTH = 5;
   localparam integer PAYLOAD_WIDTH = 32;
   localparam integer FLIT_WIDTH = (PAYLOAD_WIDTH+1);

   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------
   reg [NB_ADDRESS_FLITS*FLIT_WIDTH-1:0] address_flits;
   wire                                  address_sent;
   wire                                  packet_sent;
   wire                                  all_packets_sent;
   reg                                   local_clk;
   reg                                   local_srst;
   wire                                  local_ingress_write;
   wire [FLIT_WIDTH-1:0]                 local_ingress_data;
   reg [LOG2_FIFO_DEPTH:0]               local_ingress_fifo_level;

   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------
   hynoc_stream_writer
   #(
      .WRITER_CHECKER_ID   (WRITER_CHECKER_ID),
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
   hynoc_stream_writer_inst
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
   // Value Change Dump
   //----------------------------------------------------------------
   initial begin
      $dumpfile ("hynoc_stream_writer_tb.vcd");
      $dumpvars;
   end

   //----------------------------------------------------------------
   // Clock and Reset Generation
   //----------------------------------------------------------------
   initial begin
      local_clk       = 0;
      local_srst      = 1;
      #10 local_srst  = 1;
      #20 local_srst  = 0;
   end

   always
     #2 local_clk = !local_clk;

   initial begin
     wait(all_packets_sent) $finish;
   end

   //----------------------------------------------------------------
   // Emulate the fifo level
   //----------------------------------------------------------------
   integer dir;
   reg fifo_incr;

   initial begin
      local_ingress_fifo_level = 0;
      dir = 0;
      address_flits = {{1'b0, 32'h01234567}, {1'b0, 32'h89abcdef}};
   end

   always @(posedge local_clk) begin
      if(dir == 0) begin
         local_ingress_fifo_level <= local_ingress_fifo_level + 1'b1;
      end else begin
         local_ingress_fifo_level <= local_ingress_fifo_level - 1'b1;
      end
   end

   always @(local_ingress_fifo_level) begin
      if(local_ingress_fifo_level == 0) begin
         dir = 0;
      end
      else if(local_ingress_fifo_level == 2**LOG2_FIFO_DEPTH-1) begin
         dir = 1;
      end
   end


endmodule
