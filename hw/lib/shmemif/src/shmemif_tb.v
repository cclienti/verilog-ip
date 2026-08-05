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

module shmemif_tb();

   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------
   localparam NB_PORTS            = 4;
   localparam LOG2_NB_PORTS       = $clog2(NB_PORTS);
   localparam ADDR_WIDTH          = 12;
   localparam DATA_WIDTH          = 32;
   localparam REGISTER_MEM_OUTPUT = 1;

   localparam ARRAY_BOUND  = 1023;

   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------
   reg                            clk;
   reg                            srst;
   reg [NB_PORTS-1:0]             shmem_request;
   reg [NB_PORTS-1:0]             shmem_wren;
   wire [NB_PORTS*ADDR_WIDTH-1:0] shmem_addr;
   wire [NB_PORTS*DATA_WIDTH-1:0] shmem_datain;
   wire [NB_PORTS*DATA_WIDTH-1:0] shmem_dataout;
   wire [NB_PORTS-1:0]            shmem_done;
   wire                           mem_wren;
   wire [ADDR_WIDTH-1:0]          mem_addr;
   wire [DATA_WIDTH-1:0]          mem_datain;
   wire [DATA_WIDTH-1:0]          mem_dataout;

   reg [DATA_WIDTH-1:0]           shmem_datain_array [NB_PORTS-1:0];
   reg [ADDR_WIDTH-1:0]           shmem_addr_array [NB_PORTS-1:0];

   integer                        cpt;


   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------
   // Synthesis freezes the parameters into the netlist, which then takes
   // no override. The localparams above must keep matching the values
   // vivado-gen-post-syn was run with, or the buses no longer fit the ports.
   shmemif
`ifndef POST_SYNTH
   #(
      .NB_PORTS            (NB_PORTS),
      .LOG2_NB_PORTS       (LOG2_NB_PORTS),
      .ADDR_WIDTH          (ADDR_WIDTH),
      .DATA_WIDTH          (DATA_WIDTH),
      .REGISTER_MEM_OUTPUT (REGISTER_MEM_OUTPUT)
   )
`endif
   DUT
   (
      .clk           (clk),
      .srst          (srst),
      .shmem_request (shmem_request),
      .shmem_wren    (shmem_wren),
      .shmem_addr    (shmem_addr),
      .shmem_datain  (shmem_datain),
      .shmem_dataout (shmem_dataout),
      .shmem_done    (shmem_done),
      .mem_wren      (mem_wren),
      .mem_addr      (mem_addr),
      .mem_datain    (mem_datain),
      .mem_dataout   (mem_dataout)
   );


   //----------------------------------------------------------------
   // Clock and Reset Generation
   //----------------------------------------------------------------
   initial begin
      clk       = 0;
      srst      = 1;
`ifdef POST_SYNTH
      // The Xilinx flip-flops hold their output while the global set/reset
      // is asserted, for the first 100 ns. Releasing srst before that just
      // loses the reset pulse.
      @(negedge glbl.GSR);
`endif
      #10 srst  = 1;
      #20 srst  = 0;
   end

   always
     #2 clk = !clk;


   //----------------------------------------------------------------
   // Some usefull information
   //----------------------------------------------------------------
   genvar i;
   integer j;

   // Reaches inside the DUT, so it only exists against the RTL: the
   // netlist is synthesised with -flatten_hierarchy full and lut_gen is
   // gone from it.
