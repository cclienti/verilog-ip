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

module nrpmem_tb ();

   // Parameters
   localparam int MEM_WIDTH         = 32;
   localparam int LOG2_MEM_DEPTH    = 4;   // 16 words
   localparam int NUMBER_READ_PORTS = 3;

   // DUT signals
   logic                                         clk;
   logic                                         enable;
   logic [LOG2_MEM_DEPTH-1:0]                   wraddr;
   logic                                         wren;
   logic [MEM_WIDTH-1:0]                        wrdata;
   logic [NUMBER_READ_PORTS*LOG2_MEM_DEPTH-1:0] rdaddr_comb;
   logic [NUMBER_READ_PORTS*MEM_WIDTH-1:0]      rddata_comb;
   logic [NUMBER_READ_PORTS*LOG2_MEM_DEPTH-1:0] rdaddr_reg;
   logic [NUMBER_READ_PORTS*MEM_WIDTH-1:0]      rddata_reg;

   // Helpers to slice read data
   logic [MEM_WIDTH-1:0] comb_rd [NUMBER_READ_PORTS-1:0];
   logic [MEM_WIDTH-1:0] reg_rd  [NUMBER_READ_PORTS-1:0];

   integer errors = 0;

   generate
      for (genvar i = 0; i < NUMBER_READ_PORTS; i++) begin : gen_slice
         assign comb_rd[i] = rddata_comb[(i+1)*MEM_WIDTH-1 -: MEM_WIDTH];
         assign reg_rd[i]  = rddata_reg [(i+1)*MEM_WIDTH-1 -: MEM_WIDTH];
      end
   endgenerate


   //----------------------------------------------------------------
   // DUT instances
   //----------------------------------------------------------------

   nrpmem #(.MEM_WIDTH        (MEM_WIDTH),
            .LOG2_MEM_DEPTH   (LOG2_MEM_DEPTH),
            .NUMBER_READ_PORTS(NUMBER_READ_PORTS),
            .REGISTER_OUTPUTS (1'b0))
   dut_comb (
      .clk    (clk),
      .enable (enable),
      .wraddr (wraddr),
      .wren   (wren),
      .wrdata (wrdata),
      .rdaddr (rdaddr_comb),
      .rddata (rddata_comb));

   nrpmem #(.MEM_WIDTH        (MEM_WIDTH),
            .LOG2_MEM_DEPTH   (LOG2_MEM_DEPTH),
            .NUMBER_READ_PORTS(NUMBER_READ_PORTS),
            .REGISTER_OUTPUTS (1'b1))
   dut_reg (
      .clk    (clk),
      .enable (enable),
      .wraddr (wraddr),
      .wren   (wren),
      .wrdata (wrdata),
      .rdaddr (rdaddr_reg),
      .rddata (rddata_reg));


   //----------------------------------------------------------------
   // VCD
   //----------------------------------------------------------------
   initial begin
      $dumpfile("nrpmem_tb.vcd");
      $dumpvars(0, nrpmem_tb);
   end


   //----------------------------------------------------------------
   // Clock generation: period = 10 ns
   //----------------------------------------------------------------
   initial clk = 1'b0;
   always #5 clk = ~clk;


   //----------------------------------------------------------------
   // Checker task
   //----------------------------------------------------------------
   task automatic check;
      input string          label;
      input [MEM_WIDTH-1:0] got;
      input [MEM_WIDTH-1:0] expected;
      begin
         if (got !== expected) begin
            $display("FAIL [%s]: got=32'h%08h expected=32'h%08h", label, got, expected);
            errors = errors + 1;
         end
      end
   endtask

   // Helper: wait for posedge then wait 1ns to avoid setup races
   task automatic next_cycle;
      @(posedge clk); #1;
   endtask


   //----------------------------------------------------------------
   // Stimulus and checks
   //
   // Rule: ALL inputs are driven 1 ns AFTER posedge clk (#1 delay)
   //       so that always_ff blocks always see stable values.
   //       Combinational outputs are sampled after a further #1.
   //
   // Write latency : 1 cycle  (sync write, captured on next posedge)
   // Read latency  : 0 cycles (comb DUT) / 1 cycle (reg DUT)
   //
   // Cycle map:
   //  posedge 0 : set initial state
   //  posedge 1 : write addr1 = 0xAABBCCDD
   //  posedge 2 : write addr2 = 0x11223344
   //  posedge 3 : write addr3 = 0xDEADBEEF
   //  posedge 4 : stop write, set rdaddr = {3,2,1}
   //              comb output valid → check comb
   //  posedge 5 : check reg output (captured from posedge 4)
   //  posedge 6 : write addr1 with enable=0 (should be ignored)
   //  posedge 7 : re-enable, stop write, set rdaddr = {3,2,1}
   //              check comb (addr1 must still hold 0xAABBCCDD)
   //  posedge 8 : check reg output
   //  posedge 9 : rotate rdaddr = {2,1,3}  (port0->3, port1->1, port2->2)
   //              check comb
   //  posedge 10: check reg output
   //----------------------------------------------------------------

   initial begin
      // Initialise before first posedge
      enable      = 1'b1;
      wren        = 1'b0;
      wraddr      = '0;
      wrdata      = '0;
      rdaddr_comb = '0;
      rdaddr_reg  = '0;

      // -- posedge 0: initial state already set above --
      next_cycle;   // posedge 0 captured: wren=0, nothing written

      // -- posedge 1: write addr1 --
      wren   = 1'b1;
      wraddr = 4'd1;
      wrdata = 32'hAABBCCDD;
      next_cycle;   // posedge 1 captured: addr1 <= 0xAABBCCDD

      // -- posedge 2: write addr2 --
      wraddr = 4'd2;
      wrdata = 32'h11223344;
      next_cycle;   // posedge 2 captured: addr2 <= 0x11223344

      // -- posedge 3: write addr3 --
      wraddr = 4'd3;
      wrdata = 32'hDEADBEEF;
      next_cycle;   // posedge 3 captured: addr3 <= 0xDEADBEEF

      // -- posedge 4: stop write, set rdaddr --
      wren        = 1'b0;
      wraddr      = '0;
      wrdata      = '0;
      rdaddr_comb = {4'd3, 4'd2, 4'd1}; // port0->1, port1->2, port2->3
      rdaddr_reg  = {4'd3, 4'd2, 4'd1};
      // combinational outputs settle immediately after signal update
      #1;
      check("comb rd[0] addr1", comb_rd[0], 32'hAABBCCDD);
      check("comb rd[1] addr2", comb_rd[1], 32'h11223344);
      check("comb rd[2] addr3", comb_rd[2], 32'hDEADBEEF);

      // -- posedge 5: registered outputs from posedge 4 --
      next_cycle;
      #1;
      check("reg  rd[0] addr1", reg_rd[0], 32'hAABBCCDD);
      check("reg  rd[1] addr2", reg_rd[1], 32'h11223344);
      check("reg  rd[2] addr3", reg_rd[2], 32'hDEADBEEF);

      // -- posedge 6: write addr1 with enable=0 (should be ignored) --
      enable = 1'b0;
      wren   = 1'b1;
      wraddr = 4'd1;
      wrdata = 32'hFFFFFFFF;
      next_cycle;   // posedge 6: enable=0 so wren_gated=0, nothing written

      // -- posedge 7: re-enable, stop write, check addr1 unchanged --
      enable      = 1'b1;
      wren        = 1'b0;
      wraddr      = '0;
      wrdata      = '0;
      rdaddr_comb = {4'd3, 4'd2, 4'd1};
      rdaddr_reg  = {4'd3, 4'd2, 4'd1};
      #1;
      check("comb rd[0] addr1 after disabled write", comb_rd[0], 32'hAABBCCDD);

      // -- posedge 8: registered output --
      next_cycle;
      #1;
      check("reg  rd[0] addr1 after disabled write", reg_rd[0], 32'hAABBCCDD);

      // -- posedge 9: rotate read ports --
      next_cycle;
      rdaddr_comb = {4'd2, 4'd1, 4'd3}; // port0->3, port1->1, port2->2
      rdaddr_reg  = {4'd2, 4'd1, 4'd3};
      #1;
      check("comb rd[0] addr3", comb_rd[0], 32'hDEADBEEF);
      check("comb rd[1] addr1", comb_rd[1], 32'hAABBCCDD);
      check("comb rd[2] addr2", comb_rd[2], 32'h11223344);

      // -- posedge 10: registered output of rotated rdaddr --
      next_cycle;
      #1;
      check("reg  rd[0] addr3", reg_rd[0], 32'hDEADBEEF);
      check("reg  rd[1] addr1", reg_rd[1], 32'hAABBCCDD);
      check("reg  rd[2] addr2", reg_rd[2], 32'h11223344);

      // Done
      next_cycle;
      if (errors == 0)
         $display("PASS: all checks passed");
      else
         $display("FAIL: %0d error(s) found", errors);

      $finish();
   end

endmodule
