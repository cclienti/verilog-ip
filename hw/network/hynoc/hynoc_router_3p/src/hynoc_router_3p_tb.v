//                              -*- Mode: Verilog -*-
// Filename        : hynoc_router_3p_tb.v
// Description     : Testbench of the three ports router
// Author          : Christophe Clienti
// Created On      : Sat Feb 22 14:41:44 2020
// Last Modified By: Christophe
// Last Modified On: Sat Feb 22 14:41:44 2020
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module hynoc_router_3p_tb;

   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------
`include "../../hynoc_ingress/src/hynoc_ingress_routing_list.v"

   localparam integer INDEX_WIDTH          = 5;
   localparam integer LOG2_FIFO_DEPTH      = 5;
   localparam integer PAYLOAD_WIDTH        = 32;
   localparam integer FLIT_WIDTH           = (PAYLOAD_WIDTH+1);
   localparam integer PRRA_PIPELINE        = 0;
   localparam integer SINGLE_CLOCK_ROUTER  = 0;
   localparam integer ENABLE_MCAST_ROUTING = 1;

   localparam integer NUM_ROUTERS     = 2;
   localparam integer NUM_LOCAL_XFCES = 4;

   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------
   reg arst;

   // Routers
   reg                      router_clk;
   reg                      router_srst;

   wire                     port0_ingress_srst       [NUM_ROUTERS-1:0];
   wire                     port0_ingress_clk        [NUM_ROUTERS-1:0];
   wire                     port0_ingress_write      [NUM_ROUTERS-1:0];
   wire [FLIT_WIDTH-1:0]    port0_ingress_data       [NUM_ROUTERS-1:0];
   wire                     port0_ingress_full       [NUM_ROUTERS-1:0];
   wire [LOG2_FIFO_DEPTH:0] port0_ingress_fifo_level [NUM_ROUTERS-1:0];
   wire                     port0_egress_srst        [NUM_ROUTERS-1:0];
   wire                     port0_egress_clk         [NUM_ROUTERS-1:0];
   wire                     port0_egress_write       [NUM_ROUTERS-1:0];
   wire [FLIT_WIDTH-1:0]    port0_egress_data        [NUM_ROUTERS-1:0];
   wire [LOG2_FIFO_DEPTH:0] port0_egress_fifo_level  [NUM_ROUTERS-1:0];

   wire                     port1_ingress_srst       [NUM_ROUTERS-1:0];
   wire                     port1_ingress_clk        [NUM_ROUTERS-1:0];
   wire                     port1_ingress_write      [NUM_ROUTERS-1:0];
   wire [FLIT_WIDTH-1:0]    port1_ingress_data       [NUM_ROUTERS-1:0];
   wire                     port1_ingress_full       [NUM_ROUTERS-1:0];
   wire [LOG2_FIFO_DEPTH:0] port1_ingress_fifo_level [NUM_ROUTERS-1:0];
   wire                     port1_egress_srst        [NUM_ROUTERS-1:0];
   wire                     port1_egress_clk         [NUM_ROUTERS-1:0];
   wire                     port1_egress_write       [NUM_ROUTERS-1:0];
   wire [FLIT_WIDTH-1:0]    port1_egress_data        [NUM_ROUTERS-1:0];
   wire [LOG2_FIFO_DEPTH:0] port1_egress_fifo_level  [NUM_ROUTERS-1:0];

   wire                     port2_ingress_srst       [NUM_ROUTERS-1:0];
   wire                     port2_ingress_clk        [NUM_ROUTERS-1:0];
   wire                     port2_ingress_write      [NUM_ROUTERS-1:0];
   wire [FLIT_WIDTH-1:0]    port2_ingress_data       [NUM_ROUTERS-1:0];
   wire                     port2_ingress_full       [NUM_ROUTERS-1:0];
   wire [LOG2_FIFO_DEPTH:0] port2_ingress_fifo_level [NUM_ROUTERS-1:0];
   wire                     port2_egress_srst        [NUM_ROUTERS-1:0];
   wire                     port2_egress_clk         [NUM_ROUTERS-1:0];
   wire                     port2_egress_write       [NUM_ROUTERS-1:0];
   wire [FLIT_WIDTH-1:0]    port2_egress_data        [NUM_ROUTERS-1:0];
   wire [LOG2_FIFO_DEPTH:0] port2_egress_fifo_level  [NUM_ROUTERS-1:0];

   // Local interfaces
   wire                     li_port_ingress_srst       [NUM_LOCAL_XFCES-1:0];
   wire                     li_port_ingress_clk        [NUM_LOCAL_XFCES-1:0];
   wire                     li_port_ingress_write      [NUM_LOCAL_XFCES-1:0];
   wire [FLIT_WIDTH-1:0]    li_port_ingress_data       [NUM_LOCAL_XFCES-1:0];
   wire                     li_port_ingress_full       [NUM_LOCAL_XFCES-1:0];
   wire [LOG2_FIFO_DEPTH:0] li_port_ingress_fifo_level [NUM_LOCAL_XFCES-1:0];
   wire                     li_port_egress_srst        [NUM_LOCAL_XFCES-1:0];
   wire                     li_port_egress_clk         [NUM_LOCAL_XFCES-1:0];
   wire                     li_port_egress_write       [NUM_LOCAL_XFCES-1:0];
   wire [FLIT_WIDTH-1:0]    li_port_egress_data        [NUM_LOCAL_XFCES-1:0];
   wire [LOG2_FIFO_DEPTH:0] li_port_egress_fifo_level  [NUM_LOCAL_XFCES-1:0];
   reg                      local_clk                  [NUM_LOCAL_XFCES-1:0];
   reg                      local_srst                 [NUM_LOCAL_XFCES-1:0];
   reg                      local_ingress_write        [NUM_LOCAL_XFCES-1:0];
   reg [FLIT_WIDTH-1:0]     local_ingress_data         [NUM_LOCAL_XFCES-1:0];
   wire                     local_ingress_full         [NUM_LOCAL_XFCES-1:0];
   wire [LOG2_FIFO_DEPTH:0] local_ingress_fifo_level   [NUM_LOCAL_XFCES-1:0];
   wire                     local_egress_read          [NUM_LOCAL_XFCES-1:0];
   wire [FLIT_WIDTH-1:0]    local_egress_data          [NUM_LOCAL_XFCES-1:0];
   wire                     local_egress_empty         [NUM_LOCAL_XFCES-1:0];
   wire [LOG2_FIFO_DEPTH:0] local_egress_fifo_level    [NUM_LOCAL_XFCES-1:0];


   //----------------------------------------------------------------
   // Value Change Dump
   //----------------------------------------------------------------

   initial begin
      $dumpfile ("hynoc_router_3p_tb.vcd");
      $dumpvars;
   end


   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------

   genvar rindex;
   generate
      // Instantiate routers
      for (rindex = 0; rindex < NUM_ROUTERS; rindex = rindex + 1) begin: GEN_ROUTERS
         hynoc_router_3p #(.INDEX_WIDTH          (INDEX_WIDTH),
                           .LOG2_FIFO_DEPTH      (LOG2_FIFO_DEPTH),
                           .PAYLOAD_WIDTH        (PAYLOAD_WIDTH),
                           .FLIT_WIDTH           (FLIT_WIDTH),
                           .PRRA_PIPELINE        (PRRA_PIPELINE),
                           .SINGLE_CLOCK_ROUTER  (SINGLE_CLOCK_ROUTER),
                           .ENABLE_MCAST_ROUTING (ENABLE_MCAST_ROUTING))

         hynoc_router_3p_inst (.router_clk               (router_clk),
                               .router_srst              (router_srst),
                               .port0_ingress_srst       (port0_ingress_srst[rindex]),
                               .port0_ingress_clk        (port0_ingress_clk[rindex]),
                               .port0_ingress_write      (port0_ingress_write[rindex]),
                               .port0_ingress_data       (port0_ingress_data[rindex]),
                               .port0_ingress_full       (port0_ingress_full[rindex]),
                               .port0_ingress_fifo_level (port0_ingress_fifo_level[rindex]),
                               .port0_egress_srst        (port0_egress_srst[rindex]),
                               .port0_egress_clk         (port0_egress_clk[rindex]),
                               .port0_egress_write       (port0_egress_write[rindex]),
                               .port0_egress_data        (port0_egress_data[rindex]),
                               .port0_egress_fifo_level  (port0_egress_fifo_level[rindex]),
                               .port1_ingress_srst       (port1_ingress_srst[rindex]),
                               .port1_ingress_clk        (port1_ingress_clk[rindex]),
                               .port1_ingress_write      (port1_ingress_write[rindex]),
                               .port1_ingress_data       (port1_ingress_data[rindex]),
                               .port1_ingress_full       (port1_ingress_full[rindex]),
                               .port1_ingress_fifo_level (port1_ingress_fifo_level[rindex]),
                               .port1_egress_srst        (port1_egress_srst[rindex]),
                               .port1_egress_clk         (port1_egress_clk[rindex]),
                               .port1_egress_write       (port1_egress_write[rindex]),
                               .port1_egress_data        (port1_egress_data[rindex]),
                               .port1_egress_fifo_level  (port1_egress_fifo_level[rindex]),
                               .port2_ingress_srst       (port2_ingress_srst[rindex]),
                               .port2_ingress_clk        (port2_ingress_clk[rindex]),
                               .port2_ingress_write      (port2_ingress_write[rindex]),
                               .port2_ingress_data       (port2_ingress_data[rindex]),
                               .port2_ingress_full       (port2_ingress_full[rindex]),
                               .port2_ingress_fifo_level (port2_ingress_fifo_level[rindex]),
                               .port2_egress_srst        (port2_egress_srst[rindex]),
                               .port2_egress_clk         (port2_egress_clk[rindex]),
                               .port2_egress_write       (port2_egress_write[rindex]),
                               .port2_egress_data        (port2_egress_data[rindex]),
                               .port2_egress_fifo_level  (port2_egress_fifo_level[rindex]));
      end
   endgenerate


   //----------------------------------------------------------------
   // Clock and reset generation
   //----------------------------------------------------------------

   initial begin
      router_clk  = 0;
      arst        = 1;
      #10.2 arst  = 1;
      #13.4 arst  = 0;
   end

   always
     #4 router_clk = !router_clk;

   always @(posedge router_clk) begin
      router_srst <= arst;
   end


   //----------------------------------------------------------------
   // Network topology
   //----------------------------------------------------------------

   //
   //             .-------------.    .-------------.
   //             |   Router 0  |    |   Router 1  |
   //             |             |    |             |
   // Local 0 <-->| P0       P2 |<-->| P0       P2 |<--> Local 3
   //             |             |    |             |
   //             |      P1     |    |     P1      |
   //             '-------------'    '-------------'
   //                    ↑                  ↑
   //                    ↓                  ↓
   //                 Local 1            Local 2
   //

`define ROUTER_CONNECT_HALF(SRC_ROUTER, SRC_PORT, DST_ROUTER, DST_PORT) \
   assign DST_PORT``_ingress_srst[DST_ROUTER]      = SRC_PORT``_egress_srst[SRC_ROUTER]; \
   assign DST_PORT``_ingress_clk[DST_ROUTER]       = SRC_PORT``_egress_clk[SRC_ROUTER]; \
   assign DST_PORT``_ingress_write[DST_ROUTER]     = SRC_PORT``_egress_write[SRC_ROUTER]; \
   assign DST_PORT``_ingress_data[DST_ROUTER]      = SRC_PORT``_egress_data[SRC_ROUTER]; \
   assign SRC_PORT``_egress_fifo_level[SRC_ROUTER] = DST_PORT``_ingress_fifo_level[DST_ROUTER]

