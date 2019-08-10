//                              -*- Mode: Verilog -*-
// Filename        : hynoc_ingress_tb.v
// Description     :
// Author          : Christophe
// Created On      : Sun Jun 23 12:03:37 2013
// Last Modified By: Christophe
// Last Modified On: Sun Jun 23 12:03:37 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module hynoc_ingress_tb;

   //----------------------------------------------------------------
   // Constants
   //----------------------------------------------------------------

   localparam integer NB_PORTS             = 5;
   localparam integer INDEX_WIDTH          = 4;
   localparam integer LOG2_FIFO_DEPTH      = 5;
   localparam integer PAYLOAD_WIDTH        = 32;
   localparam integer FLIT_WIDTH           = (PAYLOAD_WIDTH+1);
   localparam integer SINGLE_CLOCK_PORT    = 0;
   localparam integer ENABLE_MCAST_ROUTING = 1;
   localparam integer ENABLE_XY_ROUTING    = 0;

`include "hynoc_ingress_routing_list.v"


   //----------------------------------------------------------------
   // Signals
   //----------------------------------------------------------------

   reg                      wsrst;
   reg                      wclk;
   reg                      wen;
   reg [FLIT_WIDTH-1:0]     wdata;
   wire                     wfull;
   wire [LOG2_FIFO_DEPTH:0] wlevel;
   reg                      router_srst;
   reg                      router_clk;
   reg [NB_PORTS-2:0]       from_egress_grant;
   reg [NB_PORTS-2:0]       from_egress_afull;
   wire [NB_PORTS-2:0]      to_egress_request;
   wire                     to_egress_write;
   wire [FLIT_WIDTH-1:0]    to_egress_data;

   wire [FLIT_WIDTH-1:0]      egress_ref_rdata;
   wire [NB_PORTS-2:0]        egress_ref_rrequest;
   wire                       egress_ref_rempty;
   wire [LOG2_FIFO_DEPTH*2:0] egress_ref_rlevel;
   wire                       egress_ref_wsrst;
   wire                       egress_ref_wclk;
   reg                        egress_ref_wen;
   reg [FLIT_WIDTH-1:0]       egress_ref_wdata;
   reg [NB_PORTS-2:0]         egress_ref_wrequest;
   wire [LOG2_FIFO_DEPTH*2:0] egress_ref_wlevel;
   reg                        egress_valid;


   reg                      arst;
   integer                  rcpt, wcpt;


   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------

   hynoc_ingress
   #(
      .NB_PORTS             (NB_PORTS),
      .INDEX_WIDTH          (INDEX_WIDTH),
      .LOG2_FIFO_DEPTH      (LOG2_FIFO_DEPTH),
      .PAYLOAD_WIDTH        (PAYLOAD_WIDTH),
      .FLIT_WIDTH           (FLIT_WIDTH),
      .SINGLE_CLOCK_PORT    (SINGLE_CLOCK_PORT),
      .ENABLE_MCAST_ROUTING (ENABLE_MCAST_ROUTING),
      .ENABLE_XY_ROUTING    (ENABLE_XY_ROUTING)
   )
   hynoc_ingress_inst
   (
      .wsrst             (wsrst),
      .wclk              (wclk),
      .wen               (wen),
      .wdata             (wdata),
      .wlevel            (wlevel),
      .wfull             (wfull),
      .router_srst       (router_srst),
      .router_clk        (router_clk),
      .from_egress_grant (from_egress_grant),
      .from_egress_afull (from_egress_afull),
      .to_egress_request (to_egress_request),
      .to_egress_write   (to_egress_write),
      .to_egress_data    (to_egress_data)
   );

   //----------------------------------------------------------------
   // logs
   //----------------------------------------------------------------

   report #(.UNIT("us")) rpt();


   //----------------------------------------------------------------
   // Clock and reset generation
   //----------------------------------------------------------------

   initial begin
      router_clk  = 0;
      wclk        = 0;
      arst        = 1;
      #10.2 arst  = 1;
      #13.4 arst  = 0;
   end

   always
     #2 router_clk = !router_clk;

   generate
      if (SINGLE_CLOCK_PORT != 0) begin
         always @(*) wclk = router_clk;
      end
      else begin
         always
           #3 wclk = !wclk;
      end
   endgenerate

   always @(posedge router_clk) begin
      router_srst <= arst;
   end

   always @(posedge wclk) begin
      wsrst <= arst;
   end


   //----------------------------------------------------------------
   // VCD
   //----------------------------------------------------------------

   initial begin
      $dumpfile ("hynoc_ingress_tb.vcd");
      $dumpvars;
   end


   //----------------------------------------------------------------
   // Test vectors
   //----------------------------------------------------------------

   integer i;

   // write the fifo
   initial begin
      wen = 0;
      wdata = 0;
      egress_ref_wen = 0;
      egress_ref_wdata = 0;
      egress_ref_wrequest = 0;

      // Wait reset release
      @(negedge router_srst);
      repeat(8) @(posedge wclk);

      // bad packet
      wen <= 1;
      wdata <= {1'b1, 32'h0123_4567};
      egress_ref_wen <= 0;
      egress_ref_wdata <= 0;
      egress_ref_wrequest <= 0;
      @(posedge wclk);

      // bad packet
      wen  <= 1;
      wdata <= {1'b0, 32'h8123_4567};
      egress_ref_wen <= 0;
      egress_ref_wdata <= 0;
      egress_ref_wrequest <= 0;
      @(posedge wclk);

      wen <= 1;
      wdata <= {1'b1, 32'haabb_ccdd};
      egress_ref_wen <= 0;
      egress_ref_wdata <= 0;
      egress_ref_wrequest <= 0;
      @(posedge wclk);

      // new ucast packet
      wen <= 1;
      wdata <= {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 28'b00_00_00_00_00_00_00_00_00_00_11_01_0001};
      egress_ref_wen <= 1;
      egress_ref_wdata <= {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 28'b00_00_00_00_00_00_00_00_00_00_11_01_0000};
      egress_ref_wrequest <= 8;
      @(posedge wclk);

      for(i=11; i<=50; i=i+1) begin
         wen <= 1;
         egress_ref_wen <= 1;
         wdata[PAYLOAD_WIDTH] <= 1'b0;
         wdata[PAYLOAD_WIDTH-1:0] <= i;
         egress_ref_wdata[PAYLOAD_WIDTH] <= 1'b0;
         egress_ref_wdata[PAYLOAD_WIDTH-1:0] <= i;
         @(posedge wclk);
      end

      wen <= 1;
      wdata <= {1'b1, 32'h0000_0000};
      egress_ref_wen <= 1'b1;
      egress_ref_wdata <= {1'b1, 32'h0000_0000};
      @(posedge wclk);

      // new ucast packet, no routing flit transmitted
      wen <= 1;
      wdata <= {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 28'b00_00_00_00_00_00_00_00_00_10_10_01_0000};
      egress_ref_wen <= 0;
      egress_ref_wdata <= 0;
      egress_ref_wrequest <= 2;
      @(posedge wclk);

      wen <= 1;
      wdata <= {1'b1, 32'hCAFE_DECA};
      egress_ref_wen <= 1;
      egress_ref_wdata <= {1'b1, 32'hCAFE_DECA};
      @(posedge wclk);

      // new ucast packet with two header flits
      wen <= 1;
      wdata <= {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 28'b00_00_00_00_00_00_00_00_00_10_10_01_0010};
      egress_ref_wen <= 1;
      egress_ref_wdata <= {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 28'b00_00_00_00_00_00_00_00_00_10_10_01_0001};
      egress_ref_wrequest <= 4;
      @(posedge wclk);

      wen <= 1;
      wdata <= {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 28'b00_00_00_00_00_00_00_00_00_10_10_01_0010};
      egress_ref_wen <= 1;
      egress_ref_wdata <= {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 28'b00_00_00_00_00_00_00_00_00_10_10_01_0010};
      @(posedge wclk);

      wen <= 1;
      wdata <= {1'b1, 32'hDEAD_BABE};
      egress_ref_wen <= 1;
      egress_ref_wdata <= {1'b1, 32'hDEAD_BABE};
      @(posedge wclk);

       // new ucast packet with two header flits, only one transmitted
      wen <= 1;
      wdata <= {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 28'b00_00_00_00_00_00_00_00_00_10_10_01_0000};
      egress_ref_wen <= 0;
      egress_ref_wdata <= 0;
      egress_ref_wrequest <= 2;
      @(posedge wclk);

      wen <= 1;
      wdata <= {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 28'b00_00_00_00_00_00_00_00_00_10_10_01_0010};
      egress_ref_wen <= 1;
      egress_ref_wdata <= {1'b0, PROTO_ROUTING_UCAST_CIRCUIT_SWITCH, 28'b00_00_00_00_00_00_00_00_00_10_10_01_0010};
      @(posedge wclk);

      wen <= 1;
      wdata <= {1'b1, 32'h89ab_cdef};
      egress_ref_wen <= 1;
      egress_ref_wdata <= {1'b1, 32'h89ab_cdef};
      @(posedge wclk);

      // new mcast packet
      wen <= 1;
      wdata <= {1'b0, PROTO_ROUTING_MCAST_CIRCUIT_SWITCH, 28'b0000_0000_0000_0000_0111_1101_0001};
      egress_ref_wen <= 1;
      egress_ref_wdata <= {1'b0, PROTO_ROUTING_MCAST_CIRCUIT_SWITCH, 28'b0000_0000_0000_0000_0111_1101_0000};
      egress_ref_wrequest <= 7;
      @(posedge wclk);

      for(i=111; i<=120; i=i+1) begin
         wen <= 1;
         egress_ref_wen <= 1;
         wdata[PAYLOAD_WIDTH] <= 1'b0;
         wdata[PAYLOAD_WIDTH-1:0] <= i;
         egress_ref_wdata[PAYLOAD_WIDTH] <= 1'b0;
         egress_ref_wdata[PAYLOAD_WIDTH-1:0] <= i;
         @(posedge wclk);
      end

      wen <= 1;
      wdata <= {1'b1, 32'h0000_0000};
      egress_ref_wen <= 1'b1;
      egress_ref_wdata <= {1'b1, 32'h0000_0000};
      @(posedge wclk);

      // End of test
      wen <= 0;
      wdata <= 0;
      egress_ref_wen <= 0;
      egress_ref_wdata <= 0;
      egress_ref_wrequest <= 0;
      @(posedge wclk);

      // egress_ref write port uses wclk
      // egress read port uses wclk
      while (egress_ref_rlevel > 0) @(posedge wclk);
      repeat(8) @(posedge wclk);

      if (egress_ref_wlevel > 0) begin
         $display("error: remaining data in the reference fifo");
      end

      $finish();
   end

   //----------------------------------------------------------------
   // Egress Response
   //----------------------------------------------------------------

   //egress grant simulation. Pipeline to assert grant at the same time
   //that from_egress_afull
   reg [NB_PORTS-2:0]       from_egress_grant_reg;
   always @(posedge router_clk) begin
      from_egress_grant_reg <= to_egress_request;
      from_egress_grant     <= from_egress_grant_reg;
   end


   //egress fifo simulation
   wire                       egress_rsrst;
   wire                       egress_rclk;
   reg                        egress_ren;
   wire [FLIT_WIDTH-1:0]      egress_rdata;
   wire [NB_PORTS-2:0]        egress_rrequest;
   wire                       egress_rempty;
   wire [LOG2_FIFO_DEPTH*2:0] egress_rlevel;
   wire                       egress_wsrst;
   wire                       egress_wclk;
   reg                        egress_wen;
   reg [FLIT_WIDTH-1:0]       egress_wdata;
   reg [NB_PORTS-2:0]         egress_wrequest;
   wire [LOG2_FIFO_DEPTH*2:0] egress_wlevel;

   dclkfifolut
   #(
      .LOG2_FIFO_DEPTH (LOG2_FIFO_DEPTH*2),
      .FIFO_WIDTH      (FLIT_WIDTH + NB_PORTS - 1)
   )
   egress_fifo_inst
   (
      .rsrst   (egress_rsrst),
      .rclk    (egress_rclk),
      .ren     (egress_ren),
      .rdata   ({egress_rdata, egress_rrequest}),
      .rlevel  (egress_rlevel),
      .rempty  (egress_rempty),
      .wsrst   (egress_wsrst),
      .wclk    (egress_wclk),
      .wen     (egress_wen),
      .wdata   ({egress_wdata, egress_wrequest}),
      .wlevel  (egress_wlevel),
      .wfull   ()
   );

   assign egress_rsrst = wsrst;
   assign egress_rclk  = wclk;

   assign egress_wsrst  = router_srst;
   assign egress_wclk   = router_clk;

   always @(posedge router_clk) begin
      if(router_srst == 1'b1) begin
         egress_wen        <= 1'b0;
         egress_wdata      <= 0;
         from_egress_afull <= 1'b0;
      end
      else begin
         egress_wen        <= to_egress_write;
         egress_wdata      <= to_egress_data;
         egress_wrequest   <= to_egress_request;
         from_egress_afull <= {(NB_PORTS-1){(egress_wlevel >= 2**LOG2_FIFO_DEPTH-5)}} & from_egress_grant_reg;
      end
   end

   always @(posedge egress_rclk) begin
      if(egress_rsrst == 1'b1) begin
         egress_ren <= 1'b0;
      end
      else begin
         if(({$random} % 4) == 3) begin
            egress_ren <= !egress_rempty;
         end
         else begin
            egress_ren <= 1'b0;
         end
      end
   end


   //----------------------------------------------------------------
   // Checker
   //----------------------------------------------------------------

   dclkfifolut
   #(
      .LOG2_FIFO_DEPTH (LOG2_FIFO_DEPTH*2),
      .FIFO_WIDTH      (FLIT_WIDTH + NB_PORTS - 1)
   )
   egress_fifo_inst_ref
   (
      .rsrst   (egress_rsrst),
      .rclk    (egress_rclk),
      .ren     (egress_ren),
      .rdata   ({egress_ref_rdata, egress_ref_rrequest}),
      .rlevel  (egress_ref_rlevel),
      .rempty  (egress_ref_rempty),
      .wsrst   (egress_ref_wsrst),
      .wclk    (egress_ref_wclk),
      .wen     (egress_ref_wen),
      .wdata   ({egress_ref_wdata, egress_ref_wrequest}),
      .wlevel  (egress_ref_wlevel),
      .wfull   ()
   );

   assign egress_ref_wsrst = wsrst;
   assign egress_ref_wclk  = wclk;

   always @(posedge egress_rclk) begin
      if(egress_rsrst == 1'b1) begin
         egress_valid <= 1'b0;
      end
      else begin
         egress_valid <= egress_ren;
      end
   end

   always @(posedge egress_rclk) begin
      if (egress_valid == 1'b1) begin
         if (egress_ref_rdata == egress_rdata) begin
            $sformat(rpt.local_str, "rdata %h ok", egress_rdata);
            rpt.info(rpt.local_str);
         end
         else begin
            $sformat(rpt.local_str, "rdata ko, obtained h%h instead of h%h", egress_rdata, egress_ref_rdata);
            rpt.error(rpt.local_str);
         end
      end
   end

   always @(posedge egress_rclk) begin
      if (egress_valid == 1'b1) begin
         if (egress_ref_rrequest == egress_rrequest) begin
            $sformat(rpt.local_str, "request h%h ok", egress_rrequest);
            rpt.info(rpt.local_str);
         end
         else begin
            $sformat(rpt.local_str, "request ko, obtained h%h instead of h%h", egress_rrequest, egress_ref_rrequest);
            rpt.error(rpt.local_str);
         end
      end
   end

endmodule
