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
// Title         : AXI Stream IPv4 Parser
//-----------------------------------------------------------------------------
// File          : axi_stream_ipv4_parser.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-28
// Last modified : 2026-08-28
//-----------------------------------------------------------------------------
// Description: This module strips the IPv4 header from the byte stream
// behind the eth parser's demux output and decodes it for a second
// packet demux, one output per transport protocol. Like the eth
// parser it never drops a payload beat itself: m_sel carries the index
// of the protocol in the PROTOCOLS list -- the lowest matching index
// wins -- or NB_PROTOCOLS, the demux discard code, when no entry
// matches or the header fails validation: version/IHL other than 0x45
// (options are dead on modern networks and a variable-length header
// stage is not worth them), a fragment (MF set or a non-zero offset),
// a header checksum that does not verify, or a destination that is
// neither local_ip nor limited broadcast -- whether to answer a
// broadcast is the protocol block's policy, so the destination is
// exposed on m_dst_ip.
//
// The Ethernet minimum frame pads short IP packets, so the payload is
// cut at total_length: m_axi_tlast fires on the last real payload byte
// and the padding is consumed silently. A frame that ends before
// total_length is aborted with tuser on its final beat, the receive
// drop convention. A frame with no L4 payload (total_length <= 20, or
// ending inside the header) emits nothing, so a zero-beat frame can
// never reach the demux. src/dst IP, protocol and payload length are
// registered before the first payload beat and stable to the last,
// the packet FIFO convention.

