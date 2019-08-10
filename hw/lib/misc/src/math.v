//                              -*- Mode: Verilog -*-
// Filename        : math.v
// Description     : Various Maths Constant Functions
// Author          : Christophe Clienti
// Created On      : Fri Jun 28 16:10:53 2013
// Last Modified By: Christophe Clienti
// Last Modified On: Fri Jun 28 16:10:53 2013
// Update Count    : 0
// Status          : Unknown, Use with caution!



// Compute log2 at elab time
// Picked from http://www.beyond-circuits.com/wordpress/2008/11/constant-functions/
function integer log2;
   input integer value;
   begin
      value = value-1;
      for (log2=0; value>0; log2=log2+1) begin
         value = value>>1;
      end
   end
endfunction
