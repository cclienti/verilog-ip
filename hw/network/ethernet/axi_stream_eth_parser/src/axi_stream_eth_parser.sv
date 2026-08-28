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
// Title         : AXI Stream Ethernet Parser
//-----------------------------------------------------------------------------
// File          : axi_stream_eth_parser.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-27
// Last modified : 2026-08-28
//-----------------------------------------------------------------------------
// Description: This module strips the 14-byte Ethernet header from a
// byte-wide AXI stream frame and decodes it for the packet demux
// downstream. The destination and source MAC, the EtherType and the
// payload length are presented on dedicated side-band outputs,
// registered before the first payload beat and stable to the last,
// following the packet FIFO convention.
//
// m_sel carries the index of the EtherType in the ETHERTYPES list --
// the lowest matching index wins -- or NB_ETHERTYPES, the demux
// discard code, when no entry matches or the destination filter
// rejects the frame: not promiscuous, not the local MAC, not broadcast
// -- nor, with ACCEPT_MULTICAST, any group address (I/G bit); per-group
// filtering belongs to the protocol layer that knows its joined
// addresses. The parser itself never drops a payload beat; steering an
// unwanted frame at the discard code is what makes it vanish in the
// demux, consumed at full rate with no output beat.
//
// m_length is s_length minus the header, for a producer that delivers
// the frame length on the first beat (the packet FIFO m_length); tie
// s_length off and ignore m_length when no length is available. A
// frame whose tlast falls inside the header is consumed and nothing is
// emitted, so a zero-beat frame can never reach the demux. tuser
// passes through on payload beats; on header beats it is ignored.

`timescale 1 ns / 100 ps

module axi_stream_eth_parser #(
    parameter int NB_ETHERTYPES = 2,
    // Element i on bit slice [i*16 +: 16], matched to select code i
    parameter logic [NB_ETHERTYPES*16-1:0] ETHERTYPES = {16'h0806, 16'h0800},
    parameter int LENGTH_WIDTH = 12,
    // Widen the broadcast accept to any group address (I/G bit)
    parameter bit ACCEPT_MULTICAST = 0,
    // Wide enough to hold NB_ETHERTYPES itself, the discard code
    localparam int SEL_W = $clog2(NB_ETHERTYPES + 1)
)(
    input logic                     clock,
    input logic                     sreset,

    // Endpoint identity, sampled once per frame with the last header byte
    input logic [47:0]              local_mac,
    input logic                     promiscuous,

    // AXI Stream input, whole frames with the length on the first beat
    input logic [7:0]               s_axi_tdata,
    input logic                     s_axi_tuser,
    input logic                     s_axi_tvalid,
    input logic                     s_axi_tlast,
    output logic                    s_axi_tready,
    input logic [LENGTH_WIDTH-1:0]  s_length,

    // AXI Stream output, the payload; side-bands stable for the frame
    output logic [7:0]              m_axi_tdata,
    output logic                    m_axi_tuser,
    output logic                    m_axi_tvalid,
    output logic                    m_axi_tlast,
    input logic                     m_axi_tready,
    output logic [SEL_W-1:0]        m_sel,
    output logic [47:0]             m_dst_mac,
    output logic [47:0]             m_src_mac,
    output logic [15:0]             m_ethertype,
    output logic [LENGTH_WIDTH-1:0] m_length
);

    localparam int HDR_BYTES = 14;

    logic                    in_payload;
    logic [3:0]              hdr_cnt;
    logic                    hdr_last;
    logic                    s_accept;
    logic [103:0]            hdr_q;
    logic [111:0]            hdr_full;
    logic [LENGTH_WIDTH-1:0] len_q;
    logic [47:0]             cur_dst;
    logic [15:0]             cur_ethertype;
    logic [SEL_W-1:0]        type_sel;
    logic                    da_ok;

    //-------------------------------------------
    // Handshake: the header is consumed at full
    // rate, the payload passes through
    //-------------------------------------------
    assign s_axi_tready = in_payload ? m_axi_tready : 1'b1;
    assign s_accept     = s_axi_tvalid && s_axi_tready;

    assign m_axi_tvalid = in_payload && s_axi_tvalid;
    assign m_axi_tdata  = s_axi_tdata;
    assign m_axi_tuser  = s_axi_tuser;
    assign m_axi_tlast  = s_axi_tlast;

    //-------------------------------------------
    // Header capture, oldest byte in the MSBs
    //-------------------------------------------
    // Accepting the 14th header byte; a tlast there is a headers-only
    // frame, dropped like any other runt
    assign hdr_last = !in_payload && s_accept && hdr_cnt == 4'(HDR_BYTES - 1) && !s_axi_tlast;

    assign hdr_full      = {hdr_q, s_axi_tdata};
    assign cur_dst       = hdr_full[111:64];
    assign cur_ethertype = hdr_full[15:0];

    always_ff @(posedge clock) begin
        if (s_accept && !in_payload) begin
            hdr_q <= {hdr_q[95:0], s_axi_tdata};
            if (hdr_cnt == 4'd0) begin
                len_q <= s_length;
            end
        end
    end

    //-------------------------------------------
    // Frame phase
    //-------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            in_payload <= 1'b0;
            hdr_cnt    <= '0;
        end
        else if (s_accept) begin
            if (s_axi_tlast) begin
                // Frame end, or a runt dying inside its header
                in_payload <= 1'b0;
                hdr_cnt    <= '0;
            end
            else if (!in_payload) begin
                if (hdr_cnt == 4'(HDR_BYTES - 1)) begin
                    in_payload <= 1'b1;
                    hdr_cnt    <= '0;
                end
                else begin
                    hdr_cnt <= hdr_cnt + 4'd1;
                end
            end
        end
    end

    //-------------------------------------------
    // Select decode and side-band registers
    //-------------------------------------------
    // Downward so the lowest matching index wins on duplicate entries
    always_comb begin
        type_sel = SEL_W'(NB_ETHERTYPES);
        for (int i = NB_ETHERTYPES - 1; i >= 0; i--) begin
            if (cur_ethertype == ETHERTYPES[i*16 +: 16]) begin
                type_sel = SEL_W'(i);
            end
        end
    end

    // Broadcast is the all-ones group address: with ACCEPT_MULTICAST
    // the I/G bit subsumes it, without it only broadcast passes
    assign da_ok = promiscuous || cur_dst == local_mac
                || (ACCEPT_MULTICAST ? cur_dst[40] : cur_dst == '1);

    always_ff @(posedge clock) begin
        if (sreset) begin
            m_sel       <= SEL_W'(NB_ETHERTYPES);
            m_dst_mac   <= '0;
            m_src_mac   <= '0;
            m_ethertype <= '0;
            m_length    <= '0;
        end
        else if (hdr_last) begin
            m_sel       <= da_ok ? type_sel : SEL_W'(NB_ETHERTYPES);
            m_dst_mac   <= cur_dst;
            m_src_mac   <= hdr_full[63:16];
            m_ethertype <= cur_ethertype;
            m_length    <= len_q - LENGTH_WIDTH'(HDR_BYTES);
        end
    end

endmodule
