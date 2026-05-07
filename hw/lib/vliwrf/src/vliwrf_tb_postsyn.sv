// SPDX-License-Identifier: CERN-OHL-P-2.0
// Copyright (c) 2013-2026 Christophe Clienti
//
// Post-synthesis testbench for vliwrf.
// The netlist is fixed at:
//   MEM_WIDTH=32, LOG2_NB_REGS_PER_WR_PORT=5, NUM_WRITE_PORTS=4,
//   NUM_READ_PORTS=8, REGISTER_OUTPUTS=1
// Only registered-output behaviour is tested (one clock latency).

`timescale 1 ps / 1 ps

module vliwrf_tb_postsyn ();

   // Fixed parameters matching the synthesised netlist
   localparam int MEM_WIDTH                = 32;
   localparam int LOG2_NB_REGS_PER_WR_PORT = 5;   // 32 regs per bank
   localparam int NUM_WRITE_PORTS          = 4;
   localparam int NUM_READ_PORTS           = 8;
   localparam int LOG2_NUM_WR_PORTS        = 2;    // clog2(4)
   localparam int RD_ADDR_WIDTH            = 7;    // 5+2

   //----------------------------------------------------------------
   // DUT signals
   //----------------------------------------------------------------
   logic clk;
   logic enable;

   // Write ports (unpacked to avoid variable part-selects)
   logic [NUM_WRITE_PORTS-1:0]            wren;
   logic [LOG2_NB_REGS_PER_WR_PORT-1:0]  wraddr_arr [NUM_WRITE_PORTS-1:0];
   logic [MEM_WIDTH-1:0]                  wrdata_arr [NUM_WRITE_PORTS-1:0];

   // Read ports (unpacked)
   logic [LOG2_NUM_WR_PORTS-1:0]          rdbank [NUM_READ_PORTS-1:0];
   logic [LOG2_NB_REGS_PER_WR_PORT-1:0]  rdoff  [NUM_READ_PORTS-1:0];

   // Flat buses
   logic [NUM_WRITE_PORTS*LOG2_NB_REGS_PER_WR_PORT-1:0] wraddr;  // 20b
   logic [NUM_WRITE_PORTS*MEM_WIDTH-1:0]                 wrdata;  // 128b
   logic [NUM_READ_PORTS*RD_ADDR_WIDTH-1:0]              rdaddr;  // 56b
   logic [NUM_READ_PORTS*MEM_WIDTH-1:0]                  rddata;  // 256b

   // Sliced outputs
   logic [MEM_WIDTH-1:0] rd [NUM_READ_PORTS-1:0];

   integer errors = 0;

   //----------------------------------------------------------------
   // Flat bus assembly (genvar -> constant part-selects)
   //----------------------------------------------------------------
   generate
      for (genvar i = 0; i < NUM_WRITE_PORTS; i++) begin : gen_wr
         assign wraddr[i*LOG2_NB_REGS_PER_WR_PORT +: LOG2_NB_REGS_PER_WR_PORT] = wraddr_arr[i];
         assign wrdata[i*MEM_WIDTH +: MEM_WIDTH]                                 = wrdata_arr[i];
      end
      for (genvar j = 0; j < NUM_READ_PORTS; j++) begin : gen_rd
         assign rdaddr[j*RD_ADDR_WIDTH +: RD_ADDR_WIDTH] = {rdbank[j], rdoff[j]};
         assign rd[j] = rddata[j*MEM_WIDTH +: MEM_WIDTH];
      end
   endgenerate

   //----------------------------------------------------------------
   // DUT (no parameter overrides – netlist has them fixed)
   //----------------------------------------------------------------
   vliwrf dut (
      .clk    (clk),
      .enable (enable),
      .wren   (wren),
      .wraddr (wraddr),
      .wrdata (wrdata),
      .rdaddr (rdaddr),
      .rddata (rddata));

   //----------------------------------------------------------------
   // VCD
   //----------------------------------------------------------------
   initial begin
      $dumpfile("vliwrf_tb_postsyn.vcd");
      $dumpvars(0, vliwrf_tb_postsyn);
   end

   //----------------------------------------------------------------
   // Clock: 10 ns period (matches timescale 1ps/1ps)
   //----------------------------------------------------------------
   initial clk = 1'b0;
   always #5000 clk = ~clk;   // 5000 ps = 5 ns half-period

   //----------------------------------------------------------------
   // Checker
   //----------------------------------------------------------------
   task automatic check(input string lbl,
                        input logic [MEM_WIDTH-1:0] got,
                        input logic [MEM_WIDTH-1:0] exp);
      if (got !== exp) begin
         $display("FAIL [%s] got=32'h%08h expected=32'h%08h", lbl, got, exp);
         errors++;
      end
   endtask

   //----------------------------------------------------------------
   // Helper: set all read addresses
   //----------------------------------------------------------------
   task automatic set_rd(
      input logic [LOG2_NUM_WR_PORTS-1:0] b0, input logic [LOG2_NB_REGS_PER_WR_PORT-1:0] o0,
      input logic [LOG2_NUM_WR_PORTS-1:0] b1, input logic [LOG2_NB_REGS_PER_WR_PORT-1:0] o1,
      input logic [LOG2_NUM_WR_PORTS-1:0] b2, input logic [LOG2_NB_REGS_PER_WR_PORT-1:0] o2,
      input logic [LOG2_NUM_WR_PORTS-1:0] b3, input logic [LOG2_NB_REGS_PER_WR_PORT-1:0] o3,
      input logic [LOG2_NUM_WR_PORTS-1:0] b4, input logic [LOG2_NB_REGS_PER_WR_PORT-1:0] o4,
      input logic [LOG2_NUM_WR_PORTS-1:0] b5, input logic [LOG2_NB_REGS_PER_WR_PORT-1:0] o5,
      input logic [LOG2_NUM_WR_PORTS-1:0] b6, input logic [LOG2_NB_REGS_PER_WR_PORT-1:0] o6,
      input logic [LOG2_NUM_WR_PORTS-1:0] b7, input logic [LOG2_NB_REGS_PER_WR_PORT-1:0] o7);
      rdbank[0]=b0; rdoff[0]=o0;  rdbank[1]=b1; rdoff[1]=o1;
      rdbank[2]=b2; rdoff[2]=o2;  rdbank[3]=b3; rdoff[3]=o3;
      rdbank[4]=b4; rdoff[4]=o4;  rdbank[5]=b5; rdoff[5]=o5;
      rdbank[6]=b6; rdoff[6]=o6;  rdbank[7]=b7; rdoff[7]=o7;
   endtask

   //----------------------------------------------------------------
   // Main test sequence (registered outputs: 1 cycle latency)
   //----------------------------------------------------------------
   initial begin
      enable = 1'b1;
      wren   = '0;
      wraddr_arr[0]='0; wraddr_arr[1]='0; wraddr_arr[2]='0; wraddr_arr[3]='0;
      wrdata_arr[0]='0; wrdata_arr[1]='0; wrdata_arr[2]='0; wrdata_arr[3]='0;
      rdbank[0]='0; rdoff[0]='0; rdbank[1]='0; rdoff[1]='0;
      rdbank[2]='0; rdoff[2]='0; rdbank[3]='0; rdoff[3]='0;
      rdbank[4]='0; rdoff[4]='0; rdbank[5]='0; rdoff[5]='0;
      rdbank[6]='0; rdoff[6]='0; rdbank[7]='0; rdoff[7]='0;
      // Wait for Xilinx GSR (Global Set/Reset) to deassert (100 ns)
      @(negedge glbl.GSR);
      @(negedge clk);

      // -------------------------------------------------------
      // Write cycle 1: reg[1] in all banks
      // -------------------------------------------------------
      @(negedge clk);
      wren = 4'b1111;
      wraddr_arr[0]=5'd1; wrdata_arr[0]=32'hA0000001;
      wraddr_arr[1]=5'd1; wrdata_arr[1]=32'hB0000001;
      wraddr_arr[2]=5'd1; wrdata_arr[2]=32'hC0000001;
      wraddr_arr[3]=5'd1; wrdata_arr[3]=32'hD0000001;

      // -------------------------------------------------------
      // Write cycle 2: different offsets
      // -------------------------------------------------------
      @(negedge clk);
      wren = 4'b1111;
      wraddr_arr[0]=5'd2; wrdata_arr[0]=32'hA0000002;
      wraddr_arr[1]=5'd3; wrdata_arr[1]=32'hB0000003;
      wraddr_arr[2]=5'd4; wrdata_arr[2]=32'hC0000004;
      wraddr_arr[3]=5'd5; wrdata_arr[3]=32'hD0000005;

      // -------------------------------------------------------
      // Set read addresses; data appears one cycle later
      // -------------------------------------------------------
      @(negedge clk);
      wren = '0;
      set_rd(2'd0,5'd1, 2'd1,5'd1, 2'd2,5'd1, 2'd3,5'd1,
             2'd0,5'd2, 2'd1,5'd3, 2'd2,5'd4, 2'd3,5'd5);

      @(negedge clk);
      #1000; // 1 ns settle
      check("reg rd[0] bank0/reg1", rd[0], 32'hA0000001);
      check("reg rd[1] bank1/reg1", rd[1], 32'hB0000001);
      check("reg rd[2] bank2/reg1", rd[2], 32'hC0000001);
      check("reg rd[3] bank3/reg1", rd[3], 32'hD0000001);
      check("reg rd[4] bank0/reg2", rd[4], 32'hA0000002);
      check("reg rd[5] bank1/reg3", rd[5], 32'hB0000003);
      check("reg rd[6] bank2/reg4", rd[6], 32'hC0000004);
      check("reg rd[7] bank3/reg5", rd[7], 32'hD0000005);

      // -------------------------------------------------------
      // Test enable=0 inhibits write
      // -------------------------------------------------------
      @(negedge clk);
      enable = 1'b0;
      wren = 4'b0001;
      wraddr_arr[0]=5'd1; wrdata_arr[0]=32'hDEADBEEF;

      @(negedge clk);
      enable = 1'b1;
      wren   = '0;

      @(negedge clk);
      @(negedge clk);
      #1000;
      check("reg rd[0] bank0/reg1 after disabled write", rd[0], 32'hA0000001);

      // -------------------------------------------------------
      // Rotate read ports
      // -------------------------------------------------------
      @(negedge clk);
      set_rd(2'd3,5'd5, 2'd2,5'd4, 2'd1,5'd3, 2'd0,5'd2,
             2'd3,5'd1, 2'd2,5'd1, 2'd1,5'd1, 2'd0,5'd1);

      @(negedge clk);
      #1000;
      check("reg rd[0] bank3/reg5", rd[0], 32'hD0000005);
      check("reg rd[1] bank2/reg4", rd[1], 32'hC0000004);
      check("reg rd[2] bank1/reg3", rd[2], 32'hB0000003);
      check("reg rd[3] bank0/reg2", rd[3], 32'hA0000002);
      check("reg rd[4] bank3/reg1", rd[4], 32'hD0000001);
      check("reg rd[5] bank2/reg1", rd[5], 32'hC0000001);
      check("reg rd[6] bank1/reg1", rd[6], 32'hB0000001);
      check("reg rd[7] bank0/reg1", rd[7], 32'hA0000001);

      // -------------------------------------------------------
      // Done
      // -------------------------------------------------------
      @(negedge clk);
      if (errors == 0)
         $display("PASS: all post-syn checks passed");
      else
         $display("FAIL: %0d error(s) found", errors);
      $finish();
   end

endmodule
