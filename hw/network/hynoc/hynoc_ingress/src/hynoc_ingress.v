//                              -*- Mode: Verilog -*-
// Filename        : hynoc_ingress.v
// Description     : Input part of a hynoc port
// Author          : Christophe Clienti
// Created On      : Fri Jun 21 09:10:01 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Fri Jun 21 09:10:01 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

//----------------------------------------------------------------
// Protocol: 1-bit sideband to parametrize the flit type:
//  [ 1 bit ][ payload_width bits ]
//  [   0   ][    standard flit   ]
//  [   1   ][      last flit     ]
//
// The first flits must be routing flits. Depending on the protocol,
// multiple routing filts can be sent, but only the first flit is
// interpreted by an ingress port of a router at a time:
//   [ 1 bit ][     payload_width bits         ]
//   [   0   ][ proto ][     routing flits     ]
//   [   0   ][ proto ][     routing flits     ]
//
// Proto is a 4-bit width field that defines the low level routing protocol:
// - circuit switch ucast:  4'b0000
// - circuit switch mcast:  4'b0001
// - XY routing:            4'b1111 (* not supported*)
//
// At emission, a packet is composed of one or more routing flits followed by
// at least one payload flit:
//   [ 1 bit ][  payload_width bits       ]
//   [   0   ][ 0001 ][ last routing flit ]
//   [   0   ][          payload          ]
//   [   1   ][        last payload       ]
//----------------------------------------------------------------

module hynoc_ingress
  #(parameter integer NB_PORTS             = 5,  //nb ports in a router
    parameter integer INDEX_WIDTH          = 4,  //width of header index
    parameter integer LOG2_FIFO_DEPTH      = 5,  //log2 depth of the ingress fifo
    parameter integer PAYLOAD_WIDTH        = 32, //payload width
    parameter integer FLIT_WIDTH           = PAYLOAD_WIDTH + 1, //payload + stop bit
    parameter integer SINGLE_CLOCK_PORT    = 0,  //wclk and router_clk are the same
    parameter integer ENABLE_MCAST_ROUTING = 1,  //enable multicast protocol
    parameter integer ENABLE_XY_ROUTING    = 1)  //enable XY protocol (not supported)

   (input wire                      wsrst,
    input wire                      wclk,
    input wire                      wen,
    input wire [FLIT_WIDTH-1:0]     wdata,
    output wire [LOG2_FIFO_DEPTH:0] wlevel,
    output wire                     wfull,

    input wire                      router_srst,
    input wire                      router_clk,
    input wire [NB_PORTS-2:0]       from_egress_grant,
    input wire [NB_PORTS-2:0]       from_egress_afull,

    output reg [NB_PORTS-2:0]       to_egress_request,
    output reg                      to_egress_write,
    output reg [FLIT_WIDTH-1:0]     to_egress_data);


   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------

