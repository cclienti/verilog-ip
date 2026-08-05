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

   localparam integer RX_FLITS_W_REF = 22;
   localparam [63:0]  RX_SUM_W_REF   = 64'h0000000fccccccc7;
   localparam integer RX_FLITS_G_REF = 993;
   localparam [63:0]  RX_SUM_G_REF   = 64'h0000000000000080;

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

   //----------------------------------------------------------------
   // Checker
   //----------------------------------------------------------------
   // The stimulus is a fixed hand-written sequence and these outputs
   // were verified by eye until now. Count and sum of what the DUT
   // drives are blessed from that eyeball-verified run; a mismatch
   // means the behaviour changed -- re-bless deliberately, never to
   // make the run pass.
   integer   rx_flits_w = 0;
   reg [63:0] rx_sum_w  = 0;
   integer   rx_flits_g = 0;
   reg [63:0] rx_sum_g  = 0;

   always @(posedge wclk) begin
      if (wen) begin
         rx_flits_w <= rx_flits_w + 1;
         rx_sum_w   <= rx_sum_w + wdata;
      end
   end

   always @(posedge wclk) begin
      if (!router_srst) begin
         rx_flits_g <= rx_flits_g + 1;
         rx_sum_g   <= rx_sum_g + {30'b0, to_ingress_grant};
      end
   end

   initial begin
      #4000;
      $display("rx_w: %0d flits sum 64'h%h", rx_flits_w, rx_sum_w);
      $display("rx_g: %0d flits sum 64'h%h", rx_flits_g, rx_sum_g);
      if (rx_flits_w === RX_FLITS_W_REF && rx_sum_w === RX_SUM_W_REF && rx_flits_g === RX_FLITS_G_REF && rx_sum_g === RX_SUM_G_REF)
        $display("hynoc_egress_tb: ALL TESTS PASSED");
      else begin
        $display("hynoc_egress_tb: delivered stream differs from the blessed reference");
        $display("hynoc_egress_tb: 1 ERROR(S)");
      end
      $finish;
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
