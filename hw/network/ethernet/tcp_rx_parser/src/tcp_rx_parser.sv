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
// Title         : TCP Receive Segment Parser
//-----------------------------------------------------------------------------
// File          : tcp_rx_parser.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-09-12
// Last modified : 2026-09-12
//-----------------------------------------------------------------------------
// Description: The receive walker of the TCP socket, as its own
// component so it is verified against the bench-side model on its
// own. It decodes and validates one TCP segment as the IPv4 parser
// and demux deliver it -- the L4 unit, cut at total_length, with
// s_src_ip/s_dst_ip/s_length beside its first beat -- and streams the
// payload out. It knows nothing of the connection: the record match,
// the in-order and window decisions, the events and the receive FIFO
// are the socket's, wrapped around this. This is the streaming twin
// of tcp_model_pkg's parse_tcp.
//
// Validation is on the fly: at least 20 bytes, a data offset of at
// least 5 that fits s_length, a TCP checksum over the pseudo-header,
// header and data that verifies, and no tuser. The header fields are
// registered as they pass and are stable from hdr_valid to seg_done.
// Options are walked and the MSS option is read; every other option
// is skipped. The payload leaves on m_pl_*, its tlast the segment's
// last byte, and m_pl_tuser is raised on that last beat when the
// segment failed -- the doom the socket's receive FIFO honours.
//
// Clean FSM for the benchmark goal: IDLE, HEADER, OPTIONS, PAYLOAD,
// DROP, with the option walk a small second machine; the byte
// counter, the field registers and the checksum accumulator are
// datapath.

