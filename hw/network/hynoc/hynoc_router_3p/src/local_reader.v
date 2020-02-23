//                              -*- Mode: Verilog -*-
// Filename        : local_reader.v
// Description     : local interface reader
// Author          : Christophe
// Created On      : Sat Feb 22 14:41:44 2020
// Last Modified By: Christophe
// Last Modified On: Sat Feb 22 14:41:44 2020
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2020 Christophe Clienti - All Rights Reserved

module local_reader
  #(parameter integer LOCAL_ID      = 0,
    parameter integer PAYLOAD_WIDTH = 32,
    parameter integer FLIT_WIDTH    = PAYLOAD_WIDTH + 1)
   (input wire                  clk,
    input wire                  srst,
    output reg                  read,
    input wire                  empty,
    input wire [FLIT_WIDTH-1:0] data);

   reg read_reg;
   reg start;

   always @(*) begin
      read = !empty;
   end

   always @(posedge clk) begin
      if (srst == 1'b1) begin
         read_reg <= 1'b0;
      end
      else begin
         read_reg <= read;
      end
   end

   always @(posedge clk) begin
      if (srst == 1'b1) begin
         start <= 1;
      end
      else begin
         if (read_reg == 1'b1) begin
            start <= data[FLIT_WIDTH-1];
         end
      end
   end

   always @(posedge clk) begin
      if (read_reg == 1'b1) begin
         if (start == 1'b1) begin
            $display("Local Xfce %0d: Receiving packet from %0d (%08x)",
                     LOCAL_ID, data[31:16], data);
         end
         else if (data[FLIT_WIDTH-1] == 1'b1) begin
            $display("Local Xfce %0d: Last flit received from %0d (%08x)",
                     LOCAL_ID, data[31:16], data);
         end
      end
   end

endmodule
