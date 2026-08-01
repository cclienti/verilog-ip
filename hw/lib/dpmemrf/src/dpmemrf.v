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



`timescale 1 ns / 100 ps

module dpmemrf
  #(parameter DEPTH   = 10,
    parameter WIDTH   = 32,
    parameter BYTE_WE = 0,   //1: wea/web become per-byte write enables
    parameter NBE     = BYTE_WE ? WIDTH/8 : 1,  //derived, do not override
    parameter OUTREGA = 1,
    parameter OUTREGB = 1)

   (input wire             clka, ena,
    input wire [NBE-1:0]   wea,
    input wire [DEPTH-1:0] addra,
    input wire [WIDTH-1:0] dia,
    output reg [WIDTH-1:0] doa,

    input wire             clkb, enb,
    input wire [NBE-1:0]   web,
    input wire [DEPTH-1:0] addrb,
    input wire [WIDTH-1:0] dib,
    output reg [WIDTH-1:0] dob);


   localparam CHUNK = WIDTH / NBE;   //WIDTH when BYTE_WE = 0, else 8

   // NBE and CHUNK are truncating divisions: with BYTE_WE = 1 and a WIDTH
   // that is not a multiple of 8, the write loop would cover only
   // NBE*CHUNK bits and the top of every word would never be assigned.
   initial begin
      if (BYTE_WE != 0 && (WIDTH % 8) != 0) begin
         $display("dpmemrf: BYTE_WE=1 requires WIDTH %% 8 == 0 (WIDTH=%0d)",
                  WIDTH);
         $finish;
      end
   end

   reg [WIDTH-1:0] ram[2**DEPTH-1:0];
   reg [WIDTH-1:0] doa_reg, dob_reg;
   integer         ia, ib;

   // READ_FIRST on both ports: the non-blocking read of ram[] samples the
   // pre-write content. The per-chunk write is the pattern Vivado maps
   // onto the BRAM's native byte write enables (WEA[3:0] on a 32-bit
   // port), so BYTE_WE = 1 costs no extra primitive -- it does NOT split
   // the memory into narrow slices.
   always @ (posedge clka) begin
      if(ena == 1'b1) begin
         doa_reg <= ram[addra];
         for(ia = 0; ia < NBE; ia = ia + 1) begin
            if(wea[ia] == 1'b1) begin
               ram[addra][ia*CHUNK +: CHUNK] <= dia[ia*CHUNK +: CHUNK];
            end
         end
      end
   end

   generate
      if(OUTREGA != 0) begin
         always @ (posedge clka) begin
            if(ena == 1'b1) begin
               doa <= doa_reg;
            end
         end
      end else begin
         always @ (doa_reg) begin
            doa <= doa_reg;
         end
      end
   endgenerate


   always @ (posedge clkb) begin
      if(enb == 1'b1) begin
         dob_reg <= ram[addrb];
         for(ib = 0; ib < NBE; ib = ib + 1) begin
            if(web[ib] == 1'b1) begin
               ram[addrb][ib*CHUNK +: CHUNK] <= dib[ib*CHUNK +: CHUNK];
            end
         end
      end
   end

   generate
      if(OUTREGB != 0) begin
         always @ (posedge clkb) begin
            if(enb == 1'b1) begin
               dob <= dob_reg;
            end
         end
      end else begin
         always @ (dob_reg) begin
            dob <= dob_reg;
         end
      end
   endgenerate

endmodule // dpmemrf
