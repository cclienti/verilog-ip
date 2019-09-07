//                              -*- Mode: Verilog -*-
// Filename        : dclkfifolut_tb.v
// Description     : Testbench of Dual Clock Fifo based on LUT memory
// Author          : Christophe Clienti
// Created On      : Tue Jun 18 14:35:09 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Tue Jun 18 14:35:09 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!
// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps


module dclkfifolut_tb;

   //----------------------------------------------------------------
   //Constants
   //----------------------------------------------------------------
   localparam LOG2_FIFO_DEPTH = 3;
   localparam FIFO_WIDTH      = 8;

   //----------------------------------------------------------------
   //Signals
   //----------------------------------------------------------------
   //DUT Signals
   reg                      rsrst;
   reg                      rclk;
   reg                      ren;
   wire [FIFO_WIDTH-1:0]    rdata;
   wire                     rempty;
   wire [LOG2_FIFO_DEPTH:0] rlevel;
   reg                      wsrst;
   reg                      wclk;
   reg                      wen;
   reg  [FIFO_WIDTH-1:0]    wdata;
   wire                     wfull;
   wire [LOG2_FIFO_DEPTH:0] wlevel;

   reg                      arst;

   // ref signals

   // counter
   integer                  rcpt, wcpt;

   //----------------------------------------------------------------
   // DUT
   //----------------------------------------------------------------
   dclkfifolut
   #(
      .LOG2_FIFO_DEPTH (LOG2_FIFO_DEPTH),
      .FIFO_WIDTH      (FIFO_WIDTH)
   )
   DUT
   (
      .rsrst   (rsrst),
      .rclk    (rclk),
      .ren     (ren),
      .rdata   (rdata),
      .rempty  (rempty),
      .rlevel  (rlevel),
      .wsrst   (wsrst),
      .wclk    (wclk),
      .wen     (wen),
      .wdata   (wdata),
      .wfull   (wfull),
      .wlevel  (wlevel)
   );

   //----------------------------------------------------------------
   // Clock and Reset Generation
   //----------------------------------------------------------------
   initial begin
      rclk        = 0;
      wclk        = 0;
      arst        = 1;
      #10.2 arst  = 1;
      #13.4 arst  = 0;
   end

   always
     #2 rclk = !rclk;

   always
     #3 wclk = !wclk;

   always @(posedge rclk) begin
      rsrst <= arst;
   end

   always @(posedge wclk) begin
      wsrst <= arst;
   end


   //----------------------------------------------------------------
   // Value Change Dump
   //----------------------------------------------------------------
   initial  begin
      $dumpfile ("dclkfifolut_tb.vcd");
      $dumpvars;
   end

   //----------------------------------------------------------------
   // Test vectors
   //----------------------------------------------------------------
   initial
     #1000 $finish;

   always @(posedge rclk)
     if(rsrst) begin
        rcpt <= 0;
     end
     else begin
        rcpt <= rcpt + 1;
     end

   always @(posedge wclk)
     if(wsrst) begin
        wcpt <= 0;
     end
     else begin
        wcpt <= wcpt + 1;
     end

   // write the fifo
   always @(wcpt) begin
      // write first pattern
      if ((wcpt >= 1) && (wcpt<=7)) begin
         wen    = 1'b1;
         wdata  = wcpt;
      end

      else if (wcpt == 9) begin
         wen    = 1'b1;
         wdata  = 8;
      end

      // try to overflow the fifo with one more write
      else if (wcpt == 10) begin
         wen    = 1'b1;
         wdata  = wcpt;
      end

      // write another pattern after corruption attempt
      else if ((wcpt >= 21) && (wcpt<=28)) begin
         wen    = 1'b1;
         wdata  = wcpt;
      end

      else begin
         wen    = 1'b0;
         wdata  = 0;
      end
   end

   // read the fifo
   always @(rcpt) begin
      if ((rcpt >= 21) && (rcpt<=27)) begin
        ren  = 1'b1;
      end

      else if (rcpt == 29) begin
        ren = 1'b1;
      end

      // try to overflow the fifo with one more read
      else if (rcpt == 30) begin
        ren = 1'b1;
      end

      // read continously the fifo
      else if (rcpt >= 33) begin
         ren = ~rempty;
      end

      else begin
        ren  = 1'b0;
      end
   end

   //----------------------------------------------------------------
   // Reference
   //----------------------------------------------------------------
   reg [FIFO_WIDTH-1:0] ref_data [15:0];

   initial begin
      ref_data[0] = 1;
      ref_data[1] = 2;
      ref_data[2] = 3;
      ref_data[3] = 4;
      ref_data[4] = 5;
      ref_data[5] = 6;
      ref_data[6] = 7;
      ref_data[7] = 8;
      ref_data[8] = 21;
      ref_data[9] = 22;
      ref_data[10] = 23;
      ref_data[11] = 24;
      ref_data[12] = 25;
      ref_data[13] = 26;
      ref_data[14] = 27;
      ref_data[15] = 28;
   end

   //----------------------------------------------------------------
   // Checks
   //----------------------------------------------------------------
   reg rcheck;
   integer rcheck_ptr = 0;
   wire [FIFO_WIDTH-1:0] rcheck_data;

   assign rcheck_data = ref_data[rcheck_ptr];

   always @(posedge rclk) begin
      rcheck <= ren & ~rempty;
   end

   always @(posedge rclk) begin
      if (rcheck) begin
         rcheck_ptr <= rcheck_ptr + 1;

         $write("rcpt(%0d) rdata(h'%0h) ref(h'%0h)", rcpt, rdata, rcheck_data);

         if (rcheck_data != rdata) begin
            $display(" -> Error");
         end
         else begin
            $display(" -> Ok");
         end

      end
   end

endmodule
