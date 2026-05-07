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

// N-Read-Port Memory (nrpmem)
//
// Memory with one synchronous write port and NUMBER_READ_PORTS independent
// asynchronous read ports.
//
// Built from NUMBER_READ_PORTS dual-port LUT-RAMs, all sharing the same
// write port. Each RAM instance services one read port independently.
//
// LUTRAM inference relies on:
//   - synchronous write  (always_ff)
//   - asynchronous read  (assign / combinational)
//   - synthesis attributes:
//       (* ram_style = "distributed" *)  -- Xilinx
//       (* ramstyle  = "logic"        *)  -- Intel/Altera
//
// If REGISTER_OUTPUTS is 0, read data is combinational (zero latency).
// If REGISTER_OUTPUTS is 1, read data is registered (one cycle latency),
// gated by enable.

module nrpmem
  #(parameter int MEM_WIDTH         = 32,   // Width of a memory word
    parameter int LOG2_MEM_DEPTH    = 6,    // Log2 of number of words
    parameter int NUMBER_READ_PORTS = 8,    // Number of independent read ports
    parameter bit REGISTER_OUTPUTS  = 1'b0) // Register read outputs (adds 1 cycle latency)

   (input  logic                                         clk,
    input  logic                                         enable,

    // Write port
    input  logic [LOG2_MEM_DEPTH-1:0]                    wraddr,
    input  logic                                         wren,
    input  logic [MEM_WIDTH-1:0]                         wrdata,

    // Read ports (concatenated, port i at bits [(i+1)*LOG2_MEM_DEPTH-1 -: LOG2_MEM_DEPTH])
    input  logic [NUMBER_READ_PORTS*LOG2_MEM_DEPTH-1:0] rdaddr,
    output logic [NUMBER_READ_PORTS*MEM_WIDTH-1:0]      rddata);


   //----------------------------------------------------------------
   // Internal signals
   //----------------------------------------------------------------

   logic wren_gated;
   assign wren_gated = wren & enable;


   //----------------------------------------------------------------
   // Generate one LUTRAM per read port, all sharing the write port.
   //
   // All signals (ram array, combinational read, optional output
   // register and output assign) are kept local to the generate block
   // to ensure correct simulation and reliable LUTRAM inference.
   //----------------------------------------------------------------

   generate
      for (genvar i = 0; i < NUMBER_READ_PORTS; i++) begin : gen_rams

         // One independent LUTRAM per read port.
         // Synthesis attributes force distributed RAM inference:
         //   Xilinx: ram_style = "distributed"
         //   Intel:  ramstyle  = "logic"
         (* ram_style = "distributed" *)  // Xilinx
         (* ramstyle  = "logic"       *)  // Intel/Altera
         logic [MEM_WIDTH-1:0] ram [2**LOG2_MEM_DEPTH-1:0];

         // Synchronous write — all RAMs share the same write port
         always_ff @(posedge clk) begin
            if (wren_gated) begin
               ram[wraddr] <= wrdata;
            end
         end

         // Asynchronous (combinational) read
         logic [MEM_WIDTH-1:0] rd_comb;
         assign rd_comb = ram[rdaddr[(i+1)*LOG2_MEM_DEPTH-1 -: LOG2_MEM_DEPTH]];

         // Optional output register
         if (REGISTER_OUTPUTS) begin : gen_out_reg
            logic [MEM_WIDTH-1:0] rd_reg;

            always_ff @(posedge clk) begin
               if (enable) begin
                  rd_reg <= rd_comb;
               end
            end

            assign rddata[(i+1)*MEM_WIDTH-1 -: MEM_WIDTH] = rd_reg;
         end
         else begin : gen_out_comb
            assign rddata[(i+1)*MEM_WIDTH-1 -: MEM_WIDTH] = rd_comb;
         end

      end
   endgenerate


endmodule
