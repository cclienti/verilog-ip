//                              -*- Mode: Verilog -*-
// Filename        : outport.v
// Description     : Output part of a hynoc port
// Author          : Christophe Clienti
// Created On      : Fri Jun 21 09:10:01 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Fri Jun 21 09:10:01 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module hynoc_egress
  #(parameter integer NB_PORTS         = 5,  //nb ports in a router
    parameter integer LOG2_FIFO_DEPTH  = 5,  //ceil log2 depth of the ingress fifo
    parameter integer PAYLOAD_WIDTH    = 32, //payload WIDTH
    parameter integer PRRA_PIPELINE    = 0,  //PIPELINE the arbiter (one more cycle latency)
    parameter integer FLIT_WIDTH       = (PAYLOAD_WIDTH + 1), //payload + stop bit + ext
    parameter integer MUX_INPUT_WIDTH  = (NB_PORTS-1)*(FLIT_WIDTH))

   (output wire                      wsrst,
    output wire                      wclk,
    output reg                       wen,
    output reg [FLIT_WIDTH-1:0]      wdata,
    input wire [LOG2_FIFO_DEPTH:0]   wlevel,

    input wire                       router_srst,
    input wire                       router_clk,

    output reg [NB_PORTS-2:0]        to_ingress_grant,
    output reg [NB_PORTS-2:0]        to_ingress_afull,

    input wire [NB_PORTS-2:0]        from_ingress_request,
    input wire [NB_PORTS-2:0]        from_ingress_write,
    input wire [MUX_INPUT_WIDTH-1:0] from_ingress_data);

   localparam integer LOG2_PRRA_STATES = $clog2(NB_PORTS-1);
   localparam integer PRRA_WIDTH = NB_PORTS-1;

   //----------------------------------------------------------------
   // Constant checks
   //----------------------------------------------------------------

   initial begin
      if(FLIT_WIDTH < (PAYLOAD_WIDTH+1)) begin
         $display("FLIT_WIDTH (%0d) must be less than (PAYLOAD_WIDTH+1), PAYLOAD_WIDTH=%0d",
                FLIT_WIDTH, PAYLOAD_WIDTH);
         $finish;
      end
      if(MUX_INPUT_WIDTH != (NB_PORTS-1)*(FLIT_WIDTH)) begin
         $display("MUX_INPUT_WIDTH (%0d) must be equal to (NB_PORTS-1)*(FLIT_WIDTH), NB_PORTS=%0d, FLIT_WIDTH=%0d",
                MUX_INPUT_WIDTH, NB_PORTS, FLIT_WIDTH);
         $finish;
      end
      if((2**LOG2_PRRA_STATES) > (NB_PORTS-1)) begin
         $display("LOG2_PRRA_STATES (%0d) must be less or equal that clog2(NB_PORTS-1), NB_PORTS = %0d",
                LOG2_PRRA_STATES,NB_PORTS);
         $finish;
      end
   end


   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------

   wire [LOG2_PRRA_STATES-1:0] state;
   wire [PRRA_WIDTH-1:0]       grant;
   wire                        inprocess;


   //----------------------------------------------------------------
   // Parallel Round Robin Arbiter
   //----------------------------------------------------------------

   prra
   #(
      .WIDTH      (PRRA_WIDTH),
      .LOG2_WIDTH (LOG2_PRRA_STATES),
      .PIPELINE   (PRRA_PIPELINE)
   )
   prra_inst
   (
      .clk       (router_clk),
      .srst      (router_srst),
      .request   (from_ingress_request),
      .state     (state),
      .grant     (grant)
   );


   //----------------------------------------------------------------
   // Almost full management
   //----------------------------------------------------------------

   wire afull;

   assign afull = (wlevel >= 2**LOG2_FIFO_DEPTH-5) ? 1'b1 : 1'b0;

   always @(posedge router_clk) begin
      if(router_srst == 1'b1) begin
         to_ingress_afull <= 0;
      end
      else begin
         to_ingress_afull <= {PRRA_WIDTH{afull}} & grant;
      end
   end


   //----------------------------------------------------------------
   // Grant register
   //----------------------------------------------------------------

   // Pipeline to assert grant at the same time that to_ingress_afull

   always @(posedge router_clk) begin
      if(router_srst == 1'b1) begin
         to_ingress_grant <= 0;
      end else begin
         to_ingress_grant <= grant;
      end
   end

   //----------------------------------------------------------------
   // Assign fifo signals
   //----------------------------------------------------------------

   //clock and reset
   assign wsrst = router_srst;
   assign wclk  = router_clk;

   //wen and wdata mux
   wire [FLIT_WIDTH-1:0] data_mux_input [PRRA_WIDTH-1:0];

   genvar i;
   generate
      for(i=0; i<PRRA_WIDTH; i=i+1) begin: gen_data_mux_input
         assign data_mux_input[i] = from_ingress_data[(i+1)*(FLIT_WIDTH)-1:i*(FLIT_WIDTH)];
      end
   endgenerate

   //set when a request is in process
   assign inprocess = grant[state];

   // Register muxes
   always @(posedge router_clk) begin
      if(router_srst == 1'b1) begin
         wen   <= 1'b0;
         wdata <= 0;
      end
      else begin
         wen   <= from_ingress_write[state] & inprocess;
         wdata <= data_mux_input[state];
      end
   end

endmodule
