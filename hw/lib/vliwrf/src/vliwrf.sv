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

// VLIW Multi-Port Register File (vliwrf)
//
// Register file with NUM_WRITE_PORTS independent write ports and
// NUM_READ_PORTS independent read ports, intended for VLIW processors
// and multi-issue datapaths.
//
// Architecture:
//   - NUM_WRITE_PORTS nrpmem banks, one per write port.
//   - Each bank has NUM_READ_PORTS asynchronous read ports.
//   - All banks share the same read address LSBs (register offset within a bank).
//   - The MSBs of each read address select which bank drives that read port output.
//
// Read address layout (RD_ADDR_WIDTH bits per port):
//   [RD_ADDR_WIDTH-1 : LOG2_NB_REGS_PER_WR_PORT]  -> bank select (write port index)
//   [LOG2_NB_REGS_PER_WR_PORT-1 : 0]               -> register offset within bank
//
// Total register file capacity: NUM_WRITE_PORTS * 2**LOG2_NB_REGS_PER_WR_PORT words.
//
// If REGISTER_OUTPUTS is 1, read data is registered (one cycle latency) and
// the bank-select is also registered to stay in sync.
// If REGISTER_OUTPUTS is 0, read data is combinational (zero latency).

module vliwrf
  #(parameter int  MEM_WIDTH                = 32,  // Width of a register word
    parameter int  LOG2_NB_REGS_PER_WR_PORT = 5,   // Log2 of registers per write port
    parameter int  NUM_WRITE_PORTS          = 4,    // Number of write ports (power of 2, >= 2)
    parameter int  NUM_READ_PORTS           = 8,    // Number of read ports
    parameter bit  REGISTER_OUTPUTS         = 1'b1) // Register read outputs (1 cycle latency)

   (input  logic                                                                             clk,
    input  logic                                                                             enable,

    // Write ports (concatenated)
    input  logic [NUM_WRITE_PORTS-1:0]                                                      wren,
    input  logic [NUM_WRITE_PORTS*LOG2_NB_REGS_PER_WR_PORT-1:0]                            wraddr,
    input  logic [NUM_WRITE_PORTS*MEM_WIDTH-1:0]                                            wrdata,

    // Read ports (concatenated)
    // Each read address is RD_ADDR_WIDTH bits:
    //   MSBs [RD_ADDR_WIDTH-1:LOG2_NB_REGS_PER_WR_PORT] = bank (write port) select
    //   LSBs [LOG2_NB_REGS_PER_WR_PORT-1:0]             = register offset within bank
    input  logic [NUM_READ_PORTS*(LOG2_NB_REGS_PER_WR_PORT+$clog2(NUM_WRITE_PORTS))-1:0]  rdaddr,
    output logic [NUM_READ_PORTS*MEM_WIDTH-1:0]                                             rddata);


   //----------------------------------------------------------------
   // Local parameters
   //----------------------------------------------------------------

   localparam int LOG2_NUM_WR_PORTS = $clog2(NUM_WRITE_PORTS);
   localparam int RD_ADDR_WIDTH     = LOG2_NB_REGS_PER_WR_PORT + LOG2_NUM_WR_PORTS;


   //----------------------------------------------------------------
   // Parameter assertions
   //----------------------------------------------------------------

   initial begin
      if (MEM_WIDTH <= 0)
         $fatal(1, "%m: MEM_WIDTH (%0d) must be > 0", MEM_WIDTH);
      if ((MEM_WIDTH & (MEM_WIDTH - 1)) != 0)
         $fatal(1, "%m: MEM_WIDTH (%0d) must be a power of 2", MEM_WIDTH);
      if (LOG2_NB_REGS_PER_WR_PORT < 1)
         $fatal(1, "%m: LOG2_NB_REGS_PER_WR_PORT (%0d) must be >= 1", LOG2_NB_REGS_PER_WR_PORT);
      if (NUM_WRITE_PORTS < 2)
         $fatal(1, "%m: NUM_WRITE_PORTS (%0d) must be >= 2", NUM_WRITE_PORTS);
      if ((NUM_WRITE_PORTS & (NUM_WRITE_PORTS - 1)) != 0)
         $fatal(1, "%m: NUM_WRITE_PORTS (%0d) must be a power of 2", NUM_WRITE_PORTS);
      if (NUM_READ_PORTS < 1)
         $fatal(1, "%m: NUM_READ_PORTS (%0d) must be >= 1", NUM_READ_PORTS);
   end


   //----------------------------------------------------------------
   // Internal signals
   //----------------------------------------------------------------

   // One output bus per bank, width = NUM_READ_PORTS * MEM_WIDTH
   logic [NUM_READ_PORTS*MEM_WIDTH-1:0] bank_rddata [NUM_WRITE_PORTS-1:0];

   // Shared read address LSBs (register offset) fed to all banks
   logic [NUM_READ_PORTS*LOG2_NB_REGS_PER_WR_PORT-1:0] rd_lsb_addr;

   // Per read-port bank select extracted from rdaddr MSBs
   logic [LOG2_NUM_WR_PORTS-1:0] rd_bank_sel     [NUM_READ_PORTS-1:0];
   logic [LOG2_NUM_WR_PORTS-1:0] rd_bank_sel_reg [NUM_READ_PORTS-1:0];

   // 2D array: rd_word[read_port][bank] holds the MEM_WIDTH word from
   // that bank for that read port. Module-level, populated by genvar assigns.
   logic [MEM_WIDTH-1:0] rd_word [NUM_READ_PORTS-1:0][NUM_WRITE_PORTS-1:0];

   // Unpacked output array driven by always_comb mux, then
   // flattened to rddata by genvar assigns.
   logic [MEM_WIDTH-1:0] rddata_arr [NUM_READ_PORTS-1:0];


   //----------------------------------------------------------------
   // Extract register offset (LSBs) and bank select (MSBs) from rdaddr
   // j is genvar -> all part-selects are constants
   //----------------------------------------------------------------

   generate
      for (genvar j = 0; j < NUM_READ_PORTS; j++) begin : gen_rdaddr_split
         assign rd_lsb_addr[j*LOG2_NB_REGS_PER_WR_PORT +: LOG2_NB_REGS_PER_WR_PORT] =
                rdaddr[j*RD_ADDR_WIDTH +: LOG2_NB_REGS_PER_WR_PORT];

         assign rd_bank_sel[j] =
                rdaddr[j*RD_ADDR_WIDTH + LOG2_NB_REGS_PER_WR_PORT +: LOG2_NUM_WR_PORTS];
      end
   endgenerate


   //----------------------------------------------------------------
   // nrpmem bank instances (one per write port)
   // i is genvar -> all part-selects are constants
   //----------------------------------------------------------------

   generate
      for (genvar i = 0; i < NUM_WRITE_PORTS; i++) begin : gen_banks
         nrpmem #(
            .MEM_WIDTH        (MEM_WIDTH),
            .LOG2_MEM_DEPTH   (LOG2_NB_REGS_PER_WR_PORT),
            .NUMBER_READ_PORTS(NUM_READ_PORTS),
            .REGISTER_OUTPUTS (REGISTER_OUTPUTS))
         bank (
            .clk    (clk),
            .enable (enable),
            .wraddr (wraddr[i*LOG2_NB_REGS_PER_WR_PORT +: LOG2_NB_REGS_PER_WR_PORT]),
            .wren   (wren[i]),
            .wrdata (wrdata[i*MEM_WIDTH +: MEM_WIDTH]),
            .rdaddr (rd_lsb_addr),
            .rddata (bank_rddata[i]));
      end
   endgenerate


   //----------------------------------------------------------------
   // Bank select pipeline
   // Registered when REGISTER_OUTPUTS=1 to match nrpmem output latency.
   //----------------------------------------------------------------

   generate
      if (REGISTER_OUTPUTS) begin : gen_banksel_reg
         always_ff @(posedge clk) begin
            if (enable) begin
               for (int j = 0; j < NUM_READ_PORTS; j++) begin
                  rd_bank_sel_reg[j] <= rd_bank_sel[j];
               end
            end
         end
      end
      else begin : gen_banksel_comb
         for (genvar j = 0; j < NUM_READ_PORTS; j++) begin : gen_banksel_wire
            assign rd_bank_sel_reg[j] = rd_bank_sel[j];
         end
      end
   endgenerate


   //----------------------------------------------------------------
   // Collect rd_word[j][i]: read port j output from bank i
   // Both i and j are genvar -> all part-selects are constant -> safe
   //----------------------------------------------------------------

   generate
      for (genvar j = 0; j < NUM_READ_PORTS; j++) begin : gen_rdword_j
         for (genvar i = 0; i < NUM_WRITE_PORTS; i++) begin : gen_rdword_i
            assign rd_word[j][i] = bank_rddata[i][j*MEM_WIDTH +: MEM_WIDTH];
         end
      end
   endgenerate


   //----------------------------------------------------------------
   // Output mux
   // Use always_comb with integer loops and explicit if comparison.
   // All array accesses use unpacked arrays with integer index variables
   // or constant genvar -> no variable part-selects in always blocks.
   // rddata_arr is unpacked -> integer indexing is safe in Icarus.
   //----------------------------------------------------------------

   always_comb begin
      for (integer j = 0; j < NUM_READ_PORTS; j++) begin
         rddata_arr[j] = {MEM_WIDTH{1'b0}};
         for (integer i = 0; i < NUM_WRITE_PORTS; i++) begin
            if (integer'(rd_bank_sel_reg[j]) == i) begin
               rddata_arr[j] = rd_word[j][i];
            end
         end
      end
   end

   // Flatten rddata_arr to rddata flat bus using genvar (constant part-select)
   generate
      for (genvar j = 0; j < NUM_READ_PORTS; j++) begin : gen_rddata_out
         assign rddata[j*MEM_WIDTH +: MEM_WIDTH] = rddata_arr[j];
      end
   endgenerate


endmodule
