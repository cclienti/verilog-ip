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
// Title         : TCP Transmit Frame Builder
//-----------------------------------------------------------------------------
// File          : tcp_tx_frame.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-09-12
// Last modified : 2026-09-12
//-----------------------------------------------------------------------------
// Description: The transmit walker of the TCP socket, as its own
// component so the socket can hand it one segment at a time and so it
// can be verified against the bench-side model on its own. Given the
// header fields the scheduler has chosen and a payload read back from
// the transmit ring, it emits one complete Ethernet frame -- MAC and
// IPv4 headers (TTL 64, DF set, fresh IP checksum), the TCP header,
// the MSS option on a SYN-ACK, then the payload -- with both checksums
// in place, ready for the packet mux and the FCS generator.
//
// The fields are latched on start. A payload of pl_len bytes is read
// back twice through pl_addr/pl_data: once in SUM to accumulate the
// TCP data checksum (the header leaves before the data and a
// retransmission re-reads the ring, so the sum cannot be taken at
// write time), then again in PAYLOAD to emit it. The scheduler maps
// pl_addr, a 0-based offset into this segment, onto the ring.
//
// Clean FSM for the socket's benchmark goal: enumerated state, one
// registered process, one next-state process, one outputs process,
// Moore outputs except tready-gated advance; the byte index, the
// checksum accumulator and the header image are datapath. This first
// version sums the fixed header halfwords combinationally; the
// running-ahead pipeline the README describes is a timing refinement
// that does not change the bytes emitted.

