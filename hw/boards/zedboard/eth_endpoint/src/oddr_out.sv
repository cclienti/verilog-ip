// SPDX-License-Identifier: CERN-OHL-P-2.0
// Copyright (c) 2026 Christophe Clienti
//
// This source describes Open Hardware and is licensed under the CERN-OHL-P v2.
// You may redistribute and modify this file under the terms of the CERN-OHL-P v2
// (https://ohwr.org/cern_ohl_p_v2.txt).
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING
// OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A PARTICULAR PURPOSE.
// Please see the CERN-OHL-P v2 for applicable conditions.

//-----------------------------------------------------------------------------
// Title         : ODDR Output Retimer
//-----------------------------------------------------------------------------
// File          : oddr_out.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-30
// Last modified : 2026-08-30
//-----------------------------------------------------------------------------
// Description: One output pin through a 7-series ODDR in SAME_EDGE
// mode: d1 and d2 are both captured at the rising edge, d1 drives the
// pin over the high half-period, d2 over the low one. Feeding d1 the
// previous cycle's value and d2 the current one makes the pin change
// only on falling edges -- half a period away from a receiver that
// samples on rising edges, whatever the routing or the corner. Under
// synthesis this is the hard OLOGIC primitive; simulators get a
// behavioral twin whose dual-edge process assigns non-blocking on
// both edges, so an observer at either edge deterministically reads
// the previous half-period's value.

`timescale 1 ns / 100 ps

module oddr_out (
    input logic  clock,
    input logic  d1,     // pin value for the high half-period
    input logic  d2,     // pin value for the low half-period
    output logic q
);

`ifdef SYNTHESIS
    ODDR
    #(
        .DDR_CLK_EDGE ("SAME_EDGE"),
        .INIT         (1'b0),
        .SRTYPE       ("SYNC")
    )
    oddr_inst
    (
        .Q  (q),
        .C  (clock),
        .CE (1'b1),
        .D1 (d1),
        .D2 (d2),
        .R  (1'b0),
        .S  (1'b0)
    );
`else
    logic d2_q;  // d2 held from the rising edge to the falling one

    always @(posedge clock or negedge clock) begin
        if (clock) begin
            d2_q <= d2;
            q    <= d1;
        end
        else begin
            q <= d2_q;
        end
    end
`endif

endmodule
