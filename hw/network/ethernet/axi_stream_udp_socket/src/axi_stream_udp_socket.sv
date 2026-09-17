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
// Title         : AXI Stream UDP Socket
//-----------------------------------------------------------------------------
// File          : axi_stream_udp_socket.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-09-14
// Last modified : 2026-09-14
//-----------------------------------------------------------------------------
// Description: One UDP listener between the IPv4 layer and an
// application, on listen_port. See README.rst for the full design:
// no connection, so no handshake, sequence space, retransmission or
// window; the peer address travels beside the stream, on
// m_app_peer_*/s_app_dst_*, rather than living in a record. Two
// straight-through walkers around two axi_stream_packet_fifo
// instances, each carrying the datagram's address (and, on transmit,
// its precomputed checksum) in the FIFO's own INFO_WIDTH side-band --
// the same commit/rollback mechanism the TCP socket's receive buffer
// uses, including the "a doomed beat needs no room" property that lets
// a rejected datagram (wrong port, foreign destination, no free
// space) be doomed from its very first beat without ever consuming
// real buffer space, exactly as axi_stream_tcp_socket dooms a
// not-accepted segment.
//
// A datagram with no payload is accepted at the wire -- decoded,
// matched, its checksum verified -- but delivers nothing to the
// application: AXI stream needs a beat to carry an event, and there is
// none to spend on an empty frame the way TCP spends one on its close
// token, so this socket cannot represent, and cannot originate, a
// zero-byte UDP datagram. Documented, not implemented: rare enough in
// practice, and a marker-beat mechanism to carry it would cost more
// than the limitation does.
//
// Clean FSMs for the socket's benchmark goal, both kept inside this
// one component rather than split out the way tcp_rx_parser and
// tcp_tx_frame were: receive walker IDLE/HEADER/PAYLOAD/DROP, transmit
// walker IDLE/HEADER/PAYLOAD. The checksum accumulators, the byte
// counters and the header images are datapath.