`ifndef POST_SYNTH
   generate
     for(i=0 ; i<NB_PORTS ; i=i+1) begin: gen_view
        initial begin
           #1 $display("LUT %d:",i);
           for(j=0 ; j<2**NB_PORTS ; j=j+1) begin
              // i index must be static to index lut_gen, we use a generate with a for loop
              $display("\t %b -> %d", j[NB_PORTS-1:0], DUT.lut_gen[i].prra_lut_inst.lut[j]);
           end
        end
     end
   endgenerate
`endif

   // Expected memory content. Each interface starts at quadrant*1024
   // with datain equal to the address, and interfaces 1-3 stop at
   // absolute address 1023: they wrap through the whole space and sweep
   // quadrant 0 again with data offset by 4096. All three write the same
   // value there, so the final state is deterministic whatever the
   // arbitration order: ram[a] is a+4096 below 1024 and a above.
   //
   // Compare full words: through an ADDR_WIDTH-bit slice, a+4096 folds
   // back onto a and the offset is invisible.
   integer x1,x2,x3,x4;
   integer errors = 0;
   initial begin
      #50000;
      for(j=0; j<=ARRAY_BOUND; j=j+1) begin
         x1 = j;
         x2 = x1 + (2**ADDR_WIDTH)/4;
         x3 = x2 + (2**ADDR_WIDTH)/4;
         x4 = x3 + (2**ADDR_WIDTH)/4;

         if (dpmemrf_inst.ram[x1] !== x1 + 4096) begin
            errors = errors + 1;
            $display("Error: ram[%0d] = %0d (expected %0d)", x1, dpmemrf_inst.ram[x1], x1 + 4096);
         end
         if (dpmemrf_inst.ram[x2] !== x2) begin
            errors = errors + 1;
            $display("Error: ram[%0d] = %0d (expected %0d)", x2, dpmemrf_inst.ram[x2], x2);
         end
         if (dpmemrf_inst.ram[x3] !== x3) begin
            errors = errors + 1;
            $display("Error: ram[%0d] = %0d (expected %0d)", x3, dpmemrf_inst.ram[x3], x3);
         end
         if (dpmemrf_inst.ram[x4] !== x4) begin
            errors = errors + 1;
            $display("Error: ram[%0d] = %0d (expected %0d)", x4, dpmemrf_inst.ram[x4], x4);
         end
      end
      if (errors == 0)
        $display("shmemif_tb: ALL TESTS PASSED (%0d words)", 2**ADDR_WIDTH);
      else
        $display("shmemif_tb: %0d ERROR(S)", errors);
      $finish;
   end


   //----------------------------------------------------------------
   // Test memory
   //----------------------------------------------------------------
   dpmemrf
   #(
      .DEPTH   (ADDR_WIDTH),
      .WIDTH   (DATA_WIDTH),
      .OUTREGA (REGISTER_MEM_OUTPUT),
      .OUTREGB (REGISTER_MEM_OUTPUT)
   )
   dpmemrf_inst
   (
      .clka  (clk),
      .ena   (1'b1),
      .wea   (mem_wren),
      .addra (mem_addr),
      .dia   (mem_datain),
      .doa   (mem_dataout),
      .clkb  (clk),
      .enb   (1'b0),
      .web   (1'b0),
      .addrb (0),
      .dib   (0),
      .dob   ()
   );


   //----------------------------------------------------------------
   // Test Vectors
   //----------------------------------------------------------------
   always @(posedge clk)
     if(srst) begin
        cpt <= 0;
     end
     else begin
        cpt <= cpt + 1;
     end

   initial begin
         shmem_request = 0;
         shmem_wren    = 0;
   end

   generate
      for(i=0; i<NB_PORTS; i=i+1) begin: gen_array
         assign shmem_datain[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH] = shmem_datain_array[i];
         assign shmem_addr[(i+1)*ADDR_WIDTH-1:i*ADDR_WIDTH] = shmem_addr_array[i];
      end
   endgenerate

   // First interface
   always @(posedge clk) begin
      if(srst == 1'b1) begin
         shmem_request[0]      <= 1'b0;
         shmem_wren[0]         <= 1'b0;
         shmem_addr_array[0]   <= 0;
         shmem_datain_array[0] <= 0;
      end
      else begin
         if(shmem_addr_array[0] != 1023) begin
            shmem_request[0] <= 1'b1;
            shmem_wren[0]    <= 1'b1;
            if(shmem_done[0] == 1'b1) begin
               shmem_addr_array[0]   <= shmem_addr_array[0] + 1;
               shmem_datain_array[0] <= shmem_datain_array[0] + 1;
            end
         end
         else begin
            shmem_request[0] <= 1'b0;
            shmem_wren[0]    <= 1'b0;
         end
      end
   end

   // Second interface
   always @(posedge clk) begin
      if(srst == 1'b1) begin
         shmem_request[1]      <= 1'b0;
         shmem_wren[1]         <= 1'b0;
         shmem_addr_array[1]   <= 1024;
         shmem_datain_array[1] <= 1024;
      end
      else begin
         if(shmem_addr_array[1] != 1023) begin
            shmem_request[1] <= 1'b1;
            shmem_wren[1]    <= 1'b1;
            if(shmem_done[1] == 1'b1) begin
               shmem_addr_array[1]   <= shmem_addr_array[1] + 1;
               shmem_datain_array[1] <= shmem_datain_array[1] + 1;
            end
         end
         else begin
            shmem_request[1] <= 1'b0;
            shmem_wren[1]    <= 1'b0;
         end
      end
   end

   // Third interface
   always @(posedge clk) begin
      if(srst == 1'b1) begin
         shmem_request[2]      <= 1'b0;
         shmem_wren[2]         <= 1'b0;
         shmem_addr_array[2]   <= 2048;
         shmem_datain_array[2] <= 2048;
      end
      else begin
         if(shmem_addr_array[2] != 1023) begin
            shmem_request[2] <= 1'b1;
            shmem_wren[2]    <= 1'b1;
            if(shmem_done[2] == 1'b1) begin
               shmem_addr_array[2]   <= shmem_addr_array[2] + 1;
               shmem_datain_array[2] <= shmem_datain_array[2] + 1;
            end
         end
         else begin
            shmem_request[2] <= 1'b0;
            shmem_wren[2]    <= 1'b0;
         end
      end
   end

   // Fourth interface
   always @(posedge clk) begin
      if(srst == 1'b1) begin
         shmem_request[3]      <= 1'b0;
         shmem_wren[3]         <= 1'b0;
         shmem_addr_array[3]   <= 3072;
         shmem_datain_array[3] <= 3072;
      end
      else begin
         if(shmem_addr_array[3] != 1023) begin
            shmem_request[3] <= 1'b1;
            shmem_wren[3]    <= 1'b1;
            if(shmem_done[3] == 1'b1) begin
               shmem_addr_array[3]   <= shmem_addr_array[3] + 1;
               shmem_datain_array[3] <= shmem_datain_array[3] + 1;
            end
         end
         else begin
            shmem_request[3] <= 1'b0;
            shmem_wren[3]    <= 1'b0;
         end
      end
   end


/* -----\/----- EXCLUDED -----\/-----
   always @(posedge clk) begin
      case(cpt)
         0: begin
            shmem_request  = 4'b0000;
            shmem_wren     = 4'b0000;
            shmem_addr     = 48'h000_000_000_000;
            shmem_datain   = 32'h00_00_00_00;
         end

         2: begin
            shmem_request  = 4'b0001;
            shmem_wren     = 4'b0000;
            shmem_addr     = 48'h000_000_000_000;
            shmem_datain   = 32'h00_00_00_00;
         end

         4: begin
            shmem_request  = 4'b0011;
            shmem_wren     = 4'b0000;
            shmem_addr     = 48'h000_000_000_000;
            shmem_datain   = 32'h00_00_00_00;
         end

         8: begin
            shmem_request  = 4'b0111;
            shmem_wren     = 4'b0000;
            shmem_addr     = 48'h000_000_000_000;
            shmem_datain   = 32'h00_00_00_00;
         end

         12: begin
            shmem_request  = 4'b1111;
            shmem_wren     = 4'b0000;
            shmem_addr     = 48'h000_000_000_000;
            shmem_datain   = 32'h00_00_00_00;
         end

         16: begin
            shmem_request  = 4'b1100;
            shmem_wren     = 4'b0000;
            shmem_addr     = 48'h000_000_000_000;
            shmem_datain   = 32'h00_00_00_00;
         end

      endcase
   end
 -----/\----- EXCLUDED -----/\----- */



endmodule
