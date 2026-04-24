// SPDX-License-Identifier: CERN-OHL-P-2.0
// Copyright (c) 2013-2026 Christophe Clienti
//
// This source describes Open Hardware and is licensed under the CERN-OHL-P v2.
// You may redistribute and modify this file under the terms of the CERN-OHL-P v2
// (https://ohwr.org/cern_ohl_p_v2.txt).
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING
// OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A PARTICULAR PURPOSE.
// Please see the CERN-OHL-P v2 for applicable conditions.



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
