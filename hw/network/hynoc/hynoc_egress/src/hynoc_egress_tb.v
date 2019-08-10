//                              -*- Mode: Verilog -*-
// Filename        : hynoc_egress_tb.v
// Description     :
// Author          : Christophe Clienti
// Created On      : Fri Jun 28 16:51:16 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Fri Jun 28 16:51:16 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module hynoc_egress_tb();

   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------

   localparam integer        NB_PORTS = 5;
   localparam integer        LOG2_FIFO_DEPTH = 5;
   localparam integer        PAYLOAD_WIDTH = 32;
   localparam integer        PRRA_PIPELINE = 0;
   localparam integer        FLIT_WIDTH = PAYLOAD_WIDTH+1;
   localparam integer        MUX_INPUT_WIDTH = (NB_PORTS-1)*(FLIT_WIDTH);


   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------

   wire                      wsrst;
   wire                      wclk;
   wire                      wen;
   wire [FLIT_WIDTH-1:0]     wdata;
   reg [LOG2_FIFO_DEPTH:0]   wlevel;
   reg                       router_srst;
   reg                       router_clk;
   wire [NB_PORTS-2:0]       to_ingress_grant;
   wire [NB_PORTS-2:0]       to_ingress_afull;
   reg [NB_PORTS-2:0]        from_ingress_request;
   reg [NB_PORTS-2:0]        from_ingress_write;
   reg [MUX_INPUT_WIDTH-1:0] from_ingress_data;

   integer                   cpt;


   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------

   hynoc_egress
   #(
      .NB_PORTS         (NB_PORTS),
      .LOG2_FIFO_DEPTH  (LOG2_FIFO_DEPTH),
      .PAYLOAD_WIDTH    (PAYLOAD_WIDTH),
      .PRRA_PIPELINE    (PRRA_PIPELINE),
      .FLIT_WIDTH       (FLIT_WIDTH),
      .MUX_INPUT_WIDTH  (MUX_INPUT_WIDTH)
   )
   hynoc_egress_inst
   (
      .wsrst                (wsrst),
      .wclk                 (wclk),
      .wen                  (wen),
      .wdata                (wdata),
      .wlevel               (wlevel),
      .router_srst          (router_srst),
      .router_clk           (router_clk),
      .to_ingress_grant     (to_ingress_grant),
      .to_ingress_afull     (to_ingress_afull),
      .from_ingress_request (from_ingress_request),
      .from_ingress_write   (from_ingress_write),
      .from_ingress_data    (from_ingress_data)
   );


   //----------------------------------------------------------------
   // Clock and reset generation
   //----------------------------------------------------------------

   initial begin
      router_clk       = 0;
      router_srst      = 1;
      #10 router_srst  = 1;
      #20 router_srst  = 0;
   end

   always
     #2 router_clk = !router_clk;


   //----------------------------------------------------------------
   // Value Change Dump
   //----------------------------------------------------------------

   initial begin
      $dumpfile ("hynoc_egress_tb.vcd");
      $dumpvars;
    end


   //----------------------------------------------------------------
   // Monitor values
   //----------------------------------------------------------------

   initial begin
      $display("\tcycle,\treq,\tgrant,\tstop,\tpayload");
      $monitor("%d,\t%b,\t%b,\t%b,\t%x", cpt,
               from_ingress_request, to_ingress_grant, wdata[FLIT_WIDTH-1], wdata[FLIT_WIDTH-2:0]);
   end


   //----------------------------------------------------------------
   // Test vectors
   //----------------------------------------------------------------

   initial begin
      cpt = 0;
      @(cpt == 42) #4 $finish;
   end

   always @(posedge router_clk) begin
     if(router_srst == 1'b1) begin
        cpt <= 0;
     end
     else begin
        cpt <= cpt + 1;
     end
   end

   always @(cpt) begin
      case(cpt)
         0: begin
            wlevel                = 0;
            from_ingress_request  = 4'b0000;
            from_ingress_write    = 4'b0000;
            from_ingress_data     = {1'b0, 32'h0000_0000,
                                     1'b0, 32'h0000_0000,
                                     1'b0, 32'h0000_0000,
                                     1'b0, 32'h0000_0000};
         end

         8: begin
            wlevel                = 6'h32;
            from_ingress_request  = 4'b1100;
            from_ingress_write    = 4'b0100;
            from_ingress_data     = {1'b1, 32'h3333_3333,
                                     1'b0, 32'h2222_2222,
                                     1'b1, 32'h1111_1111,
                                     1'b0, 32'hFFFF_FFFF};
         end

         15: begin
            wlevel                = 6'h32;
            from_ingress_request  = 4'b1000;
            from_ingress_write    = 4'b1000;
            from_ingress_data     = {1'b1, 32'h3333_3333,
                                     1'b0, 32'h2222_2222,
                                     1'b1, 32'h1111_1111,
                                     1'b0, 32'hFFFF_FFFF};
         end

         20: begin
            wlevel                = 6'h32;
            from_ingress_request  = 4'b0000;
            from_ingress_write    = 4'b0000;
            from_ingress_data     = {1'b1, 32'h3333_3333,
                                     1'b0, 32'h2222_2222,
                                     1'b1, 32'h1111_1111,
                                     1'b0, 32'hFFFF_FFFF};
         end

         24: begin
            wlevel                = 6'h32;
            from_ingress_request  = 4'b1110;
            from_ingress_write    = 4'b0010;
            from_ingress_data     = {1'b1, 32'h3333_3333,
                                     1'b0, 32'h2222_2222,
                                     1'b1, 32'h1111_1111,
                                     1'b0, 32'hFFFF_FFFF};
         end

         28: begin
            wlevel                = 6'h32;
            from_ingress_request  = 4'b1100;
            from_ingress_write    = 4'b0100;
            from_ingress_data     = {1'b1, 32'h3333_3333,
                                     1'b0, 32'h2222_2222,
                                     1'b1, 32'h1111_1111,
                                     1'b0, 32'hFFFF_FFFF};
         end

         32: begin
            wlevel                = 6'h32;
            from_ingress_request  = 4'b1001;
            from_ingress_write    = 4'b1000;
            from_ingress_data     = {1'b1, 32'h3333_3333,
                                     1'b0, 32'h2222_2222,
                                     1'b1, 32'h1111_1111,
                                     1'b0, 32'hFFFF_FFFF};
         end

         36: begin
            wlevel                = 6'h32;
            from_ingress_request  = 4'b0001;
            from_ingress_write    = 4'b0001;
            from_ingress_data     = {1'b1, 32'h3333_3333,
                                     1'b0, 32'h2222_2222,
                                     1'b1, 32'h1111_1111,
                                     1'b0, 32'hFFFF_FFFF};
         end

         40: begin
            wlevel                = 6'h32;
            from_ingress_request  = 4'b0000;
            from_ingress_write    = 4'b0000;
            from_ingress_data     = {1'b1, 32'h3333_3333,
                                     1'b0, 32'h2222_2222,
                                     1'b1, 32'h1111_1111,
                                     1'b0, 32'hFFFF_FFFF};
         end
      endcase
   end


endmodule
