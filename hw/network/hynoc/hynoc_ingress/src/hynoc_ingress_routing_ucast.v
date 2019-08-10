//                              -*- Mode: Verilog -*-
// Filename        : hynoc_ingress_routing_ucast.v
// Description     : unicast routing module of ingress port
// Author          : Christophe
// Created On      : Sat May  7 08:25:46 2016
// Last Modified By: Christophe
// Last Modified On: Sat May  7 08:25:46 2016
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

//----------------------------------------------------------------
// Routing flit organization:
//
//   [           payload_width-4 bits        ]
//   [ GAP ][ HOP H-1 ] ... [ HOP 0 ][ Index ]
//
//  Hop width: clog2(nb_ports-1)
//----------------------------------------------------------------

module hynoc_ingress_routing_ucast
  #(parameter integer NB_PORTS        = 5,  //nb ports in a router
    parameter integer INDEX_WIDTH     = 4,  //width of header index
    parameter integer PAYLOAD_WIDTH   = 32, //payload width
    parameter integer FLIT_WIDTH      = PAYLOAD_WIDTH + 1) //flit width

   (input wire                   router_clk,
    input wire                   router_srst,
    input wire [FLIT_WIDTH-1:0]  rdata,
    input wire [NB_PORTS-2:0]    from_egress_grant,

    output reg                   new_header_write,
    output reg [FLIT_WIDTH-1:0]  new_header,
    output reg [NB_PORTS-2:0]    to_egress_request);


   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------

`include "hynoc_ingress_routing_list.v"

   localparam HOP_WIDTH           = $clog2(NB_PORTS-1);
   localparam DECODER_WIDTH       = 2**HOP_WIDTH;
   localparam NB_HOPS             = (PAYLOAD_WIDTH - INDEX_WIDTH - FLIT_PROTO_WIDTH) / HOP_WIDTH;
   localparam NB_HOPS_PADDING     = 2**INDEX_WIDTH;
   localparam EXTENSION_WIDTH     = FLIT_WIDTH - PAYLOAD_WIDTH - 1;


   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------

   wire [INDEX_WIDTH-1:0 ]  index_curr;
   wire [INDEX_WIDTH-1:0 ]  index_decr;

   wire [HOP_WIDTH-1:0]     hops [NB_HOPS_PADDING-1:0];
   wire [HOP_WIDTH-1:0]     hop;
   reg [DECODER_WIDTH-1:0]  request_decoder [DECODER_WIDTH-1:0];
   wire [NB_PORTS-2:0]      request_comb;

   wire new_header_write_comb;
   wire [FLIT_WIDTH-1:0]    new_header_comb;


   //----------------------------------------------------------------
   // Parameter checks
   //----------------------------------------------------------------

   initial begin
      if(((2**HOP_WIDTH) + 1) != NB_PORTS) begin
         $display("bad hop width or bad number of ports");
         $finish;
      end

      if ((FLIT_PROTO_WIDTH + INDEX_WIDTH + (NB_HOPS * HOP_WIDTH)) > PAYLOAD_WIDTH) begin
         $display("PAYLOAD_WIDTH does not match (%d): bad hop width (%d) or bad INDEX_WIDTH (%d) or bad number of ports (%d)",
                  PAYLOAD_WIDTH, HOP_WIDTH, INDEX_WIDTH, NB_PORTS);
         $finish;
      end

      if (EXTENSION_WIDTH < 0) begin
         $display("FLIT_WIDTH (%d) must be greater or equal to PAYLOAD_WIDTH (%d) + 1", FLIT_WIDTH, PAYLOAD_WIDTH);
         $finish;
      end
   end


   //----------------------------------------------------------------
   // Header Index Countdown
   //----------------------------------------------------------------

   assign index_curr = rdata[INDEX_WIDTH-1:0];
   assign index_decr = index_curr - 1;
   assign new_header_write_comb = (index_curr == 0) ? 1'b0 : 1'b1;
   assign new_header_comb = {rdata[FLIT_WIDTH-1:INDEX_WIDTH], index_decr};


   //----------------------------------------------------------------
   // Decode path: find the right egress port to send data
   //----------------------------------------------------------------
   genvar i;

   // convert hops flat bit vector to array
   generate
      for (i=0; i<NB_HOPS; i=i+1) begin: hop_select_input_mux
         assign hops[i] = rdata[(i+1)*HOP_WIDTH+INDEX_WIDTH-1 -: HOP_WIDTH];
      end
      if (NB_HOPS < NB_HOPS_PADDING) begin: hop_padding_test
         for (i=NB_HOPS; i<NB_HOPS_PADDING; i=i+1) begin: hop_padding
            assign hops[i] = 0;
         end
      end
   endgenerate

   // generate all decoded values
   integer decaddr, decval;

   initial begin
      for(decaddr=0; decaddr<DECODER_WIDTH; decaddr=decaddr+1) begin
         decval                    = 2**decaddr;
         request_decoder[decaddr]  = decval[DECODER_WIDTH-1:0];
      end
   end

   // Look for the current hop
   assign hop = hops[index_curr];

   // Decode the hop value to formulate the request
   assign request_comb = request_decoder[hop][NB_PORTS-2:0];


   //----------------------------------------------------------------
   // Outputs
   //----------------------------------------------------------------

   always @(*) begin
      new_header_write = new_header_write_comb;
   end

   always @(*) begin
      new_header = new_header_comb;
   end

   always @(*) begin
      to_egress_request = request_comb;
   end


endmodule
