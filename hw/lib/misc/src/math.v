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
