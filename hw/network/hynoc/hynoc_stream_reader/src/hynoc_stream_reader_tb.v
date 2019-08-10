//                              -*- Mode: Verilog -*-
// Filename        : hynoc_stream_reader_tb.v
// Description     : testbench of hynoc_stream_reader
// Author          : Christophe Clienti
// Created On      : Thu Feb 27 11:04:40 2014
// Last Modified By: Christophe Clienti
// Last Modified On: Thu Feb 27 11:04:40 2014
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module hynoc_stream_reader_tb();

   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------
   localparam integer READER_CHECKER_ID   = 5;
   localparam integer WRITER_CHECKER_ID   = 7;
   localparam integer NB_ADDRESS_FLITS    = 2;
   localparam integer FLIT_RANDOM_SEED    = 556;
   localparam integer NB_FLIT_RANDOM_SEED = 666;
   localparam integer NB_PACKETS          = 1000;
   localparam integer MAX_NB_FLITS        = 1024;
   localparam integer MAX_WAIT            = 1024;
   localparam integer LOG2_FIFO_DEPTH     = 5;
   localparam integer PAYLOAD_WIDTH       = 32;
   localparam integer FLIT_WIDTH          = (PAYLOAD_WIDTH+1);


   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------
   //reader
   wire                                  packet_received;
   wire                                  all_packets_received;
   reg                                   local_clk;
   reg                                   local_srst;
   wire                                  local_egress_read;
   wire [FLIT_WIDTH-1:0]                 local_egress_data;
   wire [LOG2_FIFO_DEPTH:0]              local_egress_fifo_level;

   //writer
   reg [NB_ADDRESS_FLITS*FLIT_WIDTH-1:0] address_flits;
   wire                                  address_sent;
   wire                                  packet_sent;
   wire                                  all_packets_sent;
   wire                                  local_ingress_write;
   wire [FLIT_WIDTH-1:0]                 local_ingress_data;
   wire [LOG2_FIFO_DEPTH:0]              local_ingress_fifo_level;


   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------
   //we add one to NB_ADDRESS_FLITS of the reader because there is no
   //router between the writer and the reader. So the reader will
   //receive one more address flits.
   hynoc_stream_reader
   #(
      .READER_CHECKER_ID   (READER_CHECKER_ID),
      .WRITER_CHECKER_ID   (WRITER_CHECKER_ID),
      .NB_ADDRESS_FLITS    (NB_ADDRESS_FLITS+1),
      .FLIT_RANDOM_SEED    (FLIT_RANDOM_SEED),
      .NB_FLIT_RANDOM_SEED (NB_FLIT_RANDOM_SEED),
      .NB_PACKETS          (NB_PACKETS),
      .MAX_NB_FLITS        (MAX_NB_FLITS),
      .MAX_WAIT            (MAX_WAIT),
      .LOG2_FIFO_DEPTH     (LOG2_FIFO_DEPTH),
      .PAYLOAD_WIDTH       (PAYLOAD_WIDTH),
      .FLIT_WIDTH          (FLIT_WIDTH)
   )
   hynoc_stream_reader_inst
   (
      .packet_received         (packet_received),
      .all_packets_received    (all_packets_received),
      .local_clk               (local_clk),
      .local_srst              (local_srst),
      .local_egress_read       (local_egress_read),
      .local_egress_data       (local_egress_data),
      .local_egress_fifo_level (local_egress_fifo_level)
   );

   dclkfifolut
   #(
      .LOG2_FIFO_DEPTH (LOG2_FIFO_DEPTH),
      .FIFO_WIDTH      (FLIT_WIDTH)
   )
   dclkfifolut_inst
   (
      .rsrst  (local_srst),
      .rclk   (local_clk),
      .ren    (local_egress_read),
      .rdata  (local_egress_data),
      .rlevel (local_egress_fifo_level),
      .wsrst  (local_srst),
      .wclk   (local_clk),
      .wen    (local_ingress_write),
      .wdata  (local_ingress_data),
      .wlevel (local_ingress_fifo_level)
   );

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
      $dumpfile ("hynoc_stream_reader_tb.vcd");
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


   //----------------------------------------------------------------
   // Test Vectors
   //----------------------------------------------------------------
   initial begin
      address_flits = {{1'b0, 32'h01234567}, {1'b0, 32'h09abcdef}};
      wait(all_packets_sent);
      wait(all_packets_received);
      $finish;
   end


endmodule
