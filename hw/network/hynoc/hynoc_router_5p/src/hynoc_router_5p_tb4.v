//                              -*- Mode: Verilog -*-
// Filename        : hynoc_router_5p_tb4.v
// Description     : Testbench of the five ports router
// Author          : Christophe Clienti
// Created On      : Mon Jul  1 13:24:35 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Mon Jul  1 13:24:35 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module hynoc_router_5p_tb4;


   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------

   parameter integer SINGLE_CLOCK_ROUTER = 0;

   localparam integer INDEX_WIDTH          = 4;
   localparam integer LOG2_FIFO_DEPTH      = 5;
   localparam integer PAYLOAD_WIDTH        = 32;
   localparam integer FLIT_WIDTH           = (PAYLOAD_WIDTH+1);
   localparam integer PRRA_PIPELINE        = 0;
   localparam integer ENABLE_MCAST_ROUTING = 1;
   localparam integer ENABLE_XY_ROUTING    = 1;

   localparam integer NB_ADDRESS_FLITS    = 1;
   localparam integer FLIT_RANDOM_SEED    = 556;
   localparam integer NB_FLIT_RANDOM_SEED = 666;
   localparam integer NB_PACKETS          = 1000;
   localparam integer MAX_NB_FLITS        = 1024;
   localparam integer MAX_WAIT            = 2;