`timescale 1 ns / 100 ps

module axi_stream_ipv4_parser #(
    parameter int NB_PROTOCOLS = 1,
    // Element i on bit slice [i*8 +: 8], matched to select code i
    parameter logic [NB_PROTOCOLS*8-1:0] PROTOCOLS = {8'h01},
    // Wide enough to hold NB_PROTOCOLS itself, the discard code
    localparam int SEL_W = $clog2(NB_PROTOCOLS + 1)
)(
    input logic                     clock,
    input logic                     sreset,

    // Endpoint identity, sampled with each frame's first beat
    input logic [31:0]              local_ip,

    // AXI Stream input, IPv4 frames from the eth parser's demux
    input logic [7:0]               s_axi_tdata,
    input logic                     s_axi_tuser,
    input logic                     s_axi_tvalid,
    input logic                     s_axi_tlast,
    output logic                    s_axi_tready,

    // AXI Stream output, the L4 payload cut at total_length
    output logic [7:0]              m_axi_tdata,
    output logic                    m_axi_tuser,
    output logic                    m_axi_tvalid,
    output logic                    m_axi_tlast,
    input logic                     m_axi_tready,
    output logic [SEL_W-1:0]        m_sel,
    output logic [31:0]             m_src_ip,
    output logic [31:0]             m_dst_ip,
    output logic [7:0]              m_protocol,
    output logic [15:0]             m_length
);

    enum logic [1:0] {HEADER, PAYLOAD, PAD} state; // frame phase

    logic [4:0]              hdr_cnt;       // header byte index, 0..19
    logic                    s_accept;      // input beat accepted this cycle
    logic                    bad_q;         // sticky header field mismatch
    logic                    err_q;         // sticky input tuser
    logic [31:0]             my_ip_q;       // identity sample of the frame start
    logic [15:0]             total_q;       // captured total_length
    logic [7:0]              proto_q;       // captured protocol
    logic [31:0]             src_q;         // captured source IP
    logic [23:0]             dst_q;         // first three destination IP bytes
    logic [31:0]             dst_full;      // whole destination, live byte appended
    logic [7:0]              even_q;        // even byte of the running halfword
    logic [19:0]             sum_q;         // ones-complement accumulator
    logic [19:0]             sum_next;      // accumulator with the live halfword
    logic [16:0]             fold1;         // first checksum fold
    logic [16:0]             fold2;         // second checksum fold
    logic                    csum_ok;       // header checksum verdict, live at byte 19
    logic                    dst_ok;        // destination filter verdict
    logic                    byte_bad;      // live mismatch on the current byte
    logic                    frame_good;    // routable header verdict at byte 19
    logic [15:0]             pay_len;       // L4 payload length, total_length - 20
    logic [15:0]             pay_cnt;       // payload byte index
    logic [SEL_W-1:0]        type_sel;      // matched protocol index or discard
    logic                    out_last;      // payload cut point at total_length
    logic                    out_abort;     // input died before total_length

    //-------------------------------------------
    // Handshake: the header and the padding are
    // consumed at full rate, the payload passes
    //-------------------------------------------
    assign s_axi_tready = state == PAYLOAD ? m_axi_tready : 1'b1;
    assign s_accept     = s_axi_tvalid && s_axi_tready;

    assign out_last  = pay_cnt == pay_len - 16'd1;
    assign out_abort = s_axi_tlast && !out_last;

    assign m_axi_tvalid = state == PAYLOAD && s_axi_tvalid;
    assign m_axi_tdata  = s_axi_tdata;
    assign m_axi_tuser  = s_axi_tuser || out_abort;
    assign m_axi_tlast  = out_last || s_axi_tlast;

    //-------------------------------------------
    // On-the-fly validation of the header
    //-------------------------------------------
    always_comb begin
        byte_bad = 1'b0;
        if (hdr_cnt == 5'd0) begin
            byte_bad = s_axi_tdata != 8'h45;
        end
        else if (hdr_cnt == 5'd6) begin
            // MF or a fragment offset: only DF may be set
            byte_bad = (s_axi_tdata & 8'h3F) != 8'h00;
        end
        else if (hdr_cnt == 5'd7) begin
            byte_bad = s_axi_tdata != 8'h00;
        end
    end

    // Ones-complement sum of the ten header halfwords, folded twice;
    // a valid header sums to 0xFFFF, checksum field included
    assign sum_next = sum_q + 20'({even_q, s_axi_tdata});
    assign fold1    = 17'(sum_next[15:0]) + 17'(sum_next[19:16]);
    assign fold2    = 17'(fold1[15:0]) + 17'(fold1[16]);
    assign csum_ok  = fold2[15:0] == 16'hFFFF;

    assign dst_full = {dst_q, s_axi_tdata};
    assign dst_ok   = dst_full == my_ip_q || dst_full == 32'hFFFF_FFFF;

    assign frame_good = !bad_q && !err_q && !s_axi_tuser && csum_ok && dst_ok;

    assign pay_len = total_q - 16'd20;

    //-------------------------------------------
    // Protocol decode
    //-------------------------------------------
    // Downward so the lowest matching index wins on duplicate entries
    always_comb begin
        type_sel = SEL_W'(NB_PROTOCOLS);
        for (int i = NB_PROTOCOLS - 1; i >= 0; i--) begin
            if (proto_q == PROTOCOLS[i*8 +: 8]) begin
                type_sel = SEL_W'(i);
            end
        end
    end

    //-------------------------------------------
    // Frame phases and captures
    //-------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            state   <= HEADER;
            hdr_cnt <= '0;
            bad_q   <= 1'b0;
            err_q   <= 1'b0;
            sum_q   <= '0;
        end
        else if (s_accept) begin
            case (state)
                HEADER: begin
                    hdr_cnt <= hdr_cnt + 5'd1;
                    if (hdr_cnt == 5'd0)  my_ip_q <= local_ip;
                    if (hdr_cnt == 5'd2)  total_q[15:8] <= s_axi_tdata;
                    if (hdr_cnt == 5'd3)  total_q[7:0]  <= s_axi_tdata;
                    if (hdr_cnt == 5'd9)  proto_q <= s_axi_tdata;
                    if (hdr_cnt >= 5'd12 && hdr_cnt <= 5'd15) begin
                        src_q <= {src_q[23:0], s_axi_tdata};
                    end
                    if (hdr_cnt >= 5'd16 && hdr_cnt <= 5'd18) begin
                        dst_q <= {dst_q[15:0], s_axi_tdata};
                    end
                    if (hdr_cnt[0]) begin
                        sum_q <= sum_next;
                    end
                    else begin
                        even_q <= s_axi_tdata;
                    end
                    if (byte_bad)     bad_q <= 1'b1;
                    if (s_axi_tuser)  err_q <= 1'b1;

                    if (s_axi_tlast) begin
                        // Died inside its header: swallowed
                        state   <= HEADER;
                        hdr_cnt <= '0;
                        bad_q   <= 1'b0;
                        err_q   <= 1'b0;
                        sum_q   <= '0;
                    end
                    else if (hdr_cnt == 5'd19) begin
                        // No L4 byte to route: swallow the padding
                        if (total_q > 16'd20) begin
                            state <= PAYLOAD;
                        end
                        else begin
                            state <= PAD;
                        end
                        hdr_cnt     <= '0;
                        sum_q       <= '0;
                        pay_cnt     <= '0;
                        m_sel       <= frame_good ? type_sel : SEL_W'(NB_PROTOCOLS);
                        m_src_ip    <= src_q;
                        m_dst_ip    <= dst_full;
                        m_protocol  <= proto_q;
                        m_length    <= total_q - 16'd20;
                    end
                end

                PAYLOAD: begin
                    pay_cnt <= pay_cnt + 16'd1;
                    if (s_axi_tlast) begin
                        // Truncated frames abort with tuser on the beat
                        state <= HEADER;
                        bad_q <= 1'b0;
                        err_q <= 1'b0;
                    end
                    else if (out_last) begin
                        state <= PAD;
                    end
                end

                default: begin // PAD
                    if (s_axi_tlast) begin
                        state <= HEADER;
                        bad_q <= 1'b0;
                        err_q <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule
