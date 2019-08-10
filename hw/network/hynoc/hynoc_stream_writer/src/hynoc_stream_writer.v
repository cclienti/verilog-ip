//                              -*- Mode: Verilog -*-
// Filename        : hynoc_stream_writer.v
// Description     : generates stream to the noc
// Author          : Christophe
// Created On      : Sun Feb 23 15:39:20 2014
// Last Modified By: Christophe
// Last Modified On: Sun Feb 23 15:39:20 2014
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module hynoc_stream_writer
  #(parameter integer WRITER_CHECKER_ID   = 0,    //id used for logging
    parameter integer NB_ADDRESS_FLITS    = 1,    //number of address flit
    parameter integer FLIT_RANDOM_SEED    = 556,  //flit value random seed
    parameter integer NB_FLIT_RANDOM_SEED = 666,  //nb flit per packet random seed
    parameter integer NB_PACKETS          = 100,  //number of packets to send
    parameter integer MAX_NB_FLITS        = 1024, //max number of flit per packets
    parameter integer MAX_WAIT            = 1024, //max number of wait cycles between two packets
    parameter integer LOG2_FIFO_DEPTH     = 5,    //log2 depth of the ingress fifo
    parameter integer PAYLOAD_WIDTH       = 32,   //payload width
    parameter integer FLIT_WIDTH          = (PAYLOAD_WIDTH+1))

   (// address flit are passed dynamically
    input wire [NB_ADDRESS_FLITS*FLIT_WIDTH-1:0] address_flits,
    output reg                                   address_sent,
    output reg                                   packet_sent,
    output reg                                   all_packets_sent,

    // stream_writer clock
    input wire                                   local_clk,
    input wire                                   local_srst,

    // signals to be plugged to an ingress port
    output reg                                   local_ingress_write,
    output reg [FLIT_WIDTH-1:0]                  local_ingress_data,
    input wire [LOG2_FIFO_DEPTH:0]               local_ingress_fifo_level);

   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------
   localparam integer FIFO_LEVEL_MAX = 2**LOG2_FIFO_DEPTH-1;

   localparam FSM_IDLE         = 0;
   localparam FSM_START        = 1;
   localparam FSM_WAIT         = 2;
   localparam FSM_SEND_ADDR    = 3;
   localparam FSM_SEND_ID      = 4;
   localparam FSM_SEND_PAYLOAD = 5;
   localparam FSM_SEND_CLOSE   = 6;


   //----------------------------------------------------------------
   // Global variables
   //----------------------------------------------------------------
   integer seed = FLIT_RANDOM_SEED; // flit value seed
   integer nseed = NB_FLIT_RANDOM_SEED; // nb flits seed
   integer wseed = NB_FLIT_RANDOM_SEED+FLIT_RANDOM_SEED; // wait seed

   reg [PAYLOAD_WIDTH/2-1:0]                 packetid = 0; // packet identifier
   reg [PAYLOAD_WIDTH-(PAYLOAD_WIDTH/2)-1:0] writerid = WRITER_CHECKER_ID; //checker id

   reg [31:0] wait_reg;
   reg [31:0] nbaddr;
   reg [31:0] nbflits;
   reg [2:0]  fsm_reg;

   wire fifo_full;

   //----------------------------------------------------------------
   // Assign Address Array
   //----------------------------------------------------------------
   wire [FLIT_WIDTH-1:0] address_array [NB_ADDRESS_FLITS-1:0];

   genvar  i;
   generate
      for (i=0; i<NB_ADDRESS_FLITS; i=i+1) begin: gen_address_array
         assign address_array[i] = address_flits[(i+1)*FLIT_WIDTH-1:i*FLIT_WIDTH];
      end
   endgenerate


   //----------------------------------------------------------------
   // FSM
   //----------------------------------------------------------------
   assign fifo_full = local_ingress_fifo_level >= FIFO_LEVEL_MAX ? 1'b1: 1'b0;

   always @(posedge local_clk) begin
      if(local_srst == 1'b1) begin
         fsm_reg <= FSM_IDLE;
         local_ingress_write <= 1'b0;
         local_ingress_data <= 0;
         nbaddr <= 0;
         nbflits <= 0;
         wait_reg <= 0;
         packetid <= 0;
         all_packets_sent <= 1'b0;
         address_sent <= 1'b0;
         packet_sent <= 1'b0;
      end
      else begin
         case(fsm_reg)
            FSM_START: begin
               fsm_reg <= FSM_WAIT;
               local_ingress_write <= 1'b0;
               local_ingress_data <= 0;
               nbaddr <= 0;
               nbflits <= $unsigned($random(nseed)) % MAX_NB_FLITS + 1;
               wait_reg <= $unsigned($random(wseed)) % MAX_WAIT + 1;
            end

            FSM_WAIT: begin
               if(wait_reg == 0) begin
                  fsm_reg <= FSM_SEND_ADDR;
               end
               else begin
                  fsm_reg <= FSM_WAIT;
                  wait_reg <= wait_reg - 1'b1;
               end
            end

            FSM_SEND_ADDR: begin
               if(fifo_full == 1'b0) begin
                  local_ingress_data[PAYLOAD_WIDTH:0] <= address_array[nbaddr][PAYLOAD_WIDTH:0];
                  local_ingress_write <= 1'b1;
                  nbaddr <= nbaddr + 1'b1;

                  if(nbaddr == NB_ADDRESS_FLITS-1) begin
                     fsm_reg <= FSM_SEND_ID;
                     address_sent <= 1'b1;
                  end
                  else begin
                     fsm_reg <= FSM_SEND_ADDR;
                  end
               end
               else begin
                  local_ingress_write <= 1'b0;
               end
            end

            FSM_SEND_ID: begin
               address_sent <= 1'b0;
               if(fifo_full == 1'b0) begin
                  local_ingress_data[PAYLOAD_WIDTH:0] <= {1'b0, writerid, packetid};
                  local_ingress_write <= 1'b1;
                  fsm_reg <= FSM_SEND_PAYLOAD;
               end
               else begin
                  local_ingress_write <= 1'b0;
               end
            end

            FSM_SEND_PAYLOAD: begin
               if(fifo_full == 1'b0) begin
                  local_ingress_data[PAYLOAD_WIDTH] <= 1'b0;
                  local_ingress_data[PAYLOAD_WIDTH-1:0] <= $random(seed);
                  local_ingress_write <= 1'b1;
                  nbflits <= nbflits - 1'b1;
                  if(nbflits == 1) begin
                     fsm_reg <= FSM_SEND_CLOSE;
                  end
                  else begin
                     fsm_reg <= FSM_SEND_PAYLOAD;
                  end
               end
               else begin
                  local_ingress_write <= 1'b0;
               end
            end

            FSM_SEND_CLOSE: begin
               if(fifo_full == 1'b0) begin
                  local_ingress_data[PAYLOAD_WIDTH:0] <= {1'b1, writerid, packetid};
                  local_ingress_write <= 1'b1;
                  fsm_reg <= FSM_IDLE;
                  packetid <= packetid + 1'b1;
                  packet_sent <= 1'b1;
                  $strobe("writer %0d: packet %0d sent", WRITER_CHECKER_ID, packetid);
               end
               else begin
                  local_ingress_write <= 1'b0;
               end
            end

            default: begin //FSM_IDLE
               packet_sent <= 1'b0;
               address_sent <= 1'b0;
               local_ingress_write <= 1'b0;
               local_ingress_data <= 0;
               nbaddr <= 0;
               nbflits <= 0;
               wait_reg <= 0;
               if(packetid == NB_PACKETS) begin
                  fsm_reg <= FSM_IDLE;
                  all_packets_sent <= 1'b1;
               end
               else begin
                  fsm_reg <= FSM_START;
               end
            end
         endcase
      end
   end

endmodule
