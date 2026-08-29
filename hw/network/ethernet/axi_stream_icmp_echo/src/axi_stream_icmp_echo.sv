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
// Title         : AXI Stream ICMP Echo Responder
//-----------------------------------------------------------------------------
// File          : axi_stream_icmp_echo.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-28
// Last modified : 2026-08-28
//-----------------------------------------------------------------------------
// Description: This module answers ICMP echo requests. It consumes
// ICMP payload frames as the IPv4 parser and packet demux deliver
// them -- cut at total_length, whole frames -- with the parser
// side-bands on s_src_ip/s_dst_ip/s_length and the requester's MAC,
// from the eth parser, on s_src_mac; all are sampled with the frame's
// first beat. A frame is consumed and ignored when it is not an echo
// request (type 8 code 0), was sent to a broadcast destination
// (answering those is the smurf amplifier), is shorter than the
// 8-byte echo header, does not fit the payload buffer, carries tuser
// on any beat, or does not match s_length. The only tuser that can
// arrive here is one within total_length: an FCS flag lands on a
// padding beat the parser swallows, so corrupt frames must be removed
// by the drop FIFO upstream, as in the documented receive chain.
//
// The identifier, sequence and data are buffered whole -- headers go
// out first, so store-and-forward is unavoidable -- in a
// 2**LOG2_DEPTH-byte RAM, and the reply leaves as one complete
// 34+s_length-byte Ethernet frame: MAC and IP headers built from the
// sampled side-bands (TTL 64, DF set, a fresh header checksum), then
// type 0 code 0 with the request's checksum incrementally adjusted
// per RFC 1624 -- the type field is the only change, so the offset is
// a constant and the payload is never summed. The request checksum is
// echoed as received, not verified. The reply relies on the FCS
// generator downstream padding it to the minimum frame (a zero-data
// echo leaves here as 42 bytes). The input holds tready low while a
// reply drains, like the ARP responder, with a heavier head-of-line
// consequence: a reply is up to 34+2**LOG2_DEPTH beats, not ARP's
// fixed 42, and while it drains the whole receive chain behind the
// demuxes stalls -- the transmit merge must guarantee forward
// progress and the receive FIFO's slack must absorb the drain.

