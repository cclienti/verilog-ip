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

module adderc_tb () ;
   //-------------------------------------------------
   // Parameters
   //-------------------------------------------------

   parameter IS_REG_OUT = 1;
   parameter WIDTH = 16;


   //-------------------------------------------------
   // DUT
   //-------------------------------------------------

   reg              clk, srst, enable;
   reg              sub_nadd, cin;
   reg [WIDTH-1:0]  a, b;

   wire [WIDTH-1:0] out;
   wire             cout;

   reg [WIDTH-1:0]  out_ref, out_ref_i;
   reg              cout_ref, cout_ref_i;

   integer          cpt=0;


   adderc #(.IS_REG_OUT(IS_REG_OUT),
            .WIDTH(WIDTH))
   DUT(.out(out), .cout(cout),
       .clk(clk), .srst(srst), .enable(enable),
       .sub_nadd(sub_nadd) , .cin(cin), .a(a), .b(b));


   //-------------------------------------------------
   // Facilities
   //-------------------------------------------------

   initial begin
      clk = 0;
      srst = 1;
      enable = 1;
      #10 srst = 1;
      #10 srst = 0;
   end

   always
     #2 clk = !clk;

   initial  begin
      $dumpfile ("adderc_tb.vcd");
      $dumpvars;
   end

   always @(posedge clk) begin
      if(srst) begin
         cpt <= 0;
      end
      else begin
         if (enable == 1'b1) begin
            cpt <= cpt + 1;
         end
      end
   end


   //-------------------------------------------------
   // Test vectors
   //-------------------------------------------------

   always @ (cpt) begin
      case (cpt)
         0: begin
            a = 0;
            b = 0;
            sub_nadd = 0;
            cin = 0;
            out_ref_i = 0;
            cout_ref_i = 0;
         end
         1: begin
            a = 1;
            b = 2;
            sub_nadd = 0;
            cin = 1;
            out_ref_i = 4;
            cout_ref_i = 0;
         end
         2: begin
            a = 1;
            b = 2;
            sub_nadd = 1;
            cin = sub_nadd;
            out_ref_i = 65535;
            cout_ref_i = 0;
         end
         3: begin
            a = -1;
            b = -1;
            sub_nadd = 0;
            cin = 0;
            out_ref_i = 65534;
            cout_ref_i = 1;
         end
         4: begin
            a = -1;
            b = 1;
            sub_nadd = 1;
            cin = sub_nadd;
            out_ref_i = 65534;
            cout_ref_i = 1;
         end
         10: begin
            $finish;
         end
      endcase
   end

   generate
      if (IS_REG_OUT == 0) begin
         always @(*) begin
            out_ref = out_ref_i;
            cout_ref = cout_ref_i;
         end
      end
      else begin
         always @(posedge clk) begin
            if(srst) begin
               out_ref <= 0;
               cout_ref <= 0;
            end
            else begin
               if (enable == 1'b1) begin
                  out_ref <= out_ref_i;
                  cout_ref <= cout_ref_i;
               end
            end
         end
      end
   endgenerate


   //-------------------------------------------------
   // Check Reference
   //-------------------------------------------------

   always @ (cpt) begin
      if (out != out_ref) begin
         $display("Error at cpt(%0d), out=%0d, out_ref=%0d", cpt, out, out_ref_i);
      end
      if (cout != cout_ref) begin
         $display("Error at cpt(%0d), cout=%0d, cout_ref=%0d", cpt, cout, cout_ref_i);
      end
   end

endmodule // adderc_tb