`define ROUTER_CONNECT_FULL(ROUTER_A, PORT_X, ROUTER_B, PORT_Y) \
   `ROUTER_CONNECT_HALF(ROUTER_A, PORT_X, ROUTER_B, PORT_Y); \
   `ROUTER_CONNECT_HALF(ROUTER_B, PORT_Y, ROUTER_A, PORT_X)

   // Router 0 (P2) <--> Router 1 (P0)
   `ROUTER_CONNECT_FULL(0, port2, 1, port0);


   //----------------------------------------------------------------
   // Local interfaces
   //----------------------------------------------------------------

   genvar lindex;
   generate
      // Instantiate local interfaces
      for (lindex = 0; lindex < NUM_LOCAL_XFCES; lindex = lindex + 1) begin: GEN_LOCAL_XFCES
         hynoc_local_interface #(.LOG2_FIFO_DEPTH (LOG2_FIFO_DEPTH),
                                 .FLIT_WIDTH      (FLIT_WIDTH),
                                 .SINGLE_CLOCK    (SINGLE_CLOCK_ROUTER))
         hynoc_local_interface_inst (.port_ingress_srst        (li_port_ingress_srst[lindex]),
                                     .port_ingress_clk         (li_port_ingress_clk[lindex]),
                                     .port_ingress_write       (li_port_ingress_write[lindex]),
                                     .port_ingress_data        (li_port_ingress_data[lindex]),
                                     .port_ingress_full        (li_port_ingress_full[lindex]),
                                     .port_ingress_fifo_level  (li_port_ingress_fifo_level[lindex]),
                                     .port_egress_srst         (li_port_egress_srst[lindex]),
                                     .port_egress_clk          (li_port_egress_clk[lindex]),
                                     .port_egress_write        (li_port_egress_write[lindex]),
                                     .port_egress_data         (li_port_egress_data[lindex]),
                                     .port_egress_fifo_level   (li_port_egress_fifo_level[lindex]),
                                     .local_clk                (local_clk[lindex]),
                                     .local_srst               (local_srst[lindex]),
                                     .local_ingress_write      (local_ingress_write[lindex]),
                                     .local_ingress_data       (local_ingress_data[lindex]),
                                     .local_ingress_full       (local_ingress_full[lindex]),
                                     .local_ingress_fifo_level (local_ingress_fifo_level[lindex]),
                                     .local_egress_read        (local_egress_read[lindex]),
                                     .local_egress_data        (local_egress_data[lindex]),
                                     .local_egress_empty       (local_egress_empty[lindex]),
                                     .local_egress_fifo_level  (local_egress_fifo_level[lindex]));

         initial begin
            local_clk[lindex] = 0;
         end

         always @(posedge local_clk[lindex]) begin
            local_srst[lindex] <= arst;
         end

         always begin
           #(lindex+3) local_clk[lindex] = !local_clk[lindex];
         end

         local_reader #(.LOCAL_ID      (lindex),
                        .PAYLOAD_WIDTH (PAYLOAD_WIDTH),
                        .FLIT_WIDTH    (FLIT_WIDTH))
         local_reader_inst (.clk   (local_clk[lindex]),
                            .srst  (local_srst[lindex]),
                            .read  (local_egress_read[lindex]),
                            .empty (local_egress_empty[lindex]),
                            .data  (local_egress_data[lindex]));
     end
   endgenerate


   //----------------------------------------------------------------
   // Connect Local interfaces
   //----------------------------------------------------------------

`define LOCAL_CONNECT(LOCAL_ID, LOCAL_PORT, ROUTER_ID, ROUTER_PORT)                                 \
   assign ROUTER_PORT``_ingress_clk[ROUTER_ID]       = LOCAL_PORT``_ingress_clk[LOCAL_ID];          \
   assign ROUTER_PORT``_ingress_srst[ROUTER_ID]      = LOCAL_PORT``_ingress_srst[LOCAL_ID];         \
   assign ROUTER_PORT``_ingress_write[ROUTER_ID]     = LOCAL_PORT``_ingress_write[LOCAL_ID];        \
   assign ROUTER_PORT``_ingress_data[ROUTER_ID]      = LOCAL_PORT``_ingress_data[LOCAL_ID];         \
   assign LOCAL_PORT``_ingress_full[LOCAL_ID]        = ROUTER_PORT``_ingress_full[ROUTER_ID];       \
   assign LOCAL_PORT``_ingress_fifo_level[LOCAL_ID]  = ROUTER_PORT``_ingress_fifo_level[ROUTER_ID]; \
   assign LOCAL_PORT``_egress_clk[LOCAL_ID]          = ROUTER_PORT``_egress_clk[ROUTER_ID];         \
   assign LOCAL_PORT``_egress_srst[LOCAL_ID]         = ROUTER_PORT``_egress_srst[ROUTER_ID];        \
   assign LOCAL_PORT``_egress_write[LOCAL_ID]        = ROUTER_PORT``_egress_write[ROUTER_ID];       \
   assign LOCAL_PORT``_egress_data[LOCAL_ID]         = ROUTER_PORT``_egress_data[ROUTER_ID];        \
   assign ROUTER_PORT``_egress_fifo_level[ROUTER_ID] = LOCAL_PORT``_egress_fifo_level[LOCAL_ID]

   // Local 0 <--> Router 0 (P0)
   `LOCAL_CONNECT(0, li_port, 0, port0);

   // Local 1 <--> Router 0 (P1)
   `LOCAL_CONNECT(1, li_port, 0, port1);

   // Local 2 <--> Router 1 (P1)
   `LOCAL_CONNECT(2, li_port, 1, port1);

   // Local 3 <--> Router 1 (P2)
   `LOCAL_CONNECT(3, li_port, 1, port2);


   //----------------------------------------------------------------
   // Helpers
   //----------------------------------------------------------------

   task automatic send_init(input integer local_id);
      begin
         $display("Init local interface %0d", local_id);
         local_ingress_write[local_id] = 0;
         local_ingress_data[local_id]  = 0;

         while (local_srst[local_id] === 1'bx) begin
            @(posedge local_clk[local_id]);
         end

         while (local_srst[local_id] == 1'b1) begin
            @(posedge local_clk[local_id]);
         end

         $display("Init local interface %0d done", local_id);
      end
   endtask

   task automatic send_flit(input integer local_id,
                            input reg [FLIT_WIDTH-1:0] flit);
      begin
         local_ingress_write[local_id] <= 1'b1;
         local_ingress_data[local_id] <= flit;

         @(posedge local_clk[local_id]);
         while (local_ingress_full[local_id] == 1'b1)
           @(posedge local_clk[local_id]);

         local_ingress_write[local_id] <= 1'b0;
      end
   endtask

   task automatic send_packet(input integer local_id,
                              input reg [PAYLOAD_WIDTH-1:0] address,
                              input integer num_payload_flits);
      integer flit_index;
      begin
         // Send address
         send_flit(local_id, {1'b0, address});

         // Send payload
         for (flit_index=0; flit_index<num_payload_flits-1; flit_index=flit_index+1) begin
            send_flit(local_id, {1'b0, local_id[15:0], flit_index[15:0]});
         end

         // Send last payload (ie close the channel with the last payload).
         send_flit(local_id, {1'b1, local_id[15:0], flit_index[15:0]});
      end
   endtask


   //----------------------------------------------------------------
   // Test vectors
   //----------------------------------------------------------------

   // P0 -> P1: 1'b0
   // P0 -> P2: 1'b1
   // P1 -> P2: 1'b0
   // P1 -> P0: 1'b1
   // P2 -> P0: 1'b0
   // P2 -> P1: 1'b1

   localparam [FLIT_WIDTH-1:0] UNICAST_L0_TO_L1 = {PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 23'd0, 5'h0};
   localparam [FLIT_WIDTH-1:0] UNICAST_L0_TO_L2 = {PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 23'd2, 5'h1};
   localparam [FLIT_WIDTH-1:0] UNICAST_L0_TO_L3 = {PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 23'd3, 5'h1};

   localparam [FLIT_WIDTH-1:0] UNICAST_L1_TO_L0 = {PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 23'd1, 5'h0};
   localparam [FLIT_WIDTH-1:0] UNICAST_L1_TO_L2 = {PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 23'd0, 5'h1};
   localparam [FLIT_WIDTH-1:0] UNICAST_L1_TO_L3 = {PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 23'd1, 5'h1};

   localparam [FLIT_WIDTH-1:0] UNICAST_L2_TO_L0 = {PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 23'd2, 5'h1};
   localparam [FLIT_WIDTH-1:0] UNICAST_L2_TO_L1 = {PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 23'd3, 5'h1};
   localparam [FLIT_WIDTH-1:0] UNICAST_L2_TO_L3 = {PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 23'd0, 5'h0};

   localparam [FLIT_WIDTH-1:0] UNICAST_L3_TO_L0 = {PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 23'd0, 5'h1};
   localparam [FLIT_WIDTH-1:0] UNICAST_L3_TO_L1 = {PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 23'd1, 5'h1};
   localparam [FLIT_WIDTH-1:0] UNICAST_L3_TO_L2 = {PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 23'd1, 5'h0};

   localparam [FLIT_WIDTH-1:0] MCAST_L0_TO_L2_L3 = {PROTO_ROUTING_MCAST_CIRCUIT_SWITCH, 1'b0,
                                                    22'b00_00_00_00_00_00_00_00_00_10_11, 5'h1};
   localparam [FLIT_WIDTH-1:0] MCAST_L3_TO_L0_L1 = {PROTO_ROUTING_MCAST_CIRCUIT_SWITCH, 1'b0,
                                                    22'b00_00_00_00_00_00_00_00_00_01_11, 5'h1};

   initial begin
      #15000;
      $finish;
   end

   // Local 0
   initial begin
      send_init(0);
      send_packet(0, UNICAST_L0_TO_L1, 127);
      send_packet(0, UNICAST_L0_TO_L2, 128);
      send_packet(0, UNICAST_L0_TO_L3, 129);
      send_packet(0, MCAST_L0_TO_L2_L3, 512);
   end

   // Local 1
   initial begin
      send_init(1);
      send_packet(1, UNICAST_L1_TO_L0, 127);
      send_packet(1, UNICAST_L1_TO_L2, 128);
      send_packet(1, UNICAST_L1_TO_L3, 129);
  end

   // Local 2
   initial begin
      send_init(2);
      send_packet(2, UNICAST_L2_TO_L0, 127);
      send_packet(2, UNICAST_L2_TO_L1, 128);
      send_packet(2, UNICAST_L2_TO_L3, 129);
  end

   // Local 3
   initial begin
      send_init(3);
      send_packet(3, UNICAST_L3_TO_L0, 127);
      send_packet(3, UNICAST_L3_TO_L1, 128);
      send_packet(3, UNICAST_L3_TO_L2, 129);
      send_packet(3, MCAST_L3_TO_L0_L1, 256);
  end

endmodule
