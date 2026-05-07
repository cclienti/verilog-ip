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

module vliwrf_tb ();

   //----------------------------------------------------------------
   // Parameters
   //----------------------------------------------------------------
   localparam int MEM_WIDTH                = 32;
   localparam int LOG2_NB_REGS_PER_WR_PORT = 3;  // 8 regs per bank
   localparam int NUM_WRITE_PORTS          = 4;
   localparam int NUM_READ_PORTS           = 8;

   localparam int LOG2_NUM_WR_PORTS = $clog2(NUM_WRITE_PORTS);
   localparam int RD_ADDR_WIDTH     = LOG2_NB_REGS_PER_WR_PORT + LOG2_NUM_WR_PORTS;

   //----------------------------------------------------------------
   // DUT signals – use unpacked arrays to avoid variable part-selects
   //----------------------------------------------------------------
   logic clk;
   logic enable;

   // Write port unpacked arrays
   logic [NUM_WRITE_PORTS-1:0]            wren;
   logic [LOG2_NB_REGS_PER_WR_PORT-1:0]  wraddr_arr [NUM_WRITE_PORTS-1:0];
   logic [MEM_WIDTH-1:0]                  wrdata_arr [NUM_WRITE_PORTS-1:0];

   // Read port unpacked arrays (separate for comb/reg DUT)
   logic [LOG2_NUM_WR_PORTS-1:0]          rdbank_c [NUM_READ_PORTS-1:0];
   logic [LOG2_NB_REGS_PER_WR_PORT-1:0]  rdoff_c  [NUM_READ_PORTS-1:0];
   logic [LOG2_NUM_WR_PORTS-1:0]          rdbank_r [NUM_READ_PORTS-1:0];
   logic [LOG2_NB_REGS_PER_WR_PORT-1:0]  rdoff_r  [NUM_READ_PORTS-1:0];

   // Flat buses assembled from unpacked arrays by genvar
   logic [NUM_WRITE_PORTS*LOG2_NB_REGS_PER_WR_PORT-1:0] wraddr;
   logic [NUM_WRITE_PORTS*MEM_WIDTH-1:0]                 wrdata;
   logic [NUM_READ_PORTS*RD_ADDR_WIDTH-1:0]              rdaddr_c;
   logic [NUM_READ_PORTS*RD_ADDR_WIDTH-1:0]              rdaddr_r;

   // Flat outputs from DUT
   logic [NUM_READ_PORTS*MEM_WIDTH-1:0]  rddata_c;
   logic [NUM_READ_PORTS*MEM_WIDTH-1:0]  rddata_r;

   // Sliced read outputs
   logic [MEM_WIDTH-1:0] comb_rd [NUM_READ_PORTS-1:0];
   logic [MEM_WIDTH-1:0] reg_rd  [NUM_READ_PORTS-1:0];

   integer errors = 0;

   //----------------------------------------------------------------
   // Flat bus assembly
   //----------------------------------------------------------------
   generate
      for (genvar i = 0; i < NUM_WRITE_PORTS; i++) begin : gen_wr
         assign wraddr[i*LOG2_NB_REGS_PER_WR_PORT +: LOG2_NB_REGS_PER_WR_PORT] = wraddr_arr[i];
         assign wrdata[i*MEM_WIDTH +: MEM_WIDTH]                                 = wrdata_arr[i];
      end
      for (genvar j = 0; j < NUM_READ_PORTS; j++) begin : gen_rd
         assign rdaddr_c[j*RD_ADDR_WIDTH +: RD_ADDR_WIDTH] = {rdbank_c[j], rdoff_c[j]};
         assign rdaddr_r[j*RD_ADDR_WIDTH +: RD_ADDR_WIDTH] = {rdbank_r[j], rdoff_r[j]};
         assign comb_rd[j] = rddata_c[j*MEM_WIDTH +: MEM_WIDTH];
         assign reg_rd [j] = rddata_r[j*MEM_WIDTH +: MEM_WIDTH];
      end
   endgenerate

   //----------------------------------------------------------------
   // DUT instances
   //----------------------------------------------------------------
   vliwrf #(
      .MEM_WIDTH               (MEM_WIDTH),
      .LOG2_NB_REGS_PER_WR_PORT(LOG2_NB_REGS_PER_WR_PORT),
      .NUM_WRITE_PORTS         (NUM_WRITE_PORTS),
      .NUM_READ_PORTS          (NUM_READ_PORTS),
      .REGISTER_OUTPUTS        (1'b0))
   dut_comb (
      .clk    (clk),  .enable (enable),
      .wren   (wren), .wraddr (wraddr), .wrdata (wrdata),
      .rdaddr (rdaddr_c), .rddata (rddata_c));

   vliwrf #(
      .MEM_WIDTH               (MEM_WIDTH),
      .LOG2_NB_REGS_PER_WR_PORT(LOG2_NB_REGS_PER_WR_PORT),
      .NUM_WRITE_PORTS         (NUM_WRITE_PORTS),
      .NUM_READ_PORTS          (NUM_READ_PORTS),
      .REGISTER_OUTPUTS        (1'b1))
   dut_reg (
      .clk    (clk),  .enable (enable),
      .wren   (wren), .wraddr (wraddr), .wrdata (wrdata),
      .rdaddr (rdaddr_r), .rddata (rddata_r));

   //----------------------------------------------------------------
   // VCD
   //----------------------------------------------------------------
   initial begin
      $dumpfile("vliwrf_tb.vcd");
      $dumpvars(0, vliwrf_tb);
   end

   //----------------------------------------------------------------
   // Clock: period = 10 ns
   //----------------------------------------------------------------
   initial clk = 1'b0;
   always #5 clk = ~clk;

   //----------------------------------------------------------------
   // Helper: check with label
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
   // Helper: apply read addresses (comb and reg DUTs share same addresses)
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
      rdbank_c[0]=b0; rdoff_c[0]=o0; rdbank_r[0]=b0; rdoff_r[0]=o0;
      rdbank_c[1]=b1; rdoff_c[1]=o1; rdbank_r[1]=b1; rdoff_r[1]=o1;
      rdbank_c[2]=b2; rdoff_c[2]=o2; rdbank_r[2]=b2; rdoff_r[2]=o2;
      rdbank_c[3]=b3; rdoff_c[3]=o3; rdbank_r[3]=b3; rdoff_r[3]=o3;
      rdbank_c[4]=b4; rdoff_c[4]=o4; rdbank_r[4]=b4; rdoff_r[4]=o4;
      rdbank_c[5]=b5; rdoff_c[5]=o5; rdbank_r[5]=b5; rdoff_r[5]=o5;
      rdbank_c[6]=b6; rdoff_c[6]=o6; rdbank_r[6]=b6; rdoff_r[6]=o6;
      rdbank_c[7]=b7; rdoff_c[7]=o7; rdbank_r[7]=b7; rdoff_r[7]=o7;
   endtask

   //----------------------------------------------------------------
   // Main test sequence
   //----------------------------------------------------------------
   initial begin
      // Initialise
      enable = 1'b1;
      wren   = '0;
      wraddr_arr[0]='0; wraddr_arr[1]='0; wraddr_arr[2]='0; wraddr_arr[3]='0;
      wrdata_arr[0]='0; wrdata_arr[1]='0; wrdata_arr[2]='0; wrdata_arr[3]='0;
      rdbank_c[0]='0; rdoff_c[0]='0; rdbank_c[1]='0; rdoff_c[1]='0;
      rdbank_c[2]='0; rdoff_c[2]='0; rdbank_c[3]='0; rdoff_c[3]='0;
      rdbank_c[4]='0; rdoff_c[4]='0; rdbank_c[5]='0; rdoff_c[5]='0;
      rdbank_c[6]='0; rdoff_c[6]='0; rdbank_c[7]='0; rdoff_c[7]='0;
      rdbank_r[0]='0; rdoff_r[0]='0; rdbank_r[1]='0; rdoff_r[1]='0;
      rdbank_r[2]='0; rdoff_r[2]='0; rdbank_r[3]='0; rdoff_r[3]='0;
      rdbank_r[4]='0; rdoff_r[4]='0; rdbank_r[5]='0; rdoff_r[5]='0;
      rdbank_r[6]='0; rdoff_r[6]='0; rdbank_r[7]='0; rdoff_r[7]='0;

      // -------------------------------------------------------
      // Write cycle 1: reg[1] in all banks simultaneously
      //   bank0/reg1=0xA0000001  bank1/reg1=0xB0000001
      //   bank2/reg1=0xC0000001  bank3/reg1=0xD0000001
      // -------------------------------------------------------
      @(negedge clk);
      wren = 4'b1111;
      wraddr_arr[0]=3'd1; wrdata_arr[0]=32'hA0000001;
      wraddr_arr[1]=3'd1; wrdata_arr[1]=32'hB0000001;
      wraddr_arr[2]=3'd1; wrdata_arr[2]=32'hC0000001;
      wraddr_arr[3]=3'd1; wrdata_arr[3]=32'hD0000001;

      // -------------------------------------------------------
      // Write cycle 2: different offsets in each bank
      //   bank0/reg2=0xA0000002  bank1/reg3=0xB0000003
      //   bank2/reg4=0xC0000004  bank3/reg5=0xD0000005
      // -------------------------------------------------------
      @(negedge clk);
      wren = 4'b1111;
      wraddr_arr[0]=3'd2; wrdata_arr[0]=32'hA0000002;
      wraddr_arr[1]=3'd3; wrdata_arr[1]=32'hB0000003;
      wraddr_arr[2]=3'd4; wrdata_arr[2]=32'hC0000004;
      wraddr_arr[3]=3'd5; wrdata_arr[3]=32'hD0000005;

      // -------------------------------------------------------
      // Stop writing; set read addresses; wait for combinational outputs
      // -------------------------------------------------------
      @(negedge clk);
      wren = '0;
      set_rd(2'd0,3'd1, 2'd1,3'd1, 2'd2,3'd1, 2'd3,3'd1,
             2'd0,3'd2, 2'd1,3'd3, 2'd2,3'd4, 2'd3,3'd5);

      // Allow combinational propagation
      #1;
      check("comb rd[0] bank0/reg1", comb_rd[0], 32'hA0000001);
      check("comb rd[1] bank1/reg1", comb_rd[1], 32'hB0000001);
      check("comb rd[2] bank2/reg1", comb_rd[2], 32'hC0000001);
      check("comb rd[3] bank3/reg1", comb_rd[3], 32'hD0000001);
      check("comb rd[4] bank0/reg2", comb_rd[4], 32'hA0000002);
      check("comb rd[5] bank1/reg3", comb_rd[5], 32'hB0000003);
      check("comb rd[6] bank2/reg4", comb_rd[6], 32'hC0000004);
      check("comb rd[7] bank3/reg5", comb_rd[7], 32'hD0000005);

      // -------------------------------------------------------
      // Registered outputs: wait one more posedge then check
      // -------------------------------------------------------
      @(negedge clk);
      #1;
      check("reg  rd[0] bank0/reg1", reg_rd[0], 32'hA0000001);
      check("reg  rd[1] bank1/reg1", reg_rd[1], 32'hB0000001);
      check("reg  rd[2] bank2/reg1", reg_rd[2], 32'hC0000001);
      check("reg  rd[3] bank3/reg1", reg_rd[3], 32'hD0000001);
      check("reg  rd[4] bank0/reg2", reg_rd[4], 32'hA0000002);
      check("reg  rd[5] bank1/reg3", reg_rd[5], 32'hB0000003);
      check("reg  rd[6] bank2/reg4", reg_rd[6], 32'hC0000004);
      check("reg  rd[7] bank3/reg5", reg_rd[7], 32'hD0000005);

      // -------------------------------------------------------
      // Test enable=0 inhibits write
      // -------------------------------------------------------
      @(negedge clk);
      enable = 1'b0;
      wren = 4'b0001;
      wraddr_arr[0]=3'd1; wrdata_arr[0]=32'hDEADBEEF;

      @(negedge clk);
      enable = 1'b1;
      wren   = '0;

      @(negedge clk);
      #1;
      check("comb rd[0] bank0/reg1 after disabled write", comb_rd[0], 32'hA0000001);

      @(negedge clk);
      #1;
      check("reg  rd[0] bank0/reg1 after disabled write", reg_rd[0],  32'hA0000001);

      // -------------------------------------------------------
      // Rotate read ports
      //   rd[0]->bank3/reg5  rd[1]->bank2/reg4
      //   rd[2]->bank1/reg3  rd[3]->bank0/reg2
      //   rd[4]->bank3/reg1  rd[5]->bank2/reg1
      //   rd[6]->bank1/reg1  rd[7]->bank0/reg1
      // -------------------------------------------------------
      @(negedge clk);
      set_rd(2'd3,3'd5, 2'd2,3'd4, 2'd1,3'd3, 2'd0,3'd2,
             2'd3,3'd1, 2'd2,3'd1, 2'd1,3'd1, 2'd0,3'd1);
      #1;
      check("comb rd[0] bank3/reg5", comb_rd[0], 32'hD0000005);
      check("comb rd[1] bank2/reg4", comb_rd[1], 32'hC0000004);
      check("comb rd[2] bank1/reg3", comb_rd[2], 32'hB0000003);
      check("comb rd[3] bank0/reg2", comb_rd[3], 32'hA0000002);
      check("comb rd[4] bank3/reg1", comb_rd[4], 32'hD0000001);
      check("comb rd[5] bank2/reg1", comb_rd[5], 32'hC0000001);
      check("comb rd[6] bank1/reg1", comb_rd[6], 32'hB0000001);
      check("comb rd[7] bank0/reg1", comb_rd[7], 32'hA0000001);

      @(negedge clk);
      #1;
      check("reg  rd[0] bank3/reg5", reg_rd[0], 32'hD0000005);
      check("reg  rd[1] bank2/reg4", reg_rd[1], 32'hC0000004);
      check("reg  rd[2] bank1/reg3", reg_rd[2], 32'hB0000003);
      check("reg  rd[3] bank0/reg2", reg_rd[3], 32'hA0000002);
      check("reg  rd[4] bank3/reg1", reg_rd[4], 32'hD0000001);
      check("reg  rd[5] bank2/reg1", reg_rd[5], 32'hC0000001);
      check("reg  rd[6] bank1/reg1", reg_rd[6], 32'hB0000001);
      check("reg  rd[7] bank0/reg1", reg_rd[7], 32'hA0000001);

      // -------------------------------------------------------
      // Done
      // -------------------------------------------------------
      @(negedge clk);
      if (errors == 0)
         $display("PASS: all checks passed");
      else
         $display("FAIL: %0d error(s) found", errors);
      $finish();
   end

endmodule
