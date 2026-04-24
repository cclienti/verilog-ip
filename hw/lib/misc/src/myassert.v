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



// Picked from stackoverflow

module myassert(input clk,
                input test);

   parameter MYSTRING = "UNKNOWN";

   always @(posedge clk) begin
      if (test !== 1) begin
         $display("ASSERTION FAILED %s in %m", MYSTRING);
         $finish;
      end
   end

endmodule // myassert
