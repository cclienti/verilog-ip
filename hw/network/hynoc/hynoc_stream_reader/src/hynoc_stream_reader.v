//                              -*- Mode: Verilog -*-
// Filename        : hynoc_stream_reader.v
// Description     : HyNoC stream reader
// Author          : Christophe Clienti
// Created On      : Thu Feb 27 10:44:57 2014
// Last Modified By: Christophe Clienti
// Last Modified On: Thu Feb 27 10:44:57 2014
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved
`timescale 1 ns / 100 ps

module hynoc_stream_reader
  #(parameter integer READER_CHECKER_ID   = 0,    //id of the reader
    parameter integer WRITER_CHECKER_ID   = 0,    //id of the matching writer
    parameter integer NB_ADDRESS_FLITS    = 1,    //number of address flit
    parameter integer FLIT_RANDOM_SEED    = 556,  //flit value random seed
    parameter integer NB_FLIT_RANDOM_SEED = 666,  //nb flit per packet random seed
    parameter integer NB_PACKETS          = 100,  //number of packets to send
    parameter integer MAX_NB_FLITS        = 1024, //max number of flit per packets
    parameter integer MAX_WAIT            = 1024, //max number of wait cycles between two packets
    parameter integer LOG2_FIFO_DEPTH     = 5,    //log2 depth of the ingress fifo
    parameter integer PAYLOAD_WIDTH       = 32,   //payload width
    parameter integer FLIT_WIDTH          = (PAYLOAD_WIDTH+1)) //payload width

   (output reg                     packet_received,
    output reg                     all_packets_received,

    // signals to be plugged to an egress port
    input wire                     local_clk,
    input wire                     local_srst,
    output reg                     local_egress_read,
    input wire [FLIT_WIDTH-1:0]    local_egress_data,
    input wire [LOG2_FIFO_DEPTH:0] local_egress_fifo_level);

   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------
   localparam FSM_START = 0;
   localparam FSM_WAIT  = 1;
   localparam FSM_FETCH = 2;
   localparam FSM_READ  = 3;
   localparam FSM_STALL = 4;

   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------
   integer seed = FLIT_RANDOM_SEED; // flit value seed
   integer nseed = NB_FLIT_RANDOM_SEED; // nb flits seed
   integer wseed = NB_FLIT_RANDOM_SEED+FLIT_RANDOM_SEED; // wait seed

   reg [PAYLOAD_WIDTH/2-1:0]                 packetid = 0; // packet identifier
   reg [PAYLOAD_WIDTH-(PAYLOAD_WIDTH/2)-1:0] writerid = WRITER_CHECKER_ID; //checker id

   reg [2:0] fsm_reg, fsm_next;
   reg [31:0] nbpck;
   reg [31:0] wait_reg;

   reg wait_countdown, wait_set;
   reg data_valid;
   wire fifo_empty;

   //----------------------------------------------------------------
   // Misc
   //----------------------------------------------------------------
   assign fifo_empty = local_egress_fifo_level == 0 ? 1'b1: 1'b0;

   always @(posedge local_clk) begin
      if(local_srst == 1'b1) begin
         wait_reg <= 0;
      end
      else begin
         if(wait_set == 1'b1) begin
            wait_reg <= $unsigned($random(wseed)) % MAX_WAIT + 1;
         end
         else begin
            if(wait_countdown == 1'b1) begin
               wait_reg <= wait_reg - 1'b1;
            end
         end
      end
   end


   //----------------------------------------------------------------
   // FSM
   //----------------------------------------------------------------


   // Register
   always @(posedge local_clk) begin
      if(local_srst == 1'b1) begin
         fsm_reg <= FSM_START;
      end
      else begin
         fsm_reg <= fsm_next;
      end
   end

   // Transitions
   always @(*) begin
      case(fsm_reg)
         FSM_WAIT: begin
            if(wait_reg == 0) begin
               if(fifo_empty == 1'b0) begin
                  fsm_next = FSM_READ;
               end
               else begin
                  fsm_next = FSM_STALL;
               end
            end
            else begin
               fsm_next = FSM_WAIT;
            end
         end

         FSM_FETCH: begin
            fsm_next = FSM_READ;
         end

         FSM_READ: begin
            if(fifo_empty == 1'b0) begin
               fsm_next = FSM_READ;
            end
            else begin
               fsm_next = FSM_STALL;
            end
         end

         FSM_STALL: begin
            if(fifo_empty == 1'b0) begin
               fsm_next = FSM_FETCH;
            end
            else begin
               fsm_next = FSM_STALL;
            end
         end

         default: begin // FSM_START
            fsm_next = FSM_WAIT;
         end
      endcase
   end

   //outputs
   always @(*) begin
      case(fsm_reg)
         FSM_WAIT: begin
            wait_countdown    = 1;
            wait_set          = 0;
            local_egress_read = 0;
         end

         FSM_FETCH: begin
            wait_countdown    = 0;
            wait_set          = 0;
            local_egress_read = 1;
         end

         FSM_READ: begin
            wait_countdown    = 0;
            wait_set          = 0;
            local_egress_read = 1;
         end

         FSM_STALL: begin
            wait_countdown    = 0;
            wait_set          = 0;
            local_egress_read = 0;
         end

         default: begin // FSM_START
            wait_countdown    = 0;
            wait_set          = 1;
            local_egress_read = 0;
         end
      endcase
   end

   always @(posedge local_clk) begin
      if(local_srst == 1'b1) begin
         data_valid <= 1'b0;
      end
      else begin
         data_valid <= local_egress_read & (~fifo_empty);
      end
   end

   //----------------------------------------------------------------
   // Checker
   //----------------------------------------------------------------
   localparam CHECK_HEADER  = 0;
   localparam CHECK_PAYLOAD = 1;

   integer checker_state = 0;
   integer nbflits, nbflits_ref;

   integer header_counter;

   reg [PAYLOAD_WIDTH-1:0] data_ref;

   wire [PAYLOAD_WIDTH-1:0] data;
   wire header;

   assign data = local_egress_data[PAYLOAD_WIDTH-1:0];
   assign header = local_egress_data[PAYLOAD_WIDTH];

   always @(posedge local_clk) begin
      if(local_srst == 1'b1) begin
         packet_received <= 1'b0;
         checker_state <= CHECK_HEADER;
         nbflits <= 0;
         packetid <= 0;
         header_counter <= 0;
      end
      else begin
         if(data_valid == 1'b1) begin
            case(checker_state)
               CHECK_HEADER: begin
                  packet_received <= 1'b0;
                  nbflits <= 0;

                  if(header_counter == (NB_ADDRESS_FLITS - 1)) begin
                     header_counter <= 0;
                     if(data != {writerid, packetid}) begin
                        $error("reader %0d: packet %0d: bad writerid, packetid: h%h (ref: h%h)",
                               READER_CHECKER_ID, packetid, data, {writerid, packetid});
                     end
                     checker_state <= CHECK_PAYLOAD;
                     nbflits_ref <= $unsigned($random(nseed)) % MAX_NB_FLITS + 1;
                  end
                  else begin
                     header_counter <= header_counter + 1;
                     if((header == 1'b1) || (data[PAYLOAD_WIDTH-1] != 1'b0)) begin
                        $warning("reader %0d: packet %0d: unknown header flit: h%h",
                                 WRITER_CHECKER_ID, packetid, local_egress_data);
                     end
                  end

               end

               CHECK_PAYLOAD: begin
                  if(header == 1'b0) begin
                     data_ref = $random(seed);
                     nbflits <= nbflits + 1;
                     if (data != data_ref) begin
                        $error("reader %0d: packet %0d: bad payload %0d: h%x (ref: h%x)",
                               READER_CHECKER_ID, packetid, nbflits, data, data_ref);
                     end
                  end
                  else if(header == 1'b1) begin
                     if(data != {writerid, packetid}) begin
                        $error("reader %0d: packet %0d: bad writerid, packetid: h%h (ref: h%h)",
                               READER_CHECKER_ID, packetid, data, {writerid, packetid});
                     end
                     if (nbflits != nbflits_ref) begin
                        $error("reader %0d: packet %0d: wrong number of flits received: %0d (ref: %0d)",
                               READER_CHECKER_ID, packetid, nbflits, nbflits_ref);
                     end
                     $strobe("reader %0d: packet %0d received", READER_CHECKER_ID, packetid);
                     packetid <= packetid + 1;
                     packet_received <= 1'b1;
                     checker_state <= CHECK_HEADER;
                  end
                  else begin
                     $error("reader %0d: packet %0d: bad header: %h",
                            READER_CHECKER_ID, packetid, header);
                  end
               end

            endcase
         end
         else begin
            packet_received <= 1'b0;
         end
      end
   end


   always @(*) begin
      if(packetid == NB_PACKETS) begin
         all_packets_received <= 1'b1;
      end
      else begin
         all_packets_received <= 1'b0;
      end
   end

endmodule
