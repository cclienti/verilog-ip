// Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

`timescale 1 ns / 100 ps

module sclkfiforeg
  #(parameter WIDTH = 32)

   (input wire             clk,
    input wire             srst,

    input wire             ren,
    output reg [WIDTH-1:0] rdata,
    output reg             rempty,

    input wire             wen,
    input wire [WIDTH-1:0] wdata,
    output reg             wfull);

   //----------------------------------------------------------------
   // Data Path
   //----------------------------------------------------------------

   always @(posedge clk) begin
      if (wen == 1'b1) begin
         rdata <= wdata;
      end
   end

   //----------------------------------------------------------------
   // Empty/Full management
   //----------------------------------------------------------------

   always @(posedge clk) begin
      if (srst) begin
         wfull <= 0;
      end
      else begin
         case ({wfull, wen, ren})
            3'b000: wfull <= 0;
            3'b001: wfull <= 0;
            3'b010: wfull <= 1;
            3'b011: wfull <= 0;
            3'b100: wfull <= 1;
            3'b101: wfull <= 0;
            3'b110: wfull <= 1;
            3'b111: wfull <= 1;
         endcase
      end
   end

   always @(posedge clk) begin
      if (srst) begin
         rempty <= 1;
      end
      else begin
         case ({rempty, wen, ren})
            3'b000: rempty <= 0;
            3'b001: rempty <= 1;
            3'b010: rempty <= 0;
            3'b011: rempty <= 0;
            3'b100: rempty <= 1;
            3'b101: rempty <= 1;
            3'b110: rempty <= 0;
            3'b111: rempty <= 1;
         endcase
      end
   end

endmodule