`include "hynoc_ingress_routing_list.v"

   // FSM States
   localparam FETCH_HEADER   = 0;
   localparam CHECK_HEADER   = 1;
   localparam WAIT_GRANT     = 2;
   localparam PUSH_HEADER    = 3;
   localparam PUSH_START     = 4;
   localparam PUSH_DATA      = 5;
   localparam PUSH_ASTALL    = 6;
   localparam PUSH_STALL     = 7;
   localparam FLUSH_PACKET   = 8;


   //----------------------------------------------------------------
   // Check parameters
   //----------------------------------------------------------------

   initial begin
      if(FLIT_WIDTH < (PAYLOAD_WIDTH + 1)) begin
         $display("FLIT_WIDTH (%0d) must be greater or equal to (PAYLOAD_WIDTH + 1), PAYLOAD_WIDTH=%0d",
                  FLIT_WIDTH, PAYLOAD_WIDTH);
         $finish;
      end
   end


   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------

   reg                         request_reset;
   reg                         request_set;
   reg                         write;
   reg                         write_new_header;
   reg [3:0]                   fsm_comb, fsm_reg;

   reg                         ren;
   wire [FLIT_WIDTH-1:0]       rdata;
   wire                        rempty;
   wire [LOG2_FIFO_DEPTH:0]    rlevel;

   reg                         egress_afull;
   reg                         astall, stall;

   wire                        index_curr_zero;
   wire [FLIT_WIDTH-1:0]       header_index_decr;

   wire                        flit_stop_bit;
   wire [FLIT_PROTO_WIDTH-1:0] flit_proto_header;
   reg [FLIT_PROTO_WIDTH-1:0]  flit_proto_header_reg;

   wire                        accept_comb;
   reg                         accept_reg;

   reg                         check_new_header_write;
   reg                         proto_valid;

   wire                        ucast_new_header_write;
   wire [FLIT_WIDTH-1:0]       ucast_new_header;
   wire [NB_PORTS-2:0]         ucast_to_egress_request;

   wire                        mcast_new_header_write;
   wire [FLIT_WIDTH-1:0]       mcast_new_header;
   wire [NB_PORTS-2:0]         mcast_to_egress_request;


   //----------------------------------------------------------------
   // Input fifo
   //----------------------------------------------------------------

   generate
      if (SINGLE_CLOCK_PORT != 0) begin

         sclkfifolut
         #(
            .LOG2_FIFO_DEPTH (LOG2_FIFO_DEPTH),
            .FIFO_WIDTH      (FLIT_WIDTH)
         )
         sclkfifolut_inst
         (
            .clk    (router_clk),
            .srst   (router_srst),
            .level  (rlevel),
            .ren    (ren),
            .rdata  (rdata),
            .rempty (rempty),
            .wen    (wen),
            .wdata  (wdata),
            .wfull  (wfull)
         );

         assign wlevel = rlevel;

      end
      else begin

         dclkfifolut
         #(
            .LOG2_FIFO_DEPTH (LOG2_FIFO_DEPTH),
            .FIFO_WIDTH      (FLIT_WIDTH)
         )
         dclkfifolut_inst
         (
            .rsrst   (router_srst),
            .rclk    (router_clk),
            .ren     (ren),
            .rdata   (rdata),
            .rlevel  (rlevel),
            .rempty  (rempty),
            .wsrst   (wsrst),
            .wclk    (wclk),
            .wen     (wen),
            .wdata   (wdata),
            .wlevel  (wlevel),
            .wfull   (wfull)
         );

      end
   endgenerate

   //----------------------------------------------------------------
   // Egress full detection
   //----------------------------------------------------------------

   always @(*) begin
      egress_afull = ((from_egress_afull & to_egress_request) == to_egress_request) ? 1'b1: 1'b0;
   end


   //----------------------------------------------------------------
   // Stall detection
   //----------------------------------------------------------------

   always @(*) begin
      astall = (rlevel <= 1) | egress_afull;
   end

   always @(*) begin
      stall = rempty | egress_afull;
   end


   //----------------------------------------------------------------
   // Locate protocol bits
   //----------------------------------------------------------------

   assign flit_proto_header = rdata[PAYLOAD_WIDTH-1:PAYLOAD_WIDTH-FLIT_PROTO_WIDTH];
   assign flit_stop_bit     = rdata[PAYLOAD_WIDTH];


   //----------------------------------------------------------------
   // Routing type register
   //----------------------------------------------------------------

   always @(posedge router_clk) begin
      if(request_set == 1'b1) begin
         flit_proto_header_reg = flit_proto_header;
      end
   end


   //----------------------------------------------------------------
   // Routing laws
   //----------------------------------------------------------------

   hynoc_ingress_routing_ucast
   #(
      .NB_PORTS      (NB_PORTS),
      .INDEX_WIDTH   (INDEX_WIDTH),
      .PAYLOAD_WIDTH (PAYLOAD_WIDTH),
      .FLIT_WIDTH    (FLIT_WIDTH)
   )
   hynoc_ingress_routing_ucast_inst
   (
      .router_clk        (router_clk),
      .router_srst       (router_srst),
      .rdata             (rdata),
      .from_egress_grant (from_egress_grant),
      .new_header_write  (ucast_new_header_write),
      .new_header        (ucast_new_header),
      .to_egress_request (ucast_to_egress_request)
   );

   generate
      if (ENABLE_MCAST_ROUTING != 0) begin
         hynoc_ingress_routing_mcast
         #(
            .NB_PORTS      (NB_PORTS),
            .INDEX_WIDTH   (INDEX_WIDTH),
            .PAYLOAD_WIDTH (PAYLOAD_WIDTH),
            .FLIT_WIDTH    (FLIT_WIDTH)
         )
         hynoc_ingress_routing_mcast_inst
         (
            .router_clk        (router_clk),
            .router_srst       (router_srst),
            .rdata             (rdata),
            .from_egress_grant (from_egress_grant),
            .new_header_write  (mcast_new_header_write),
            .new_header        (mcast_new_header),
            .to_egress_request (mcast_to_egress_request)
         );
      end
   endgenerate

   //----------------------------------------------------------------
   // Check that the routing law is valid
   //----------------------------------------------------------------

   always @(*) begin
      if (flit_proto_header == PROTO_ROUTING_UCAST_CIRCUIT_SWITCH) begin
         proto_valid = 1'b1;
      end
      else if ((flit_proto_header == PROTO_ROUTING_MCAST_CIRCUIT_SWITCH) && (ENABLE_MCAST_ROUTING != 0)) begin
         proto_valid = 1'b1;
      end
      else begin
         proto_valid = 1'b0;
      end
   end


   //----------------------------------------------------------------
   // check new header write signal depending on the selected routing
   // law
   // ----------------------------------------------------------------

   always @(*) begin
      if (flit_proto_header == PROTO_ROUTING_UCAST_CIRCUIT_SWITCH) begin
         check_new_header_write = ucast_new_header_write;
      end
      else if ((flit_proto_header == PROTO_ROUTING_MCAST_CIRCUIT_SWITCH) && (ENABLE_MCAST_ROUTING != 0)) begin
         check_new_header_write = mcast_new_header_write;
      end
      else begin
         check_new_header_write = 1'b0;
      end
   end


   //----------------------------------------------------------------
   // Select to right request depending on selected routing law
   //----------------------------------------------------------------

   always @(posedge router_clk) begin
      if(request_reset == 1'b1) begin
         to_egress_request <= 0;
      end
      else begin
         if(request_set == 1'b1) begin
            if (flit_proto_header == PROTO_ROUTING_UCAST_CIRCUIT_SWITCH) begin
               to_egress_request <= ucast_to_egress_request;
            end
            else if ((flit_proto_header == PROTO_ROUTING_MCAST_CIRCUIT_SWITCH) && (ENABLE_MCAST_ROUTING != 0)) begin
               to_egress_request <= mcast_to_egress_request;
            end
         end
      end
   end


   //----------------------------------------------------------------
   // Register to egress
   //----------------------------------------------------------------

   always @(posedge router_clk) begin
      if(router_srst == 1'b1) begin
         to_egress_write <= 1'b0;
      end
      else begin
         to_egress_write <= write;
      end
   end

   always @(posedge router_clk) begin
      if(router_srst == 1'b1) begin
         to_egress_data  <= 0;
      end
      else begin
         if (write_new_header) begin
            if (flit_proto_header_reg == PROTO_ROUTING_UCAST_CIRCUIT_SWITCH) begin
               to_egress_data <= ucast_new_header;
            end
            else if ((flit_proto_header_reg == PROTO_ROUTING_MCAST_CIRCUIT_SWITCH) && (ENABLE_MCAST_ROUTING != 0)) begin
               to_egress_data <= mcast_new_header;
            end
         end
         else begin
            to_egress_data <= rdata;
         end
      end
   end


   //----------------------------------------------------------------
   // Request accept logic
   //----------------------------------------------------------------

   assign accept_comb = (from_egress_grant == to_egress_request) ? 1'b1 : 1'b0;

   always @(posedge router_clk) begin
      if (router_srst == 1'b1) begin
         accept_reg <= 1'b0;
      end
      else begin
         if(egress_afull == 1'b0) begin
            accept_reg <= accept_comb;
         end
      end
   end


   //----------------------------------------------------------------
   // FSM
   //----------------------------------------------------------------

   // FSM Register
   always @(posedge router_clk) begin
      if(router_srst == 1'b1) begin
         fsm_reg <= FETCH_HEADER;
      end
      else begin
         fsm_reg <= fsm_comb;
      end
   end

   //FSM Transitions
   always @(*) begin

      case(fsm_reg)
         CHECK_HEADER: begin
            if (flit_stop_bit == 1'b0) begin
               if(proto_valid == 1'b1) begin
                  fsm_comb = WAIT_GRANT;
               end
               else begin
                  fsm_comb = FLUSH_PACKET;
               end
            end
            else begin
               fsm_comb = FLUSH_PACKET;
            end
         end

         WAIT_GRANT: begin
            //wait for posedge on accept bit
            if((accept_comb == 1'b1) && (accept_reg == 1'b0) && (egress_afull == 1'b0)) begin
               if(check_new_header_write == 1'b0) begin
                  fsm_comb = PUSH_START;
               end
               else begin
                  fsm_comb = PUSH_HEADER;
               end
            end
            else begin
               fsm_comb = WAIT_GRANT;
            end
         end

         PUSH_HEADER: begin
            if(rempty == 1'b1) begin
               fsm_comb = PUSH_START;
            end
            else begin
               fsm_comb = PUSH_DATA;
            end
         end

         PUSH_START: begin
            if(rempty == 1'b1) begin
               fsm_comb = PUSH_START;
            end
            else begin
               if(astall == 1'b1) begin
                  fsm_comb = PUSH_ASTALL;
               end
               else begin
                  fsm_comb = PUSH_DATA;
               end
            end
         end

         PUSH_DATA: begin
            if(flit_stop_bit == 1'b0) begin
               if(astall == 1'b1) begin
                  fsm_comb = PUSH_ASTALL;
               end
               else begin
                  fsm_comb = PUSH_DATA;
               end
            end
            else begin
               // we received a close, but we must know if we have
               // already fetched or not the next packet flit
               if(rempty == 1'b1) begin
                  fsm_comb = FETCH_HEADER;
               end
               else begin
                  fsm_comb = CHECK_HEADER;
               end
            end
         end

         PUSH_ASTALL: begin
            if(flit_stop_bit == 1'b0) begin
               if(stall == 1'b1) begin
                  fsm_comb = PUSH_STALL;
               end
               else begin
                  fsm_comb = PUSH_START;
               end
            end
            else begin
               fsm_comb = FETCH_HEADER;
            end
         end

         PUSH_STALL: begin
            if(stall == 1'b1) begin
               fsm_comb = PUSH_STALL;
            end
            else begin
               fsm_comb = PUSH_START;
            end
         end

         FLUSH_PACKET: begin
            if(flit_stop_bit == 1'b0) begin
               fsm_comb = FLUSH_PACKET;
            end
            else begin
               // we received a close, but we must know if we have
               // already fetched or not the next packet flit
               if(rempty == 1'b1) begin
                  fsm_comb = FETCH_HEADER;
               end
               else begin
                  fsm_comb = CHECK_HEADER;
               end
            end
         end

         //FETCH HEADER
         default: begin
            if(rempty == 1'b1) begin
               fsm_comb = FETCH_HEADER;
            end
            else begin
               fsm_comb = CHECK_HEADER;
            end
         end
      endcase
   end


   // FSM Outputs
   always @(*) begin
      case(fsm_reg)
         CHECK_HEADER: begin
            request_reset      = 1'b1;
            request_set        = 1'b0;
            ren                = 1'b0;
            write              = 1'b0;
            write_new_header   = 1'b0;
         end

         WAIT_GRANT: begin
            request_reset      = 1'b0;
            request_set        = 1'b1;
            ren                = 1'b0;
            write              = 1'b0;
            write_new_header   = 1'b0;
         end

         PUSH_HEADER: begin
            request_reset      = 1'b0;
            request_set        = 1'b0;
            ren                = 1'b1;
            write              = 1'b1;
            write_new_header   = 1'b1;
         end

         PUSH_START: begin
            request_reset      = 1'b0;
            request_set        = 1'b0;
            ren                = 1'b1;
            write              = 1'b0;
            write_new_header   = 1'b0;
         end

         PUSH_DATA: begin
            request_reset      = 1'b0;
            request_set        = 1'b0;
            ren                = 1'b1;
            write              = 1'b1;
            write_new_header   = 1'b0;
         end

         PUSH_ASTALL: begin
            request_reset      = 1'b0;
            request_set        = 1'b0;
            ren                = 1'b0;
            write              = 1'b1;
            write_new_header   = 1'b0;
         end

         PUSH_STALL: begin
            request_reset      = 1'b0;
            request_set        = 1'b0;
            ren                = 1'b0;
            write              = 1'b0;
            write_new_header   = 1'b0;
         end

         FLUSH_PACKET: begin
            request_reset      = 1'b0;
            request_set        = 1'b0;
            ren                = 1'b1;
            write              = 1'b0;
            write_new_header   = 1'b0;
         end

         //FETCH HEADER
         default: begin
            request_reset      = 1'b1;
            request_set        = 1'b0;
            ren                = 1'b1;
            write              = 1'b0;
            write_new_header   = 1'b0;
         end
      endcase
   end


endmodule
