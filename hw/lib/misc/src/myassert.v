//                              -*- Mode: Verilog -*-
// Filename        : assert.v
// Description     : assertion module
// Author          : Christophe Clienti
// Created On      : Sun Feb 24 17:23:00 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Sun Feb 24 17:23:00 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!

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
