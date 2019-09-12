//                              -*- Mode: Verilog -*-
// Filename        : shmemif_tb.v
// Description     : Multiport Memory Interface testbench
// Author          : Christophe Clienti
// Created On      : Fri Jul  5 08:08:30 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Fri Jul  5 08:08:30 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

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
   shmemif
   #(
      .NB_PORTS            (NB_PORTS),
      .LOG2_NB_PORTS       (LOG2_NB_PORTS),
      .ADDR_WIDTH          (ADDR_WIDTH),
      .DATA_WIDTH          (DATA_WIDTH),
      .REGISTER_MEM_OUTPUT (REGISTER_MEM_OUTPUT)
   )
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
      #10 srst  = 1;
      #20 srst  = 0;
   end

   always
     #2 clk = !clk;


   //----------------------------------------------------------------
   // Value Change Dump
   //----------------------------------------------------------------
   initial begin
      $dumpfile ("shmemif_tb.vcd");
      $dumpvars;
   end


   //----------------------------------------------------------------
   // Some usefull information
   //----------------------------------------------------------------
   genvar i;
   integer j;

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

   integer x1,x2,x3,x4;
   initial begin
      #50000;
      for(j=0; j<=ARRAY_BOUND; j=j+1) begin
         x1 = j;
         x2 = x1 + (2**ADDR_WIDTH)/4;
         x3 = x2 + (2**ADDR_WIDTH)/4;
         x4 = x3 + (2**ADDR_WIDTH)/4;

         $display("ram[%d]: %d \t ram[%0d]: %d \t ram[%d]: %d \t ram[%d]: %d",
                  x1[ADDR_WIDTH-1:0], dpmemrf_inst.ram[x1][ADDR_WIDTH-1:0],
                  x2[ADDR_WIDTH-1:0], dpmemrf_inst.ram[x2][ADDR_WIDTH-1:0],
                  x3[ADDR_WIDTH-1:0], dpmemrf_inst.ram[x3][ADDR_WIDTH-1:0],
                  x4[ADDR_WIDTH-1:0], dpmemrf_inst.ram[x4][ADDR_WIDTH-1:0]);
      end
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