`timescale 1 ns / 100 ps

module axi_stream_icmp_echo #(
    parameter int LOG2_DEPTH = 11  // payload buffer in bytes, log2, at most 16 (rx_cnt width)
)(
    input logic        clock,
    input logic        sreset,

    // Endpoint identity, sampled with each frame's first beat
    input logic [47:0] local_mac,
    input logic [31:0] local_ip,

    // AXI Stream input, ICMP payload frames from the IPv4 demux,
    // side-bands stable per frame
    input logic [7:0]  s_axi_tdata,
    input logic        s_axi_tuser,
    input logic        s_axi_tvalid,
    input logic        s_axi_tlast,
    output logic       s_axi_tready,
    input logic [31:0] s_src_ip,
    input logic [31:0] s_dst_ip,
    input logic [15:0] s_length,
    input logic [47:0] s_src_mac,

    // AXI Stream output, complete Ethernet echo reply frames
    output logic [7:0] m_axi_tdata,
    output logic       m_axi_tuser,
    output logic       m_axi_tvalid,
    output logic       m_axi_tlast,
    input logic        m_axi_tready
);

    localparam int DEPTH = 2**LOG2_DEPTH;

    // One encoding of the fixed reply IP header halfwords: the
    // checksum sum and the header image below must never diverge
    localparam logic [15:0] IP_VER_LEN  = 16'h4500;      // version 4, IHL 5, TOS 0
    localparam logic [15:0] IP_FLAGS    = 16'h4000;      // DF set, offset 0
    localparam logic [15:0] IP_TTL_PROT = {8'd64, 8'd1}; // TTL 64, protocol ICMP

    enum logic [1:0] {RECEIVE, HDR, DATA} state; // frame phase

    logic [15:0]           rx_cnt;      // request byte index
    logic [5:0]            tx_cnt;      // reply header byte index, 0..37
    logic [15:0]           data_idx;    // reply data byte index
    logic                  s_accept;    // input beat accepted this cycle
    logic                  m_accept;    // output beat accepted this cycle
    logic                  byte_drop;   // live mismatch on the current byte
    logic                  frame_ok;    // whole-frame verdict on the closing beat
    logic                  drop_q;      // sticky drop decision
    logic [15:0]           len_q;       // sampled s_length
    logic [15:0]           dlen;        // buffered data length, len_q - 4
    logic [31:0]           src_ip_q;    // sampled requester IP
    logic [47:0]           dst_mac_q;   // sampled requester MAC
    logic [47:0]           my_mac_q;    // identity sample of the frame start
    logic [31:0]           my_ip_q;     // identity sample of the frame start
    logic [15:0]           csum_q;      // request ICMP checksum, echoed adjusted
    logic [7:0]            ram [0:DEPTH-1]; // id/seq/data store
    logic [7:0]            ram_q;       // registered RAM read
    logic [15:0]           total_w;     // reply IP total_length
    logic [19:0]           ip_sum;      // reply IP header checksum accumulator
    logic [16:0]           ip_fold;     // reply IP checksum fold
    logic [15:0]           ip_csum;     // reply IP header checksum
    logic [16:0]           inc_sum;     // RFC 1624 incremental accumulator
    logic [15:0]           icmp_csum;   // adjusted reply ICMP checksum
    logic [303:0]          hdr_vec;     // 38-byte reply header image

    //-------------------------------------------
    // Handshake: receive stalls while the reply
    // drains, the reply follows its consumer
    //-------------------------------------------
    assign s_axi_tready = state == RECEIVE;
    assign s_accept     = s_axi_tvalid && s_axi_tready;
    assign m_accept     = m_axi_tvalid && m_axi_tready;

    //-------------------------------------------
    // On-the-fly validation of the request
    //-------------------------------------------
    always_comb begin
        byte_drop = 1'b0;
        if (rx_cnt == 16'd0) begin
            // local_ip is being sampled this very beat, so the
            // broadcast test reads the live input, the same value
            byte_drop = s_axi_tdata != 8'h08
                     || s_dst_ip != local_ip
                     || s_length < 16'd8
                     || 32'(s_length) > 32'(DEPTH + 4);
        end
        else if (rx_cnt == 16'd1) begin
            byte_drop = s_axi_tdata != 8'h00;
        end
    end

    // The whole verdict on the closing beat: nothing dropped so far
    // or live, no tuser, and exactly the announced length. The live
    // s_length, stable to the last beat, not len_q: on a single-beat
    // frame len_q is being sampled this very edge and still holds the
    // previous frame's length (X after reset)
    assign frame_ok = !drop_q && !byte_drop && !s_axi_tuser
                   && rx_cnt == s_length - 16'd1;

    //-------------------------------------------
    // Reply checksums, combinational on sampled
    // fields that hold still for the whole reply
    //-------------------------------------------
    assign total_w = 16'd20 + len_q;

    assign ip_sum = 20'(IP_VER_LEN) + 20'(total_w) + 20'(IP_FLAGS) + 20'(IP_TTL_PROT)
                  + 20'(my_ip_q[31:16]) + 20'(my_ip_q[15:0])
                  + 20'(src_ip_q[31:16]) + 20'(src_ip_q[15:0]);
    assign ip_fold = 17'(ip_sum[15:0]) + 17'(ip_sum[19:16]);
    assign ip_csum = ~(16'(ip_fold[15:0]) + 16'(ip_fold[16]));

    // Type 8 -> 0 is the only change: HC' = ~(~HC + ~0x0800). The
    // concatenation, not a 17-bit cast: 17'(~csum_q) would invert the
    // zero-extended value, set bit 16 and flip the end-around carry
    assign inc_sum   = {1'b0, ~csum_q} + 17'h0F7FF;
    assign icmp_csum = ~(16'(inc_sum[15:0]) + 16'(inc_sum[16]));

    //-------------------------------------------
    // The reply frame header, oldest byte in the
    // MSBs: Ethernet, IPv4, then type/code/csum
    //-------------------------------------------
    assign hdr_vec = {dst_mac_q, my_mac_q, 16'h0800,
                      IP_VER_LEN, total_w, 16'h0000, IP_FLAGS,
                      IP_TTL_PROT, ip_csum, my_ip_q, src_ip_q,
                      16'h0000, icmp_csum};

    assign dlen = len_q - 16'd4;

    assign m_axi_tvalid = state != RECEIVE;
    assign m_axi_tdata  = state == HDR ? hdr_vec[8*(37 - 32'(tx_cnt)) +: 8] : ram_q;
    assign m_axi_tlast  = state == DATA && data_idx == dlen - 16'd1;
    assign m_axi_tuser  = 1'b0;

    //-------------------------------------------
    // Receive, decide, emit
    //-------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            state    <= RECEIVE;
            rx_cnt   <= '0;
            tx_cnt   <= '0;
            data_idx <= '0;
            drop_q   <= 1'b0;
        end
        else begin
            case (state)
                RECEIVE: begin
                    if (s_accept) begin
                        rx_cnt <= rx_cnt + 16'd1;
                        if (rx_cnt == 16'd0) begin
                            len_q     <= s_length;
                            src_ip_q  <= s_src_ip;
                            dst_mac_q <= s_src_mac;
                            my_mac_q  <= local_mac;
                            my_ip_q   <= local_ip;
                        end
                        if (rx_cnt == 16'd2)  csum_q[15:8] <= s_axi_tdata;
                        if (rx_cnt == 16'd3)  csum_q[7:0]  <= s_axi_tdata;
                        if (byte_drop || s_axi_tuser) begin
                            drop_q <= 1'b1;
                        end
                        if (s_axi_tlast) begin
                            rx_cnt <= '0;
                            drop_q <= 1'b0;
                            if (frame_ok) begin
                                state    <= HDR;
                                tx_cnt   <= '0;
                                data_idx <= '0;
                            end
                        end
                    end
                end

                HDR: begin
                    if (m_accept) begin
                        if (tx_cnt == 6'd37) begin
                            state  <= DATA;
                            tx_cnt <= '0;
                        end
                        else begin
                            tx_cnt <= tx_cnt + 6'd1;
                        end
                    end
                end

                default: begin // DATA
                    if (m_accept) begin
                        if (data_idx == dlen - 16'd1) begin
                            state    <= RECEIVE;
                            data_idx <= '0;
                        end
                        else begin
                            data_idx <= data_idx + 16'd1;
                        end
                    end
                end
            endcase
        end
    end

    //-------------------------------------------
    // Payload store: written past the checksum,
    // prefetched so ram_q always holds the byte
    // at data_idx when the DATA phase reads it.
    // No upper bound on the write: a frame that
    // runs past DEPTH+4 wraps, but it is doomed
    // (oversize announcements drop at byte 0,
    // over-runs fail the length verdict) and no
    // write can land while a reply reads
    //-------------------------------------------
    always_ff @(posedge clock) begin
        if (s_accept && rx_cnt >= 16'd4) begin
            ram[rx_cnt[LOG2_DEPTH-1:0] - LOG2_DEPTH'(4)] <= s_axi_tdata;
        end
        ram_q <= ram[state == DATA && m_accept ? data_idx[LOG2_DEPTH-1:0] + LOG2_DEPTH'(1)
                                               : data_idx[LOG2_DEPTH-1:0]];
    end

endmodule
