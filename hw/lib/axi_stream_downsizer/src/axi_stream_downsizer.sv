// SPDX-License-Identifier: CERN-OHL-P-2.0
// Copyright (c) 2025-2026 Christophe Clienti
//
// This source describes Open Hardware and is licensed under the CERN-OHL-P v2.
// You may redistribute and modify this file under the terms of the CERN-OHL-P v2
// (https://ohwr.org/cern_ohl_p_v2.txt).
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING
// OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A PARTICULAR PURPOSE.
// Please see the CERN-OHL-P v2 for applicable conditions.

//-----------------------------------------------------------------------------
// Title         : AXI Stream Downsizer
// Project       : AXI Stream Downsizer
//-----------------------------------------------------------------------------
// File          : axi_stream_downsizer.sv
// Author        : Christophe Clienti
//-----------------------------------------------------------------------------
// Description   :
// This module downsizes the data width of an AXI stream: one wide input
// beat is emitted as up to DOWNSIZE_RATIO narrow output beats, low
// sub-word first. s_axi_tkeep marks the valid sub-words; its set bits
// are assumed contiguous from bit 0, as the matching upsizer produces
// them, so the unkept tail of a beat is skipped. The beat is acknowledged on
// the transfer of its last kept sub-word, which is also where a tlast
// input beat raises m_axi_tlast.

`timescale 1ns / 100ps

module axi_stream_downsizer #(
    parameter int  DOWNSIZE_RATIO = 4,
    parameter int  OUT_DATA_WIDTH = 2,
    parameter int  OUT_USER_WIDTH = 1,
    localparam int IN_DATA_WIDTH  = OUT_DATA_WIDTH * DOWNSIZE_RATIO,
    localparam int IN_USER_WIDTH  = OUT_USER_WIDTH * DOWNSIZE_RATIO
)(
    input logic                       clock,
    input logic                       sreset,

    // AXI Stream input
    input logic [IN_DATA_WIDTH-1:0]   s_axi_tdata,
    input logic [IN_USER_WIDTH-1:0]   s_axi_tuser,
    input logic                       s_axi_tvalid,
    input logic                       s_axi_tlast,
    input logic [DOWNSIZE_RATIO-1:0]  s_axi_tkeep,
    output logic                      s_axi_tready,

    // AXI Stream output
    output logic [OUT_DATA_WIDTH-1:0] m_axi_tdata,
    output logic [OUT_USER_WIDTH-1:0] m_axi_tuser,
    output logic                      m_axi_tvalid,
    output logic                      m_axi_tlast,
    input logic                       m_axi_tready);

    // Internal signals
    logic [$clog2(DOWNSIZE_RATIO)-1:0] count;
    logic [OUT_DATA_WIDTH-1:0]         mux_data [0:DOWNSIZE_RATIO-1];
    logic [OUT_USER_WIDTH-1:0]         mux_user [0:DOWNSIZE_RATIO-1];
    logic                              mux_keep [0:DOWNSIZE_RATIO-1];
    logic                              last_subword;

    // Generate the mux inputs
    genvar i;
    generate
        for (i = 0; i < DOWNSIZE_RATIO; i++) begin : gen_mux_inputs
            assign mux_data[i] = s_axi_tdata[i*OUT_DATA_WIDTH +: OUT_DATA_WIDTH];
            assign mux_user[i] = s_axi_tuser[i*OUT_USER_WIDTH +: OUT_USER_WIDTH];
            assign mux_keep[i] = s_axi_tkeep[i];
        end
    endgenerate

    // The sub-word being transferred is the last of its beat when it is
    // the top one or when the next keep bit is clear. Checking only the
    // next bit is what assumes the set keep bits are contiguous from
    // bit 0: a kept sub-word above a cleared bit would be dropped.
    assign last_subword = (count == $clog2(DOWNSIZE_RATIO)'(DOWNSIZE_RATIO-1)) || !mux_keep[count+1];

    // Handle the counter to select the correct mux input. The AXI source
    // holds the wide beat stable until it is acknowledged, so the
    // sub-words are muxed straight from the input, without a buffer.
    always_ff @(posedge clock) begin
        if (sreset) begin
            count <= '0;
        end
        else if (m_axi_tready && s_axi_tvalid) begin
            if (last_subword) begin
                count <= '0;
            end
            else begin
                count <= count + 1;
            end
        end
    end

    // Output the selected sub-word
    assign m_axi_tdata  = mux_data[count];
    assign m_axi_tuser  = mux_user[count];
    assign m_axi_tvalid = s_axi_tvalid;
    assign m_axi_tlast  = s_axi_tlast && last_subword;

    // The wide beat is consumed on the transfer of its last kept sub-word
    assign s_axi_tready = m_axi_tready && last_subword;

endmodule