`timescale 1 ns / 100 ps

module axi_stream_udp_socket #(
    parameter int LOG2_RX_DEPTH  = 11, // receive buffer size in bytes, log2
    parameter int LOG2_RX_FRAMES = 6,  // receive buffer capacity in datagrams, log2
    parameter int LOG2_TX_DEPTH  = 11, // transmit buffer size in bytes, log2
    parameter int LOG2_TX_FRAMES = 6   // transmit buffer capacity in datagrams, log2
)(
    input logic         clock,
    input logic         sreset,

    input logic [47:0]  local_mac,
    input logic [31:0]  local_ip,
    input logic [15:0]  listen_port,

    // AXI Stream slave: UDP datagrams from the IPv4 demux
    input logic [7:0]   s_axi_tdata,
    input logic         s_axi_tuser,
    input logic         s_axi_tvalid,
    input logic         s_axi_tlast,
    output logic        s_axi_tready,
    input logic [31:0]  s_src_ip,
    input logic [31:0]  s_dst_ip,
    input logic [15:0]  s_length,
    input logic [47:0]  s_src_mac,

    // AXI Stream master: complete Ethernet frames
    output logic [7:0]  m_axi_tdata,
    output logic        m_axi_tuser,  // constant zero
    output logic        m_axi_tvalid,
    output logic        m_axi_tlast,
    input logic         m_axi_tready,

    // AXI Stream master to the application: one received datagram per frame
    output logic [7:0]  m_app_tdata,
    output logic        m_app_tvalid,
    output logic        m_app_tlast,
    input logic         m_app_tready,
    output logic [47:0] m_app_peer_mac,
    output logic [31:0] m_app_peer_ip,
    output logic [15:0] m_app_peer_port,

    // AXI Stream slave from the application: one datagram to send per frame
    input logic [7:0]   s_app_tdata,
    input logic         s_app_tvalid,
    input logic         s_app_tlast,
    output logic        s_app_tready,
    input logic [47:0]  s_app_dst_mac,
    input logic [31:0]  s_app_dst_ip,
    input logic [15:0]  s_app_dst_port
);

    localparam int          ETH_HDR_LEN = 14;
    localparam int          IP_HDR_LEN  = 20;
    localparam int          UDP_HDR_LEN = 8;
    localparam int          HDR_LEN     = ETH_HDR_LEN + IP_HDR_LEN + UDP_HDR_LEN; // 42
    localparam logic [7:0]  IP_PROTO_UDP = 8'd17;
    localparam logic [15:0] ETHERTYPE_IPV4 = 16'h0800;

    //================================================================
    // Receive walker
    //================================================================
    enum logic [1:0] { RX_IDLE, RX_HEADER, RX_PAYLOAD, RX_DROP } rx_state, rx_next_state;

    logic        rxf_s_tready;  // receive buffer write-side ready, declared here: iverilog
                                 // wants a continuous assign's operands declared ahead of it
    logic        rx_beat, rx_first, rx_last_beat;
    logic [15:0] rx_cnt;          // byte index within the datagram
    logic [15:0] rx_src_port_q;
    logic [15:0] rx_dst_port_q;
    logic [7:0]  rx_len_hi_q;     // length field high byte, cnt==4
    logic        rx_len_bad_q;    // length field disagrees with s_length
    logic        rx_csum_zero_q;  // received checksum field is all-zero: RFC 768, skip
    logic        rx_tuser_q;      // a tuser seen earlier in this datagram
    logic        rx_accept_q;     // to_us and fits, latched when the header completes

    assign rx_beat      = s_axi_tvalid && s_axi_tready;
    assign rx_first     = (rx_state == RX_IDLE) && s_axi_tvalid;
    assign rx_last_beat = rx_beat && s_axi_tlast;

    // Header, drop and idle consume unconditionally; only payload waits
    // on the receive buffer, which is where a full buffer backpressures.
    // rxf_s_tready is declared with the receive buffer below.
    assign s_axi_tready = (rx_state == RX_PAYLOAD) ? rxf_s_tready : 1'b1;

    //-------------------------------------------
    // Checksum: pseudo-header folded into byte 0, then every byte, the
    // same technique as tcp_rx_parser -- see its README for the timing
    // lesson this shares one fold to avoid. s_length stands in for the
    // pseudo-header's UDP length term directly: unlike the payload
    // length below, it is a side-band already valid on the first beat,
    // not something decoded from the stream, so it needs no register.
    //-------------------------------------------
    logic [18:0] rx_pseudo_sum;
    logic [18:0] rx_pseudo_byte0;
    logic [15:0] rx_fold_q;
    logic [15:0] rx_byte16;
    logic [16:0] rx_fold_a;
    logic [15:0] rx_fold_next;
    logic        rx_checksum_ok;

    assign rx_pseudo_sum   = {3'h0, s_src_ip[31:16]} + {3'h0, s_src_ip[15:0]}
                           + {3'h0, s_dst_ip[31:16]} + {3'h0, s_dst_ip[15:0]}
                           + {11'h0, IP_PROTO_UDP} + {3'h0, s_length};
    assign rx_byte16       = rx_cnt[0] ? {8'h0, s_axi_tdata} : {s_axi_tdata, 8'h0};
    assign rx_pseudo_byte0 = rx_pseudo_sum + {3'h0, rx_byte16};

    assign rx_fold_a    = rx_first
                        ? {1'b0, rx_pseudo_byte0[15:0]} + {14'h0, rx_pseudo_byte0[18:16]}
                        : {1'b0, rx_fold_q} + {1'b0, rx_byte16};
    assign rx_fold_next = rx_fold_a[15:0] + {15'h0, rx_fold_a[16]};
    assign rx_checksum_ok = (rx_fold_next == 16'hFFFF) || rx_csum_zero_q;

    // Length field, decoded live from byte 5 with byte 4 already
    // registered, checked and registered the same cycle -- settled two
    // cycles ahead of the HEADER/PAYLOAD decision at cnt==7
    logic [15:0] rx_len_live;
    assign rx_len_live = {rx_len_hi_q, s_axi_tdata};

    logic [15:0] rx_payload_len;
    assign rx_payload_len = s_length - 16'(UDP_HDR_LEN);

    //================================================================
    // Receive buffer: commit/rollback, peer address riding as INFO
    // (instantiated here so its level/frames outputs are declared
    // before the datapath below reads them for the fit check)
    //================================================================
    logic [7:0]              rxf_s_tdata;
    logic                    rxf_s_tuser, rxf_s_tvalid, rxf_s_tlast;
    logic [95:0]             rxf_s_info;
    logic [7:0]              rxf_m_tdata;
    logic                    rxf_m_tvalid, rxf_m_tlast;
    logic [95:0]             rxf_m_info;
    logic [LOG2_RX_DEPTH:0]  rxf_level;
    logic [LOG2_RX_FRAMES:0] rxf_frames;

    axi_stream_packet_fifo #(
        .DATA_WIDTH (8), .LOG2_DEPTH (LOG2_RX_DEPTH), .LOG2_FRAMES (LOG2_RX_FRAMES),
        .INFO_WIDTH (96), .DROP_ON_FULL (0)
    ) rxfifo (
        .clock (clock), .sreset (sreset),
        .s_axi_tdata (rxf_s_tdata), .s_axi_tuser (rxf_s_tuser), .s_axi_tvalid (rxf_s_tvalid),
        .s_axi_tlast (rxf_s_tlast), .s_axi_tready (rxf_s_tready), .s_info (rxf_s_info),
        .m_axi_tdata (rxf_m_tdata), .m_axi_tvalid (rxf_m_tvalid), .m_axi_tlast (rxf_m_tlast),
        .m_axi_tready (m_app_tready), .m_info (rxf_m_info), .m_length (),
        .level (rxf_level), .frames (rxf_frames)
    );

    logic [31:0] rx_free;
    logic        rx_frame_free;
    assign rx_free       = (32'(1) << LOG2_RX_DEPTH) - {20'h0, rxf_level};
    assign rx_frame_free = !rxf_frames[LOG2_RX_FRAMES];

    //-------------------------------------------
    // Registered state
    //-------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) rx_state <= RX_IDLE;
        else        rx_state <= rx_next_state;
    end

    always_comb begin
        rx_next_state = rx_state;
        case (rx_state)
            RX_IDLE: begin
                if (rx_beat && !s_axi_tlast) rx_next_state = RX_HEADER;
                // a one-byte "datagram" is absorbed in IDLE, next_state stays IDLE
            end
            RX_HEADER: begin
                if (rx_last_beat) rx_next_state = RX_IDLE;   // ended inside the header
                else if (rx_beat && rx_cnt == 16'(UDP_HDR_LEN - 1)) begin
                    if      (rx_len_bad_q)          rx_next_state = RX_DROP;
                    else if (rx_payload_len == 16'd0) rx_next_state = RX_IDLE;
                    else                             rx_next_state = RX_PAYLOAD;
                end
            end
            RX_PAYLOAD: if (rx_last_beat) rx_next_state = RX_IDLE;
            RX_DROP:    if (rx_last_beat) rx_next_state = RX_IDLE;
            default:    rx_next_state = RX_IDLE;
        endcase
    end

    //-------------------------------------------
    // Datapath
    //-------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            rx_cnt         <= 16'd0;
            rx_len_bad_q   <= 1'b0;
            rx_csum_zero_q <= 1'b1;
            rx_tuser_q     <= 1'b0;
            rx_accept_q    <= 1'b0;
        end
        else if (rx_beat) begin
            rx_fold_q  <= rx_fold_next;
            rx_tuser_q <= (rx_first ? 1'b0 : rx_tuser_q) | s_axi_tuser;

            if (rx_first) begin
                rx_len_bad_q   <= 1'b0;
                rx_csum_zero_q <= 1'b1;
            end

            case (rx_cnt)
                16'd0: rx_src_port_q[15:8] <= s_axi_tdata;
                16'd1: rx_src_port_q[7:0]  <= s_axi_tdata;
                16'd2: rx_dst_port_q[15:8] <= s_axi_tdata;
                16'd3: rx_dst_port_q[7:0]  <= s_axi_tdata;
                16'd4: rx_len_hi_q         <= s_axi_tdata;
                16'd5: rx_len_bad_q        <= (rx_len_live != s_length);
                16'd6: rx_csum_zero_q      <= rx_csum_zero_q && (s_axi_tdata == 8'h00);
                16'd7: rx_csum_zero_q      <= rx_csum_zero_q && (s_axi_tdata == 8'h00);
                default: ;
            endcase

            if (rx_cnt == 16'(UDP_HDR_LEN - 1))
                rx_accept_q <= (rx_dst_port_q == listen_port) && (s_dst_ip == local_ip)
                             && ({16'h0, rx_payload_len} <= rx_free) && rx_frame_free;

            rx_cnt <= rx_last_beat ? 16'd0 : rx_cnt + 16'd1;
        end
    end

    // Offered every PAYLOAD beat regardless of acceptance; a rejected
    // datagram is doomed from its first payload beat (rx_accept_q is
    // already latched by then), so it needs no real room -- the same
    // "doomed beat needs no room" mechanism the TCP socket's receive
    // buffer relies on for a segment that does not fit or is not
    // addressed to it.
    assign rxf_s_tvalid = (rx_state == RX_PAYLOAD) && s_axi_tvalid;
    assign rxf_s_tdata  = s_axi_tdata;
    assign rxf_s_tlast  = s_axi_tlast;
    assign rxf_s_tuser  = (s_axi_tlast && !rx_checksum_ok) || !rx_accept_q || rx_tuser_q || s_axi_tuser;
    assign rxf_s_info   = {s_src_mac, s_src_ip, rx_src_port_q};

    assign m_app_tdata      = rxf_m_tdata;
    assign m_app_tvalid     = rxf_m_tvalid;
    assign m_app_tlast      = rxf_m_tlast;
    assign m_app_peer_mac   = rxf_m_info[95:48];
    assign m_app_peer_ip    = rxf_m_info[47:16];
    assign m_app_peer_port  = rxf_m_info[15:0];

    //================================================================
    // Transmit buffer: commit/rollback, destination address and the
    // precomputed checksum riding as INFO
    //================================================================
    logic [111:0]            txf_s_info;
    logic                    txf_s_tready;
    logic [7:0]               txf_m_tdata;
    logic                     txf_m_tvalid, txf_m_tlast, txf_m_tready;
    logic [111:0]             txf_m_info;
    logic [LOG2_TX_DEPTH:0]   txf_m_length;

    axi_stream_packet_fifo #(
        .DATA_WIDTH (8), .LOG2_DEPTH (LOG2_TX_DEPTH), .LOG2_FRAMES (LOG2_TX_FRAMES),
        .INFO_WIDTH (112), .DROP_ON_FULL (0)
    ) txfifo (
        .clock (clock), .sreset (sreset),
        .s_axi_tdata (s_app_tdata), .s_axi_tuser (1'b0), .s_axi_tvalid (s_app_tvalid),
        .s_axi_tlast (s_app_tlast), .s_axi_tready (txf_s_tready), .s_info (txf_s_info),
        .m_axi_tdata (txf_m_tdata), .m_axi_tvalid (txf_m_tvalid), .m_axi_tlast (txf_m_tlast),
        .m_axi_tready (txf_m_tready), .m_info (txf_m_info), .m_length (txf_m_length),
        .level (), .frames ()
    );

    assign s_app_tready = txf_s_tready;

    //-------------------------------------------
    // Checksum built while the datagram is written, folded byte by
    // byte like the receive side; the pseudo-header and UDP header
    // terms known from the first beat (destination address and port,
    // already stable per the s_app_dst_* contract) fold in with byte
    // 0, and the length -- known only once tlast arrives -- folds in
    // with the last byte instead, since nothing here is ever read back
    // to sum a second time the way a TCP retransmission requires.
    // RFC 768's edge case is honoured: a computed checksum of zero is
    // sent as all ones.
    //-------------------------------------------
    logic [15:0] tx_byte_cnt_q;    // payload bytes already accepted before this beat
    logic        tx_first;
    logic [15:0] tx_fold_q;
    logic [18:0] tx_base_sum;      // pseudo header (minus length) + UDP header ports
    logic [15:0] tx_byte16;
    logic [15:0] tx_total_len;     // UDP_HDR_LEN + bytes through this beat
    logic [16:0] tx_len_x2;        // 2 * tx_total_len, valid when this beat is last
    logic [19:0] tx_fold_a;
    logic [16:0] tx_fold_mid;
    logic [15:0] tx_fold_final;
    logic [15:0] tx_checksum;

    logic        tx_beat;
    assign tx_beat  = s_app_tvalid && s_app_tready;
    assign tx_first = tx_beat && (tx_byte_cnt_q == 16'd0);

    assign tx_base_sum = {3'h0, local_ip[31:16]} + {3'h0, local_ip[15:0]}
                       + {3'h0, s_app_dst_ip[31:16]} + {3'h0, s_app_dst_ip[15:0]}
                       + {11'h0, IP_PROTO_UDP} + {3'h0, listen_port} + {3'h0, s_app_dst_port};
    assign tx_byte16    = tx_byte_cnt_q[0] ? {8'h0, s_app_tdata} : {s_app_tdata, 8'h0};
    assign tx_total_len = 16'(UDP_HDR_LEN) + tx_byte_cnt_q + 16'd1;   // this beat counted in
    assign tx_len_x2    = {1'b0, tx_total_len} + {1'b0, tx_total_len};

    assign tx_fold_a = (tx_first ? {1'b0, tx_base_sum} : {4'h0, tx_fold_q})
                     + {4'h0, tx_byte16}
                     + (s_app_tlast ? {3'h0, tx_len_x2} : 20'h0);
    assign tx_fold_mid   = tx_fold_a[15:0] + {12'h0, tx_fold_a[19:16]};
    assign tx_fold_final = tx_fold_mid[15:0] + {15'h0, tx_fold_mid[16]};

    // The field value is the fold's one's complement -- tx_fold_final
    // itself is the running (uncomplemented) sum carried to the next
    // byte's fold, exactly as the receive side never complements what
    // it feeds forward either. RFC 768: a complemented result of zero
    // is sent as all ones.
    logic [15:0] tx_csum_raw;
    assign tx_csum_raw = ~tx_fold_final;
    assign tx_checksum = (tx_csum_raw == 16'h0000) ? 16'hFFFF : tx_csum_raw;

    always_ff @(posedge clock) begin
        if (sreset) begin
            tx_byte_cnt_q <= 16'd0;
            tx_fold_q     <= 16'h0000;
        end
        else if (tx_beat) begin
            tx_fold_q     <= tx_fold_final;
            tx_byte_cnt_q <= s_app_tlast ? 16'd0 : tx_byte_cnt_q + 16'd1;
        end
    end

    assign txf_s_info = {s_app_dst_mac, s_app_dst_ip, s_app_dst_port, tx_checksum};

    //================================================================
    // Transmit walker: pop a committed datagram, build the fixed
    // 42-byte header, then pass its payload straight through -- no
    // random-access re-read, since nothing here is ever sent twice
    //================================================================
    enum logic [1:0] { TX_IDLE, TX_HEADER, TX_PAYLOAD } tx_state, tx_next_state;

    logic [15:0] tx_hcnt;   // header byte index, HEADER only
    logic        tx_hbeat;
    assign tx_hbeat = m_axi_tvalid && m_axi_tready;

    logic [47:0] txp_dst_mac;
    logic [31:0] txp_dst_ip;
    logic [15:0] txp_dst_port;
    logic [15:0] txp_checksum;
    assign {txp_dst_mac, txp_dst_ip, txp_dst_port, txp_checksum} = txf_m_info;

    logic [15:0] txp_udp_len;   // UDP_HDR_LEN + payload bytes, from the FIFO's own length
    logic [15:0] txp_ip_len;    // IP_HDR_LEN + txp_udp_len
    assign txp_udp_len = 16'(UDP_HDR_LEN) + 16'(txf_m_length);
    assign txp_ip_len  = 16'(IP_HDR_LEN) + txp_udp_len;

    // IPv4 header checksum over the ten halfwords, checksum field zero
    function automatic logic [15:0] ip_fold(input logic [31:0] s0);
        logic [31:0] s;
        s = {16'h0, s0[15:0]} + {16'h0, s0[31:16]};
        s = {16'h0, s[15:0]}  + {16'h0, s[31:16]};
        return ~s[15:0];
    endfunction

    logic [31:0] ip_acc;
    logic [15:0] ip_ck;
    always_comb begin
        ip_acc = {16'h0, 16'h4500} + {16'h0, txp_ip_len} + {16'h0, 16'h0000}
               + {16'h0, 16'h4000} + {16'h0, 8'd64, IP_PROTO_UDP}
               + {16'h0, local_ip[31:16]} + {16'h0, local_ip[15:0]}
               + {16'h0, txp_dst_ip[31:16]} + {16'h0, txp_dst_ip[15:0]};
    end
    assign ip_ck = ip_fold(ip_acc);

    logic [7:0] tx_img [0:HDR_LEN-1];
    always_comb begin
        {tx_img[0], tx_img[1], tx_img[2], tx_img[3], tx_img[4], tx_img[5]}    = txp_dst_mac;
        {tx_img[6], tx_img[7], tx_img[8], tx_img[9], tx_img[10], tx_img[11]} = local_mac;
        {tx_img[12], tx_img[13]} = ETHERTYPE_IPV4;
        tx_img[14] = 8'h45; tx_img[15] = 8'h00;
        {tx_img[16], tx_img[17]} = txp_ip_len;
        tx_img[18] = 8'h00; tx_img[19] = 8'h00;               // identification, RFC 6864
        tx_img[20] = 8'h40; tx_img[21] = 8'h00;               // DF set, no fragment
        tx_img[22] = 8'd64; tx_img[23] = IP_PROTO_UDP;
        {tx_img[24], tx_img[25]} = ip_ck;
        {tx_img[26], tx_img[27], tx_img[28], tx_img[29]} = local_ip;
        {tx_img[30], tx_img[31], tx_img[32], tx_img[33]} = txp_dst_ip;
        {tx_img[34], tx_img[35]} = listen_port;
        {tx_img[36], tx_img[37]} = txp_dst_port;
        {tx_img[38], tx_img[39]} = txp_udp_len;
        {tx_img[40], tx_img[41]} = txp_checksum;
    end

    always_ff @(posedge clock) begin
        if (sreset) tx_state <= TX_IDLE;
        else        tx_state <= tx_next_state;
    end

    // A datagram with no payload is never pushed into the transmit
    // buffer (see the file header), so once TX_IDLE sees a committed
    // frame there is always at least one payload byte behind the
    // header: HEADER always leaves for PAYLOAD, never straight to IDLE.
    always_comb begin
        tx_next_state = tx_state;
        case (tx_state)
            TX_IDLE:    if (txf_m_tvalid) tx_next_state = TX_HEADER;
            TX_HEADER:  if (tx_hbeat && tx_hcnt == 16'(HDR_LEN - 1)) tx_next_state = TX_PAYLOAD;
            TX_PAYLOAD: if (txf_m_tvalid && txf_m_tready && txf_m_tlast) tx_next_state = TX_IDLE;
            default:    tx_next_state = TX_IDLE;
        endcase
    end

    always_ff @(posedge clock) begin
        if (sreset) tx_hcnt <= 16'd0;
        else if (tx_state == TX_IDLE) tx_hcnt <= 16'd0;
        else if (tx_state == TX_HEADER && tx_hbeat) tx_hcnt <= tx_hcnt + 16'd1;
    end

    always_comb begin
        m_axi_tuser = 1'b0;
        case (tx_state)
            TX_HEADER: begin
                m_axi_tvalid = 1'b1;
                m_axi_tdata  = tx_img[tx_hcnt[5:0]];
                m_axi_tlast  = 1'b0;
                txf_m_tready = 1'b0;   // the FIFO's head beat stays parked
            end
            TX_PAYLOAD: begin
                m_axi_tvalid = txf_m_tvalid;
                m_axi_tdata  = txf_m_tdata;
                m_axi_tlast  = txf_m_tlast;
                txf_m_tready = m_axi_tready;
            end
            default: begin // TX_IDLE
                m_axi_tvalid = 1'b0;
                m_axi_tdata  = 8'h00;
                m_axi_tlast  = 1'b0;
                txf_m_tready = 1'b0;
            end
        endcase
    end

endmodule