`include "hynoc_ingress_routing_list.v"

   localparam ADDR_FLITS_WIDTH = NB_ADDRESS_FLITS*FLIT_WIDTH;


   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------
   reg                        arst;
   integer                    cpt;

   reg                        router_clk;
   reg                        router_srst;

   wire [9:0]                 ingress_srst;
   wire [9:0]                 ingress_clk;
   wire [9:0]                 ingress_write;
   wire [FLIT_WIDTH-1:0]      ingress_data [0:9];
   wire [9:0]                 ingress_full;
   wire [LOG2_FIFO_DEPTH:0]   ingress_fifo_level [0:9];
   wire [9:0]                 egress_srst;
   wire [9:0]                 egress_clk;
   wire [9:0]                 egress_write;
   wire [FLIT_WIDTH-1:0]      egress_data [0:9];
   wire [LOG2_FIFO_DEPTH:0]   egress_fifo_level [0:9];

   reg [7:0]                  local_clk;
   reg [7:0]                  local_srst;
   wire [7:0]                 local_ingress_write;
   wire [FLIT_WIDTH-1:0]      local_ingress_data [0:7];
   wire [7:0]                 local_ingress_full;
   wire [LOG2_FIFO_DEPTH:0]   local_ingress_fifo_level [0:7];
   wire [7:0]                 local_egress_read;
   wire [FLIT_WIDTH-1:0]      local_egress_data [0:7];
   wire [7:0]                 local_egress_empty;
   wire [LOG2_FIFO_DEPTH:0]   local_egress_fifo_level [0:7];

   wire [7:0]                 reader_packet_received;
   wire [7:0]                 reader_all_packets_received;

   reg [ADDR_FLITS_WIDTH-1:0] writer_address_flits [0:7];
   wire [7:0]                 writer_address_sent;
   wire [7:0]                 writer_packet_sent;
   wire [7:0]                 writer_all_packets_sent;

   genvar i;


   //----------------------------------------------------------------
   // Value Change Dump
   //----------------------------------------------------------------

   initial begin
      $dumpfile ("hynoc_router_5p_tb4.vcd");
      $dumpvars;
   end


   //----------------------------------------------------------------
   // Clock and Reset Generation
   //----------------------------------------------------------------
   initial begin
      router_clk = 0;

      local_clk[0] = 0;
      local_clk[1] = 0;
      local_clk[2] = 0;
      local_clk[3] = 0;
      local_clk[4] = 0;
      local_clk[5] = 0;
      local_clk[6] = 0;
      local_clk[7] = 0;

      arst       = 1;
      #10.2 arst = 1;
      #20.4 arst = 0;
   end

   always
     #4 router_clk = !router_clk;

   always @(posedge router_clk)
      router_srst <= arst;

   generate
      if (SINGLE_CLOCK_ROUTER != 0) begin
         always @(*) local_clk = {8{router_clk}};
      end
      else begin
         always begin
            fork
               #3 local_clk[0] = !local_clk[0];
               #4 local_clk[1] = !local_clk[1];
               #5 local_clk[2] = !local_clk[2];
               #6 local_clk[3] = !local_clk[3];
               #6 local_clk[4] = !local_clk[4];
               #5 local_clk[5] = !local_clk[5];
               #4 local_clk[6] = !local_clk[6];
               #3 local_clk[7] = !local_clk[7];
            join
         end
      end
   endgenerate

   generate
      for(i=0; i<8; i=i+1) begin: gen_reset_li
         always @(posedge local_clk[i]) local_srst[i] <= arst;
      end
   endgenerate


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
   hynoc_router_5p_inst_0
   (
      .router_clk               (router_clk),
      .router_srst              (router_srst),

      .port0_ingress_srst       (ingress_srst[0]),
      .port0_ingress_clk        (ingress_clk[0]),
      .port0_ingress_write      (ingress_write[0]),
      .port0_ingress_data       (ingress_data[0]),
      .port0_ingress_full       (ingress_full[0]),
      .port0_ingress_fifo_level (ingress_fifo_level[0]),
      .port0_egress_srst        (egress_srst[0]),
      .port0_egress_clk         (egress_clk[0]),
      .port0_egress_write       (egress_write[0]),
      .port0_egress_data        (egress_data[0]),
      .port0_egress_fifo_level  (egress_fifo_level[0]),

      .port1_ingress_srst       (ingress_srst[2]),
      .port1_ingress_clk        (ingress_clk[2]),
      .port1_ingress_write      (ingress_write[2]),
      .port1_ingress_data       (ingress_data[2]),
      .port1_ingress_full       (ingress_full[2]),
      .port1_ingress_fifo_level (ingress_fifo_level[2]),
      .port1_egress_srst        (egress_srst[2]),
      .port1_egress_clk         (egress_clk[2]),
      .port1_egress_write       (egress_write[2]),
      .port1_egress_data        (egress_data[2]),
      .port1_egress_fifo_level  (egress_fifo_level[2]),

      .port2_ingress_srst       (ingress_srst[4]),
      .port2_ingress_clk        (ingress_clk[4]),
      .port2_ingress_write      (ingress_write[4]),
      .port2_ingress_data       (ingress_data[4]),
      .port2_ingress_full       (ingress_full[4]),
      .port2_ingress_fifo_level (ingress_fifo_level[4]),
      .port2_egress_srst        (egress_srst[4]),
      .port2_egress_clk         (egress_clk[4]),
      .port2_egress_write       (egress_write[4]),
      .port2_egress_data        (egress_data[4]),
      .port2_egress_fifo_level  (egress_fifo_level[4]),

      .port3_ingress_srst       (ingress_srst[6]),
      .port3_ingress_clk        (ingress_clk[6]),
      .port3_ingress_write      (ingress_write[6]),
      .port3_ingress_data       (ingress_data[6]),
      .port3_ingress_full       (ingress_full[6]),
      .port3_ingress_fifo_level (ingress_fifo_level[6]),
      .port3_egress_srst        (egress_srst[6]),
      .port3_egress_clk         (egress_clk[6]),
      .port3_egress_write       (egress_write[6]),
      .port3_egress_data        (egress_data[6]),
      .port3_egress_fifo_level  (egress_fifo_level[6]),

      .port4_ingress_srst       (ingress_srst[8]),
      .port4_ingress_clk        (ingress_clk[8]),
      .port4_ingress_write      (ingress_write[8]),
      .port4_ingress_data       (ingress_data[8]),
      .port4_ingress_full       (ingress_full[8]),
      .port4_ingress_fifo_level (ingress_fifo_level[8]),
      .port4_egress_srst        (egress_srst[8]),
      .port4_egress_clk         (egress_clk[8]),
      .port4_egress_write       (egress_write[8]),
      .port4_egress_data        (egress_data[8]),
      .port4_egress_fifo_level  (egress_fifo_level[8])
   );

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
   hynoc_router_5p_inst_1
   (
      .router_clk               (router_clk),
      .router_srst              (router_srst),

      .port0_ingress_srst       (ingress_srst[1]),
      .port0_ingress_clk        (ingress_clk[1]),
      .port0_ingress_write      (ingress_write[1]),
      .port0_ingress_data       (ingress_data[1]),
      .port0_ingress_full       (ingress_full[1]),
      .port0_ingress_fifo_level (ingress_fifo_level[1]),
      .port0_egress_srst        (egress_srst[1]),
      .port0_egress_clk         (egress_clk[1]),
      .port0_egress_write       (egress_write[1]),
      .port0_egress_data        (egress_data[1]),
      .port0_egress_fifo_level  (egress_fifo_level[1]),

      .port1_ingress_srst       (ingress_srst[3]),
      .port1_ingress_clk        (ingress_clk[3]),
      .port1_ingress_write      (ingress_write[3]),
      .port1_ingress_data       (ingress_data[3]),
      .port1_ingress_full       (ingress_full[3]),
      .port1_ingress_fifo_level (ingress_fifo_level[3]),
      .port1_egress_srst        (egress_srst[3]),
      .port1_egress_clk         (egress_clk[3]),
      .port1_egress_write       (egress_write[3]),
      .port1_egress_data        (egress_data[3]),
      .port1_egress_fifo_level  (egress_fifo_level[3]),

      .port2_ingress_srst       (ingress_srst[5]),
      .port2_ingress_clk        (ingress_clk[5]),
      .port2_ingress_write      (ingress_write[5]),
      .port2_ingress_data       (ingress_data[5]),
      .port2_ingress_full       (ingress_full[5]),
      .port2_ingress_fifo_level (ingress_fifo_level[5]),
      .port2_egress_srst        (egress_srst[5]),
      .port2_egress_clk         (egress_clk[5]),
      .port2_egress_write       (egress_write[5]),
      .port2_egress_data        (egress_data[5]),
      .port2_egress_fifo_level  (egress_fifo_level[5]),

      .port3_ingress_srst       (ingress_srst[7]),
      .port3_ingress_clk        (ingress_clk[7]),
      .port3_ingress_write      (ingress_write[7]),
      .port3_ingress_data       (ingress_data[7]),
      .port3_ingress_full       (ingress_full[7]),
      .port3_ingress_fifo_level (ingress_fifo_level[7]),
      .port3_egress_srst        (egress_srst[7]),
      .port3_egress_clk         (egress_clk[7]),
      .port3_egress_write       (egress_write[7]),
      .port3_egress_data        (egress_data[7]),
      .port3_egress_fifo_level  (egress_fifo_level[7]),

      .port4_ingress_srst       (ingress_srst[9]),
      .port4_ingress_clk        (ingress_clk[9]),
      .port4_ingress_write      (ingress_write[9]),
      .port4_ingress_data       (ingress_data[9]),
      .port4_ingress_full       (ingress_full[9]),
      .port4_ingress_fifo_level (ingress_fifo_level[9]),
      .port4_egress_srst        (egress_srst[9]),
      .port4_egress_clk         (egress_clk[9]),
      .port4_egress_write       (egress_write[9]),
      .port4_egress_data        (egress_data[9]),
      .port4_egress_fifo_level  (egress_fifo_level[9])
   );

   //----------------------------------------------------------------
   // Local interfaces
   //----------------------------------------------------------------
   generate
      for(i=0; i<8; i=i+1) begin: gen_li_wires
         hynoc_local_interface
         #(
            .LOG2_FIFO_DEPTH (LOG2_FIFO_DEPTH),
            .FLIT_WIDTH      (FLIT_WIDTH),
            .SINGLE_CLOCK    (SINGLE_CLOCK_ROUTER)
         )
         hynoc_local_interface_inst
         (
            .port_ingress_srst        (ingress_srst[i]),
            .port_ingress_clk         (ingress_clk[i]),
            .port_ingress_write       (ingress_write[i]),
            .port_ingress_data        (ingress_data[i]),
            .port_ingress_full        (ingress_full[i]),
            .port_ingress_fifo_level  (ingress_fifo_level[i]),
            .port_egress_srst         (egress_srst[i]),
            .port_egress_clk          (egress_clk[i]),
            .port_egress_write        (egress_write[i]),
            .port_egress_data         (egress_data[i]),
            .port_egress_fifo_level   (egress_fifo_level[i]),
            .local_clk                (local_clk[i]),
            .local_srst               (local_srst[i]),
            .local_ingress_write      (local_ingress_write[i]),
            .local_ingress_data       (local_ingress_data[i]),
            .local_ingress_full       (local_ingress_full[i]),
            .local_ingress_fifo_level (local_ingress_fifo_level[i]),
            .local_egress_read        (local_egress_read[i]),
            .local_egress_data        (local_egress_data[i]),
            .local_egress_empty       (local_egress_empty[i]),
            .local_egress_fifo_level  (local_egress_fifo_level[i])
         );
      end
   endgenerate


   generate
      for(i=0; i<8; i=i+1) begin: gen_streamer

         //----------------------------------------------------------------
         // Stream Writer
         //----------------------------------------------------------------
         hynoc_stream_writer
         #(
            .WRITER_CHECKER_ID   (i),
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
            .address_flits            (writer_address_flits[i]),
            .address_sent             (writer_address_sent[i]),
            .packet_sent              (writer_packet_sent[i]),
            .all_packets_sent         (writer_all_packets_sent[i]),
            .local_clk                (local_clk[i]),
            .local_srst               (local_srst[i]),
            .local_ingress_write      (local_ingress_write[i]),
            .local_ingress_data       (local_ingress_data[i]),
            .local_ingress_fifo_level (local_ingress_fifo_level[i])
          );

         //----------------------------------------------------------------
         // Stream Reader
         //----------------------------------------------------------------
         hynoc_stream_reader
         #(
            .READER_CHECKER_ID   (i),
            .WRITER_CHECKER_ID   (7-i),
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
         hynoc_stream_reader_inst
         (
            .packet_received         (reader_packet_received[i]),
            .all_packets_received    (reader_all_packets_received[i]),
            .local_clk               (local_clk[i]),
            .local_srst              (local_srst[i]),
            .local_egress_read       (local_egress_read[i]),
            .local_egress_data       (local_egress_data[i]),
            .local_egress_fifo_level (local_egress_fifo_level[i])
         );

      end
   endgenerate


   //----------------------------------------------------------------
   // Topology
   //----------------------------------------------------------------
   // The router is wired as follow:
   //
   //  W(0)R(0)<-->LI0<---------.                   .--------->LI7<--> W(7)R(7)
   //                           |                   |
   //                    R0     ↓            R1     ↓
   //                    .-------------.    .-------------.
   //                    |      P0     |    |      P3  P2 |<-->LI5<--> W(5)R(5)
   //                    |             |    |             |
   // W(2)R(2)<-->LI2<-->| P1       P4 |<-->| P4       P1 |<-->LI3<--> W(3)R(3)
   //                    |             |    |             |
   // W(4)R(4)<-->LI4<-->| P2   P3     |    |      P0     |
   //                    '-------------'    '-------------'
   //                           ↑                   ↑
   //                           |                   |
   // W(6)R(6)<-->LI6<----------'                   '--------->LI1<--> W(1)R(1)
   //
   // W(x) is hynoc_stream_writer_inst_x
   // R(x) is hynoc_stream_reader_inst_x
   // LIx: hynoc_local_interface_inst_x
   // R0: hynoc_router_5p_inst_0
   // R1: hynoc_router_5p_inst_1

   assign ingress_srst[8]      = egress_srst[9];
   assign ingress_clk[8]       = egress_clk[9];
   assign ingress_write[8]     = egress_write[9];
   assign ingress_data[8]      = egress_data[9];
   assign egress_fifo_level[9] = ingress_fifo_level[8];

   assign ingress_srst[9]      = egress_srst[8];
   assign ingress_clk[9]       = egress_clk[8];
   assign ingress_write[9]     = egress_write[8];
   assign ingress_data[9]      = egress_data[8];
   assign egress_fifo_level[8] = ingress_fifo_level[9];


   //----------------------------------------------------------------
   // Test Vectors
   //----------------------------------------------------------------
   initial begin
      //LI0 to LI7
      writer_address_flits[0] = {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH,
                                 28'b00_00_00_00_00_00_00_00_00_00_11_11_0001};
      //LI2 to LI5
      writer_address_flits[2] = {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH,
                                 28'b00_00_00_00_00_00_00_00_00_00_10_10_0001};
      //LI4 to LI3
      writer_address_flits[4] = {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH,
                                 28'b00_00_00_00_00_00_00_00_00_00_01_01_0001};
      //LI6 to LI1
      writer_address_flits[6] = {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH,
                                 28'b00_00_00_00_00_00_00_00_00_00_00_00_0001};

      //LI7 to LI0
      writer_address_flits[1] = {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH,
                                 28'b00_00_00_00_00_00_00_00_00_00_11_11_0001};
      //LI5 to LI2
      writer_address_flits[3] = {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH,
                                 28'b00_00_00_00_00_00_00_00_00_00_10_10_0001};
      //LI3 to LI4
      writer_address_flits[5] = {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH,
                                 28'b00_00_00_00_00_00_00_00_00_00_01_01_0001};
      //LI1 to LI6
      writer_address_flits[7] = {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH,
                                 28'b00_00_00_00_00_00_00_00_00_00_00_00_0001};
   end

   initial begin
      fork
         wait(writer_all_packets_sent == 8'b11111111);
         wait(reader_all_packets_received == 8'b11111111);
      join
      $finish;
   end




endmodule