`timescale 1 ns / 100 ps

module tcp_tx_frame (
    input logic         clock,
    input logic         sreset,

    // Segment request, all sampled on start
    input logic         start,       // one-cycle pulse: begin a frame
    input logic         with_mss,    // include the 4-byte MSS option (SYN-ACK)
    input logic [15:0]  pl_len,      // payload bytes, 0 for a control segment
    input logic [47:0]  dst_mac,     // frame destination
    input logic [47:0]  src_mac,     // local MAC
    input logic [15:0]  ip_id,       // IPv4 identification
    input logic [31:0]  src_ip,      // local IP
    input logic [31:0]  dst_ip,      // peer IP
    input logic [15:0]  src_port,    // local port
    input logic [15:0]  dst_port,    // peer port
    input logic [31:0]  seq,         // TCP sequence number
    input logic [31:0]  ack,         // TCP acknowledgement number
    input logic [7:0]   flags,       // TCP flag byte
    input logic [15:0]  window,      // advertised window
    input logic [15:0]  mss,         // MSS option value, used when with_mss

    // Payload read-back, combinational: pl_data is the ring byte at the
    // segment offset pl_addr
    output logic [15:0] pl_addr,     // 0-based payload offset
    input logic [7:0]   pl_data,     // ring byte at pl_addr

    // AXI Stream master, one complete Ethernet frame
    output logic [7:0]  m_axi_tdata,
    output logic        m_axi_tuser, // constant zero
    output logic        m_axi_tvalid,
    output logic        m_axi_tlast,
    input logic         m_axi_tready,

    output logic        busy         // high from start until the last beat
);

    localparam int ETH = 14;
    localparam int IPH = 20;
    localparam int TCPH = 20;

    //-------------------------------------------
    // Latched request
    //-------------------------------------------
    logic        with_mss_q;  // MSS option present this frame
    logic [15:0] pl_len_q;    // payload byte count this frame
    logic [47:0] dst_mac_q;   // frame destination MAC
    logic [47:0] src_mac_q;   // local MAC
    logic [15:0] ip_id_q;     // IPv4 identification
    logic [31:0] src_ip_q;    // local IP
    logic [31:0] dst_ip_q;    // peer IP
    logic [15:0] src_port_q;  // local port
    logic [15:0] dst_port_q;  // peer port
    logic [31:0] seq_q;       // sequence number
    logic [31:0] ack_q;       // acknowledgement number
    logic [7:0]  flags_q;     // flag byte
    logic [15:0] window_q;    // advertised window
    logic [15:0] mss_q;       // MSS option value
    logic [31:0] data_sum_q;  // ones' sum of the payload halfwords

    // TCP header length and the byte positions that depend on it
    logic [5:0]  tcp_hl;      // 20 or 24
    logic [15:0] hdr_bytes;   // ETH + IPH + tcp_hl, the streamed header length
    logic [15:0] frame_bytes; // hdr_bytes + payload, the whole frame

    assign tcp_hl      = with_mss_q ? 6'd24 : 6'd20;
    assign hdr_bytes   = 16'(ETH + IPH) + 16'(tcp_hl);
    assign frame_bytes = hdr_bytes + pl_len_q;

    //-------------------------------------------
    // State
    //-------------------------------------------
    enum logic [1:0] { IDLE, SUM, HEADER, PAYLOAD } state, next_state;

    logic [15:0] cnt;         // byte index: payload offset in SUM, frame offset otherwise
    logic        beat;        // an output beat is accepted this cycle
    logic        sum_last;    // last payload byte for the SUM pass
    logic        hdr_last;    // last header byte, and no payload follows
    logic        pay_last;    // last payload byte

    assign beat     = m_axi_tvalid && m_axi_tready;
    assign sum_last = (cnt == pl_len_q - 16'd1);
    assign hdr_last = (cnt == hdr_bytes - 16'd1) && (pl_len_q == 16'd0);
    assign pay_last = (cnt == frame_bytes - 16'd1);

    //-------------------------------------------
    // Header image, checksum fields zero
    //-------------------------------------------
    logic [7:0] img [0:57];   // up to 58 bytes: 14 + 20 + 24

    always_comb begin
        for (int i = 0; i < 58; i++) img[i] = 8'h00;
        // Ethernet
        {img[0], img[1], img[2], img[3], img[4], img[5]}     = dst_mac_q;
        {img[6], img[7], img[8], img[9], img[10], img[11]}   = src_mac_q;
        img[12] = 8'h08; img[13] = 8'h00;
        // IPv4
        img[14] = 8'h45; img[15] = 8'h00;
        {img[16], img[17]} = 16'(IPH) + 16'(tcp_hl) + pl_len_q;  // total length
        {img[18], img[19]} = ip_id_q;
        img[20] = 8'h40; img[21] = 8'h00;                        // DF set, no fragment
        img[22] = 8'd64; img[23] = 8'd6;                         // TTL 64, protocol TCP
        // img[24..25] IP checksum, overlaid below
        {img[26], img[27], img[28], img[29]} = src_ip_q;
        {img[30], img[31], img[32], img[33]} = dst_ip_q;
        // TCP
        {img[34], img[35]} = src_port_q;
        {img[36], img[37]} = dst_port_q;
        {img[38], img[39], img[40], img[41]} = seq_q;
        {img[42], img[43], img[44], img[45]} = ack_q;
        img[46] = {tcp_hl[5:2], 4'h0};                           // data offset, tcp_hl/4
        img[47] = flags_q;
        {img[48], img[49]} = window_q;
        // img[50..51] TCP checksum, overlaid below
        // img[52..53] urgent pointer, zero
        if (with_mss_q) begin
            img[54] = 8'h02; img[55] = 8'h04;                    // MSS option
            {img[56], img[57]} = mss_q;
        end
    end

    //-------------------------------------------
    // Checksums over the image and the data sum
    //-------------------------------------------
    function automatic logic [15:0] fold16(input logic [31:0] s0);
        logic [31:0] s = s0;
        s = {16'h0, s[15:0]} + {16'h0, s[31:16]};
        s = {16'h0, s[15:0]} + {16'h0, s[31:16]};
        return ~s[15:0];
    endfunction

    logic [31:0] ip_acc;      // sum of the ten IPv4 header halfwords
    logic [31:0] tcp_acc;     // pseudo-header, TCP header and data sum
    logic [15:0] ip_ck;       // IPv4 header checksum
    logic [15:0] tcp_ck;      // TCP checksum
    logic [15:0] tcp_len;     // TCP header plus payload, for the pseudo-header

    assign tcp_len = 16'(tcp_hl) + pl_len_q;

    always_comb begin
        // IPv4 header: ten halfwords, checksum field already zero
        ip_acc = 32'h0;
        for (int i = 14; i < 34; i += 2) ip_acc += {16'h0, img[i], img[i+1]};

        // TCP: pseudo-header, then the header halfwords (checksum and
        // any MSS option included, both from the image), then the data
        tcp_acc = {16'h0, src_ip_q[31:16]} + {16'h0, src_ip_q[15:0]}
                + {16'h0, dst_ip_q[31:16]} + {16'h0, dst_ip_q[15:0]}
                + {24'h0, 8'd6} + {16'h0, tcp_len};
        for (int i = 34; i < 34 + 20; i += 2) tcp_acc += {16'h0, img[i], img[i+1]};
        if (with_mss_q) begin
            tcp_acc += {16'h0, img[54], img[55]};
            tcp_acc += {16'h0, img[56], img[57]};
        end
        tcp_acc += data_sum_q;
    end

    assign ip_ck  = fold16(ip_acc);
    assign tcp_ck = fold16(tcp_acc);

    // The image with the two checksum fields overlaid
    function automatic logic [7:0] img_out(input logic [15:0] idx);
        case (idx)
            16'd24: return ip_ck[15:8];
            16'd25: return ip_ck[7:0];
            16'd50: return tcp_ck[15:8];
            16'd51: return tcp_ck[7:0];
            default: return img[idx[5:0]];
        endcase
    endfunction

    //-------------------------------------------
    // Registered state
    //-------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) state <= IDLE;
        else        state <= next_state;
    end

    //-------------------------------------------
    // Next state
    //-------------------------------------------
    always_comb begin
        case (state)
            IDLE: begin
                if (start && pl_len != 16'd0) next_state = SUM;
                else if (start)               next_state = HEADER;
                else                          next_state = IDLE;
            end
            SUM: begin
                if (sum_last) next_state = HEADER;
                else          next_state = SUM;
            end
            HEADER: begin
                if (beat && cnt == hdr_bytes - 16'd1 && pl_len_q != 16'd0)
                    next_state = PAYLOAD;
                else if (beat && cnt == hdr_bytes - 16'd1)
                    next_state = IDLE;
                else
                    next_state = HEADER;
            end
            PAYLOAD: begin
                if (beat && pay_last) next_state = IDLE;
                else                  next_state = PAYLOAD;
            end
            default: next_state = IDLE;
        endcase
    end

    //-------------------------------------------
    // Datapath: latch on start, scan in SUM, index in HEADER/PAYLOAD
    //-------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            cnt        <= 16'd0;
            data_sum_q <= 32'h0;
        end
        else begin
            if (state == IDLE && start) begin
                with_mss_q <= with_mss;
                pl_len_q   <= pl_len;
                dst_mac_q  <= dst_mac;
                src_mac_q  <= src_mac;
                ip_id_q    <= ip_id;
                src_ip_q   <= src_ip;
                dst_ip_q   <= dst_ip;
                src_port_q <= src_port;
                dst_port_q <= dst_port;
                seq_q      <= seq;
                ack_q      <= ack;
                flags_q    <= flags;
                window_q   <= window;
                mss_q      <= mss;
                cnt        <= 16'd0;
                data_sum_q <= 32'h0;
            end
            else if (state == SUM) begin
                // Big-endian halfwords: even offset is the high byte
                if (cnt[0] == 1'b0) data_sum_q <= data_sum_q + {16'h0, pl_data, 8'h00};
                else                data_sum_q <= data_sum_q + {24'h0, pl_data};
                if (sum_last) cnt <= 16'd0;      // restart the index for the frame
                else          cnt <= cnt + 16'd1;
            end
            else if (state == HEADER || state == PAYLOAD) begin
                if (beat) begin
                    if ((state == PAYLOAD && pay_last) ||
                        (state == HEADER && cnt == hdr_bytes - 16'd1 && pl_len_q == 16'd0))
                        cnt <= 16'd0;
                    else
                        cnt <= cnt + 16'd1;
                end
            end
        end
    end

    //-------------------------------------------
    // Outputs
    //-------------------------------------------
    always_comb begin
        // Payload offset in SUM; in PAYLOAD the frame index less the header
        if (state == SUM) pl_addr = cnt;
        else              pl_addr = cnt - hdr_bytes;

        m_axi_tuser = 1'b0;
        busy        = (state != IDLE);

        case (state)
            HEADER: begin
                m_axi_tvalid = 1'b1;
                m_axi_tdata  = img_out(cnt);
                m_axi_tlast  = hdr_last;
            end
            PAYLOAD: begin
                m_axi_tvalid = 1'b1;
                m_axi_tdata  = pl_data;
                m_axi_tlast  = pay_last;
            end
            default: begin
                m_axi_tvalid = 1'b0;
                m_axi_tdata  = 8'h00;
                m_axi_tlast  = 1'b0;
            end
        endcase
    end

endmodule