`timescale 1 ns / 100 ps

module tcp_rx_parser (
    input logic         clock,
    input logic         sreset,

    // Segment in: the L4 unit, with the parser side-bands on the first beat
    input logic [7:0]   s_axi_tdata,
    input logic         s_axi_tuser,
    input logic         s_axi_tvalid,
    input logic         s_axi_tlast,
    output logic        s_axi_tready,
    input logic [31:0]  s_src_ip,   // pseudo-header source, sampled on the first beat
    input logic [31:0]  s_dst_ip,   // pseudo-header destination
    input logic [15:0]  s_length,   // segment length in bytes

    // Payload out: the segment tail, tlast on its last byte, tuser the doom
    output logic [7:0]  m_pl_tdata,
    output logic        m_pl_tvalid,
    output logic        m_pl_tlast,
    output logic        m_pl_tuser,  // segment failed: doom the speculative write
    input logic         m_pl_tready,

    // Decoded header, stable from hdr_valid to seg_done
    output logic [15:0] src_port,
    output logic [15:0] dst_port,
    output logic [31:0] seq_num,
    output logic [31:0] ack_num,
    output logic [7:0]  flags,
    output logic [15:0] window,
    output logic [15:0] urgent,
    output logic [15:0] mss,        // MSS option value, 0 when absent
    output logic [15:0] payload_len,

    output logic        hdr_valid,  // pulse: the 20-byte header parsed, structurally ok
    output logic        seg_done,   // pulse: the segment ended
    output logic        seg_ok      // with seg_done: fully valid
);

    localparam int TCPH = 20;

    //-------------------------------------------
    // State
    //-------------------------------------------
    enum logic [2:0] { IDLE, HEADER, OPTIONS, PAYLOAD, DROP } state, next_state;

    logic [15:0] cnt;         // index of the byte being consumed this beat
    logic [15:0] len_q;       // s_length, sampled on the first beat
    logic [15:0] hl_q;        // header length in bytes, doff*4, from byte 12
    logic        struct_bad;  // data offset failed its check
    logic        tuser_q;     // a tuser seen earlier in this segment

    // Ready: header, options and drop consume unconditionally; payload
    // waits on the sink. IDLE is ready so the first byte is taken.
    assign s_axi_tready = (state == PAYLOAD) ? m_pl_tready : 1'b1;

    logic beat;               // a segment byte is consumed this cycle
    logic first;              // the first byte of a segment (in IDLE)
    assign beat  = s_axi_tvalid && s_axi_tready;
    assign first = (state == IDLE) && beat;

    //-------------------------------------------
    // Checksum: pseudo-header once, then every byte, big-endian pairs
    //-------------------------------------------
    logic [31:0] sum_q;       // running ones' sum
    logic [31:0] pseudo;      // pseudo-header contribution
    logic [31:0] byte_add;    // this byte's contribution
    logic [31:0] sum_next;    // sum after this byte
    logic [16:0] fold1;
    logic [15:0] fold2;
    logic        checksum_ok; // verdict including the byte on the bus this cycle

    assign pseudo   = {16'h0, s_src_ip[31:16]} + {16'h0, s_src_ip[15:0]}
                    + {16'h0, s_dst_ip[31:16]} + {16'h0, s_dst_ip[15:0]}
                    + {24'h0, 8'd6} + {16'h0, s_length};
    assign byte_add = cnt[0] ? {24'h0, s_axi_tdata} : {16'h0, s_axi_tdata, 8'h00};
    assign sum_next = (first ? pseudo : sum_q) + byte_add;

    assign fold1       = {1'b0, sum_next[15:0]} + {1'b0, sum_next[31:16]};
    assign fold2       = fold1[15:0] + {15'h0, fold1[16]};
    assign checksum_ok = (fold2 == 16'hFFFF);

    // Header length from the data-offset nibble, and the payload length
    logic [15:0] hl_live;
    assign hl_live     = {10'h0, s_axi_tdata[7:4], 2'h0};   // doff * 4
    assign payload_len = len_q - hl_q;                       // valid once hl_q is set

    //-------------------------------------------
    // Option walk over the OPTIONS bytes
    //-------------------------------------------
    enum logic [2:0] { OPT_TYPE, OPT_LEN, OPT_SKIP, OPT_MSS_HI, OPT_MSS_LO, OPT_EOL } opt_state;
    logic [7:0] opt_left;     // bytes left in the option being skipped
    logic       opt_is_mss;   // the option whose length we are reading is MSS

    //-------------------------------------------
    // Segment-end markers
    //-------------------------------------------
    logic last_beat;          // the segment's final byte is consumed this cycle
    assign last_beat = beat && s_axi_tlast;

    //-------------------------------------------
    // Registered state
    //-------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) state <= IDLE;
        else        state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (beat && s_axi_tlast)      next_state = IDLE;      // 1-byte junk
                else if (beat)                next_state = HEADER;
            end
            HEADER: begin
                // At cnt==19 the data-offset byte is already in hl_q
                // (captured at cnt==12), so hl_q and struct_bad are valid
                if (last_beat)                          next_state = IDLE;
                else if (beat && cnt == 16'(TCPH - 1)) begin
                    if      (struct_bad)                next_state = DROP;
                    else if (hl_q > 16'(TCPH))          next_state = OPTIONS;
                    else if ((len_q - hl_q) != 16'd0)   next_state = PAYLOAD;
                    else                                next_state = IDLE;
                end
            end
            OPTIONS: begin
                if (last_beat)                          next_state = IDLE;
                else if (beat && cnt == hl_q - 16'd1) begin
                    if ((len_q - hl_q) != 16'd0)        next_state = PAYLOAD;
                    else                                next_state = IDLE;
                end
            end
            PAYLOAD: begin
                if (last_beat)                          next_state = IDLE;
            end
            DROP: begin
                if (last_beat)                          next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    //-------------------------------------------
    // Datapath
    //-------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            cnt        <= 16'd0;
            struct_bad <= 1'b0;
            tuser_q    <= 1'b0;
            hl_q       <= 16'(TCPH);
            mss        <= 16'h0000;
        end
        else if (beat) begin
            sum_q   <= sum_next;
            tuser_q <= (first ? 1'b0 : tuser_q) | s_axi_tuser;

            if (first) begin
                len_q      <= s_length;
                struct_bad <= 1'b0;
                hl_q       <= 16'(TCPH);
                mss        <= 16'h0000;
                opt_state  <= OPT_TYPE;
            end

            // Capture header fields as their bytes pass
            case (cnt)
                16'd0:  src_port[15:8] <= s_axi_tdata;
                16'd1:  src_port[7:0]  <= s_axi_tdata;
                16'd2:  dst_port[15:8] <= s_axi_tdata;
                16'd3:  dst_port[7:0]  <= s_axi_tdata;
                16'd4:  seq_num[31:24] <= s_axi_tdata;
                16'd5:  seq_num[23:16] <= s_axi_tdata;
                16'd6:  seq_num[15:8]  <= s_axi_tdata;
                16'd7:  seq_num[7:0]   <= s_axi_tdata;
                16'd8:  ack_num[31:24] <= s_axi_tdata;
                16'd9:  ack_num[23:16] <= s_axi_tdata;
                16'd10: ack_num[15:8]  <= s_axi_tdata;
                16'd11: ack_num[7:0]   <= s_axi_tdata;
                16'd12: begin
                    hl_q <= hl_live;
                    if (hl_live < 16'(TCPH) || hl_live > len_q) struct_bad <= 1'b1;
                end
                16'd13: flags        <= s_axi_tdata;
                16'd14: window[15:8] <= s_axi_tdata;
                16'd15: window[7:0]  <= s_axi_tdata;
                16'd18: urgent[15:8] <= s_axi_tdata;
                16'd19: urgent[7:0]  <= s_axi_tdata;
                default: ;
            endcase

            // Option walk, only while stepping through the option bytes
            if (state == OPTIONS) begin
                case (opt_state)
                    OPT_TYPE: begin
                        opt_is_mss <= (s_axi_tdata == 8'h02);
                        if      (s_axi_tdata == 8'h00) opt_state <= OPT_EOL;   // EOL
                        else if (s_axi_tdata == 8'h01) opt_state <= OPT_TYPE;  // NOP
                        else                           opt_state <= OPT_LEN;
                    end
                    OPT_LEN: begin
                        if (opt_is_mss && s_axi_tdata == 8'd4)
                            opt_state <= OPT_MSS_HI;
                        else if (s_axi_tdata >= 8'd3) begin
                            opt_left  <= s_axi_tdata - 8'd3;  // bytes after this length byte, minus one
                            opt_state <= OPT_SKIP;
                        end
                        else
                            opt_state <= OPT_TYPE;            // length 2: no payload bytes
                    end
                    OPT_SKIP: begin
                        if (opt_left == 8'd0) opt_state <= OPT_TYPE;
                        else                  opt_left  <= opt_left - 8'd1;
                    end
                    OPT_MSS_HI: begin mss[15:8] <= s_axi_tdata; opt_state <= OPT_MSS_LO; end
                    OPT_MSS_LO: begin mss[7:0]  <= s_axi_tdata; opt_state <= OPT_TYPE;   end
                    default: ; // OPT_EOL: padding, consumed
                endcase
            end

            cnt <= last_beat ? 16'd0 : cnt + 16'd1;
        end
    end

    //-------------------------------------------
    // Outputs
    //-------------------------------------------
    always_comb begin
        // Payload stream: only in PAYLOAD, byte for byte
        m_pl_tvalid = (state == PAYLOAD) && s_axi_tvalid;
        m_pl_tdata  = s_axi_tdata;
        m_pl_tlast  = s_axi_tlast;
        m_pl_tuser  = s_axi_tlast && (!checksum_ok || tuser_q || s_axi_tuser);

        // Header parsed and structurally sound, as byte 19 is consumed
        hdr_valid = (state == HEADER) && beat && (cnt == 16'(TCPH - 1)) && !struct_bad;

        // Segment end and its verdict
        seg_done = last_beat;
        seg_ok   = last_beat && checksum_ok && !struct_bad && !tuser_q && !s_axi_tuser;
    end

endmodule
