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
// Title         : AXI Stream Register Slice
//-----------------------------------------------------------------------------
// File          : axi_stream_reg_slice.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-24
// Last modified : 2026-08-24
//-----------------------------------------------------------------------------
// Description: Full register slice (skid buffer) for an AXI stream link.
// Every signal of both interfaces is driven by a register: the payload
// and tvalid through the output register, tready by the skid-occupied
// flag alone -- so no combinational arc crosses the slice in either
// direction, and a chain of modules with combinational tready
// passthrough can be cut anywhere at the cost of one cycle of latency.
//
// A registered tready announces last cycle's willingness, so there is
// always one exposed cycle where the master launches a beat into a
// slice that just stalled; the skid register catches exactly that beat.
// Two storage slots is what makes the slice full-throughput: with a
// single one, a registered tready could only sustain one beat every
// other cycle. The skid is only ever occupied transiently after a
// downstream stall, and tready recovers one cycle after it drains.

`timescale 1 ns / 100 ps

module axi_stream_reg_slice #(
    parameter int DATA_WIDTH = 8,
    parameter int USER_WIDTH = 1
)(
    input logic                    clock,
    input logic                    sreset,

    // AXI Stream input
    input logic [DATA_WIDTH-1:0]   s_axi_tdata,
    input logic [USER_WIDTH-1:0]   s_axi_tuser,
    input logic                    s_axi_tvalid,
    input logic                    s_axi_tlast,
    output logic                   s_axi_tready,

    // AXI Stream output, one cycle behind the input
    output logic [DATA_WIDTH-1:0]  m_axi_tdata,
    output logic [USER_WIDTH-1:0]  m_axi_tuser,
    output logic                   m_axi_tvalid,
    output logic                   m_axi_tlast,
    input logic                    m_axi_tready
);

    localparam int PAY_W = USER_WIDTH + 1 + DATA_WIDTH;

    logic [PAY_W-1:0] s_pay;
    logic [PAY_W-1:0] o_pay;   // output register, drives the master side
    logic [PAY_W-1:0] k_pay;   // skid register, catches the exposed beat
    logic             o_valid;
    logic             k_valid;
    logic             s_accept;
    logic             o_load;

    assign s_pay = {s_axi_tuser, s_axi_tlast, s_axi_tdata};

    // tready is the skid-occupied flag alone: no combinational arc from
    // any input reaches it. Whenever it is high, the skid slot is free
    // to catch whatever the master launches on the announced ready.
    assign s_axi_tready = !k_valid;
    assign s_accept     = s_axi_tvalid && s_axi_tready;

    // The output register takes a new payload when empty or consumed
    assign o_load = !o_valid || m_axi_tready;

    always_ff @(posedge clock) begin
        if (sreset) begin
            o_valid <= 1'b0;
            k_valid <= 1'b0;
        end
        else begin
            if (o_load) begin
                // The skid drains first: it holds the older beat. The
                // payload only loads when a beat actually moves in, so
                // an idle slice does not chase the master's tdata
                // toggling with all its output flops.
                if (k_valid || s_accept) begin
                    o_pay <= k_valid ? k_pay : s_pay;
                end
                o_valid <= k_valid || s_accept;
                k_valid <= 1'b0;
            end
            else if (s_accept) begin
                // Output stalled and full: the exposed beat lands here
                k_pay   <= s_pay;
                k_valid <= 1'b1;
            end
        end
    end

    assign {m_axi_tuser, m_axi_tlast, m_axi_tdata} = o_pay;
    assign m_axi_tvalid = o_valid;

endmodule
