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
// Title         : AXI Stream TCP Socket
//-----------------------------------------------------------------------------
// File          : axi_stream_tcp_socket.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-09-12
// Last modified : 2026-09-12
//-----------------------------------------------------------------------------
// Description: One passive TCP connection between the IPv4 layer and an
// application, the top that wires the three verified engines -- the
// connection machine tcp_connection_fsm, the receive parser
// tcp_rx_parser, the transmit builder tcp_tx_frame -- around the
// connection record, the transmit ring, the receive packet FIFO, the
// timer and the priority scheduler. See the README for the contract.
//
// Pointers live in the sequence-number domain: the ring byte for a
// send sequence S is at (S - data_base) in the ring, data_base = iss+1
// being the sequence of the first data byte (the SYN takes iss). This
// keeps the SYN and FIN, which each consume a sequence, out of the
// ring index.
//
// First integration: the passive-open handshake, data both ways (a
// wire from m_app to s_app is the echo server) and the close through
// the tuser tokens; the retransmission/persist/idle timer is wired.
// First-cut simplifications flagged for a later pass: the CLOSED
// clean-up resets the datapath in one cycle rather than draining the
// receive FIFO frame by frame, and a segment is cut on a push
// boundary or the effective MSS tracked in a small inline FIFO.

`timescale 1 ns / 100 ps

module axi_stream_tcp_socket #(
    parameter int LOG2_RX_DEPTH   = 11,
    parameter int LOG2_RX_FRAMES  = 6,
    parameter int LOG2_TX_DEPTH   = 11,
    parameter int MSS             = 1460,
    parameter int RTO_CLOCKS      = 10000000,
    parameter int MAX_RETRIES     = 8,
    parameter longint IDLE_CLOCKS = 64'd30000000000,
    parameter int ACK_DELAY_CLOCKS = 4096
)(
    input logic         clock,
    input logic         sreset,

    input logic [47:0]  local_mac,
    input logic [31:0]  local_ip,
    input logic [15:0]  listen_port,

    input logic [7:0]   s_axi_tdata,
    input logic         s_axi_tuser,
    input logic         s_axi_tvalid,
    input logic         s_axi_tlast,
    output logic        s_axi_tready,
    input logic [31:0]  s_src_ip,
    input logic [31:0]  s_dst_ip,
    input logic [15:0]  s_length,
    input logic [47:0]  s_src_mac,

    output logic [7:0]  m_axi_tdata,
    output logic        m_axi_tuser,
    output logic        m_axi_tvalid,
    output logic        m_axi_tlast,
    input logic         m_axi_tready,

    output logic [7:0]  m_app_tdata,
    output logic        m_app_tuser,
    output logic        m_app_tvalid,
    output logic        m_app_tlast,
    input logic         m_app_tready,

    input logic [7:0]   s_app_tdata,
    input logic         s_app_tuser,
    input logic         s_app_tvalid,
    input logic         s_app_tlast,
    output logic        s_app_tready,

    output logic        connected,
    output logic [31:0] peer_ip,
    output logic [15:0] peer_port
);

    localparam int DEPTH = LOG2_TX_DEPTH;
    localparam logic [31:0] RX_CAP  = 32'(1) << LOG2_RX_DEPTH;
    localparam logic [31:0] TX_CAP  = 32'(1) << LOG2_TX_DEPTH;
    localparam int FIN_B = 0, SYN_B = 1, RST_B = 2, ACK_B = 4;

    //================================================================
    // Connection FSM
    //================================================================
    logic fsm_clear, fsm_listening, fsm_syn_ack_pending, fsm_connected;
    logic fsm_rx_open, fsm_tx_open, fsm_fin_pending;
    logic ev_syn_rx, ev_ctl_acked, ev_fin_rx, ev_rst_rx, ev_give_up;
    logic close_ready;

    tcp_connection_fsm fsm (
        .clock (clock), .sreset (sreset),
        .listen (1'b1), .clear_done (1'b1), .close_ready (close_ready),
        .syn_rx (ev_syn_rx), .ctl_acked (ev_ctl_acked), .fin_rx (ev_fin_rx),
        .rst_rx (ev_rst_rx), .give_up (ev_give_up),
        .clear (fsm_clear), .listening (fsm_listening),
        .syn_ack_pending (fsm_syn_ack_pending), .connected (fsm_connected),
        .rx_open (fsm_rx_open), .tx_open (fsm_tx_open), .fin_pending (fsm_fin_pending)
    );

    assign connected = fsm_connected;
    logic clr;
    assign clr = fsm_clear;   // CLOSED: one-cycle datapath clean-up

    //================================================================
    // Connection record and sequence bookkeeping
    //================================================================
    logic [47:0] peer_mac;
    logic [31:0] peer_ip_q;
    logic [15:0] peer_port_q;
    logic [31:0] rcv_nxt;      // next expected receive sequence
    logic [31:0] snd_una;      // oldest unacknowledged send sequence
    logic [31:0] snd_nxt;      // next send sequence for new data
    logic [31:0] data_base;    // sequence of the first ring data byte, iss+1
    logic [31:0] wr_seq;       // sequence one past the last byte the app wrote
    logic [15:0] snd_wnd;      // peer's advertised window
    logic [15:0] eff_mss;      // min(MSS, peer MSS, 536)
    logic [31:0] isn_ctr;      // free-running initial-sequence source
    logic        app_closed;   // the application's close token has arrived

    assign peer_ip   = peer_ip_q;
    assign peer_port = peer_port_q;

    always_ff @(posedge clock) isn_ctr <= sreset ? 32'h12340000 : isn_ctr + 32'h1;

    //================================================================
    // Receive parser
    //================================================================
    logic [7:0]  rxp_pl_tdata;
    logic        rxp_pl_tvalid, rxp_pl_tlast, rxp_pl_tuser, rxp_pl_tready;
    logic [15:0] rx_src_port, rx_dst_port, rx_window, rx_urgent, rx_mss, rx_paylen;
    logic [31:0] rx_seq, rx_ack;
    logic [7:0]  rx_flags;
    logic        rx_hdr_valid, rx_seg_done, rx_seg_ok;

    tcp_rx_parser rxp (
        .clock (clock), .sreset (sreset || clr),
        .s_axi_tdata (s_axi_tdata), .s_axi_tuser (s_axi_tuser), .s_axi_tvalid (s_axi_tvalid),
        .s_axi_tlast (s_axi_tlast), .s_axi_tready (s_axi_tready),
        .s_src_ip (s_src_ip), .s_dst_ip (s_dst_ip), .s_length (s_length),
        .m_pl_tdata (rxp_pl_tdata), .m_pl_tvalid (rxp_pl_tvalid), .m_pl_tlast (rxp_pl_tlast),
        .m_pl_tuser (rxp_pl_tuser), .m_pl_tready (rxp_pl_tready),
        .src_port (rx_src_port), .dst_port (rx_dst_port), .seq_num (rx_seq), .ack_num (rx_ack),
        .flags (rx_flags), .window (rx_window), .urgent (rx_urgent), .mss (rx_mss),
        .payload_len (rx_paylen),
        .hdr_valid (rx_hdr_valid), .seg_done (rx_seg_done), .seg_ok (rx_seg_ok)
    );

    //================================================================
    // Receive FIFO: 9-bit, byte plus a close-token bit
    //================================================================
    logic [8:0]              rxf_s_tdata;
    logic                    rxf_s_tuser, rxf_s_tvalid, rxf_s_tlast, rxf_s_tready;
    logic [8:0]              rxf_m_tdata;
    logic                    rxf_m_tvalid, rxf_m_tlast;
    logic [LOG2_RX_DEPTH:0]  rxf_level;
    logic [LOG2_RX_FRAMES:0] rxf_frames;

    axi_stream_packet_fifo #(
        .DATA_WIDTH (9), .LOG2_DEPTH (LOG2_RX_DEPTH), .LOG2_FRAMES (LOG2_RX_FRAMES),
        .INFO_WIDTH (1), .DROP_ON_FULL (0)
    ) rxfifo (
        .clock (clock), .sreset (sreset || clr),
        .s_axi_tdata (rxf_s_tdata), .s_axi_tuser (rxf_s_tuser), .s_axi_tvalid (rxf_s_tvalid),
        .s_axi_tlast (rxf_s_tlast), .s_axi_tready (rxf_s_tready), .s_info (1'b0),
        .m_axi_tdata (rxf_m_tdata), .m_axi_tvalid (rxf_m_tvalid), .m_axi_tlast (rxf_m_tlast),
        .m_axi_tready (m_app_tready), .m_info (), .m_length (),
        .level (rxf_level), .frames (rxf_frames)
    );

    assign m_app_tdata  = rxf_m_tdata[7:0];
    assign m_app_tuser  = rxf_m_tdata[8];
    assign m_app_tvalid = rxf_m_tvalid;
    assign m_app_tlast  = rxf_m_tlast;

    logic [31:0] rx_free;
    logic        rx_frame_free;
    assign rx_free       = RX_CAP - {20'h0, rxf_level};
    assign rx_frame_free = !rxf_frames[LOG2_RX_FRAMES];

    //================================================================
    // Receive classification (combinational, valid with the header)
    //================================================================
    logic is_syn, is_ack, is_rst, is_fin, to_us, peer_match;
    assign is_syn = rx_flags[SYN_B];
    assign is_ack = rx_flags[ACK_B];
    assign is_rst = rx_flags[RST_B];
    assign is_fin = rx_flags[FIN_B];
    assign to_us  = (rx_dst_port == listen_port) && (s_dst_ip == local_ip);
    assign peer_match = (s_src_ip == peer_ip_q) && (rx_src_port == peer_port_q);

    logic in_order, fits_data, fits_fin;
    assign in_order  = (rx_seq == rcv_nxt);
    assign fits_data = ({16'h0, rx_paylen} <= rx_free) && rx_frame_free;
    assign fits_fin  = ({16'h0, rx_paylen} <  rx_free) && rx_frame_free;

    // Combinational classification, stable from hdr_valid to seg_done
    // (the parser holds the fields), so seg_done can use it directly --
    // a header-only segment fires hdr_valid and seg_done on one cycle,
    // where a registered flag would still be stale.
    logic acc_syn, acc_data, acc_fin, acc_ack, acc_rst, is_foreign;
    assign acc_syn  = fsm_listening && to_us && is_syn && !is_ack;
    assign acc_data = fsm_rx_open && peer_match && to_us && in_order
                      && (rx_paylen != 16'h0) && fits_data;
    assign acc_fin  = fsm_rx_open && peer_match && to_us && in_order && is_fin && fits_fin;
    assign acc_ack  = (fsm_connected || fsm_syn_ack_pending) && peer_match && to_us && is_ack;
    assign acc_rst  = fsm_connected && peer_match && to_us && is_rst;
    assign is_foreign = !is_rst && ( (!to_us)
                                   || (fsm_listening && is_ack)
                                   || (fsm_connected && !peer_match) );

    // Latched per-segment decisions, set on hdr_valid, held to seg_done
    logic accept_data_q, foreign_q;
    logic pending_token;       // an accepted FIN owes a receive-side token

    logic ack_adv;             // this segment's ack advances snd_una
    assign ack_adv = acc_ack && ($signed(rx_ack - snd_una) > 0)
                                && ($signed(rx_ack - snd_nxt) <= 0);

    //================================================================
    // Transmit ring: inferred distributed RAM, combinational read
    //================================================================
    logic [7:0] tx_ring [0:(1<<DEPTH)-1];

    logic app_data_beat, app_close_beat;
    assign app_data_beat  = s_app_tvalid && s_app_tready && !s_app_tuser;
    assign app_close_beat = s_app_tvalid && s_app_tready &&  s_app_tuser;

    logic [31:0] ring_used;
    assign ring_used    = wr_seq - snd_una;
    assign s_app_tready = fsm_tx_open && (ring_used != TX_CAP);

    // Ring index uses the same (seq - data_base) mapping as the read
    logic [31:0] wr_off;
    assign wr_off = wr_seq - data_base;
    always_ff @(posedge clock)
        if (app_data_beat) tx_ring[wr_off[DEPTH-1:0]] <= s_app_tdata;

    // Push-boundary FIFO: send sequences at which a push/close landed
    localparam int BND = (1 << LOG2_RX_FRAMES);
    logic [31:0] bnd [0:BND-1];
    logic [LOG2_RX_FRAMES:0] bnd_wr, bnd_rd;
    logic        bnd_have;
    logic [31:0] bnd_head;
    assign bnd_have = bnd_wr != bnd_rd;
    assign bnd_head = bnd[bnd_rd[LOG2_RX_FRAMES-1:0]];

    //================================================================
    // Transmit frame builder
    //================================================================
    logic        tx_start, tx_with_mss, tx_busy, tx_busy_d, tx_inflight;
    logic [15:0] tx_pl_len;
    logic [47:0] tx_dst_mac;
    logic [15:0] tx_ip_id;
    logic [15:0] tx_src_port, tx_dst_port;
    logic [31:0] tx_seq, tx_ack;
    logic [7:0]  tx_flags;
    logic [15:0] tx_window, tx_mss;
    logic [15:0] tx_pl_addr;
    logic [7:0]  tx_pl_data;
    logic [31:0] tx_base;      // send sequence the payload starts at

    // Ring byte for the payload offset: (base + offset - data_base)
    logic [31:0] tx_rd_off;
    assign tx_rd_off  = tx_base + 32'(tx_pl_addr) - data_base;
    assign tx_pl_data = tx_ring[tx_rd_off[DEPTH-1:0]];

    tcp_tx_frame txf (
        .clock (clock), .sreset (sreset || clr),
        .start (tx_start), .with_mss (tx_with_mss), .pl_len (tx_pl_len),
        .dst_mac (tx_dst_mac), .src_mac (local_mac), .ip_id (tx_ip_id),
        .src_ip (local_ip), .dst_ip (peer_ip_q),
        .src_port (tx_src_port), .dst_port (tx_dst_port),
        .seq (tx_seq), .ack (tx_ack), .flags (tx_flags), .window (tx_window), .mss (tx_mss),
        .pl_addr (tx_pl_addr), .pl_data (tx_pl_data),
        .m_axi_tdata (m_axi_tdata), .m_axi_tuser (m_axi_tuser), .m_axi_tvalid (m_axi_tvalid),
        .m_axi_tlast (m_axi_tlast), .m_axi_tready (m_axi_tready), .busy (tx_busy)
    );

    always_ff @(posedge clock) tx_busy_d <= sreset ? 1'b0 : tx_busy;
    logic tx_done;
    assign tx_done = tx_busy_d && !tx_busy;   // the builder finished a frame

    //================================================================
    // Timers, retries, ack hold-off
    //================================================================
    logic [63:0] rto_ctr, idle_ctr;
    logic [15:0] ack_ctr;
    logic [7:0]  retries;
    logic        outstanding, zero_wnd_wait, rto_run, rto_expired;
    logic        ack_owed, idle_expired;

    assign outstanding   = ($signed(snd_nxt - snd_una) > 0);
    assign zero_wnd_wait = (snd_wnd == 16'h0) && (wr_seq != snd_nxt);
    assign rto_run       = fsm_connected && (outstanding || zero_wnd_wait);
    assign rto_expired   = rto_run && (rto_ctr >= 64'(RTO_CLOCKS));
    assign idle_expired  = fsm_connected && (IDLE_CLOCKS != 0) && (idle_ctr >= 64'(IDLE_CLOCKS));

    //================================================================
    // Scheduler
    //================================================================
    typedef enum logic [2:0] { K_NONE, K_RST, K_SYNACK, K_FIN, K_RESEND, K_DATA, K_ACK } kind_t;
    kind_t       kind_q;
    logic        ctrl_sent;    // the pending control segment was sent once

    logic [31:0] unsent, to_bnd, cand;
    logic [15:0] send_len;
    logic        data_ready;
    logic [31:0] iss_val;      // our SYN sequence, data_base - 1
    logic [15:0] resend_len_v; // outstanding data, MSS-capped
    logic        data_outstanding;  // unacked bytes are data, not the SYN/FIN
    assign iss_val          = data_base - 32'h1;
    assign data_outstanding = ($signed(snd_nxt - snd_una) > 0)
                              && ($signed(snd_una - data_base) >= 0)
                              && !fsm_syn_ack_pending && !fsm_fin_pending;
    assign unsent = wr_seq - snd_nxt;
    assign to_bnd = bnd_have ? (bnd_head - snd_nxt) : unsent;
    always_comb begin
        cand = to_bnd;
        if (cand > 32'(eff_mss)) cand = 32'(eff_mss);
        if (cand > {16'h0, snd_wnd}) cand = {16'h0, snd_wnd};
        send_len   = 16'(cand);
        data_ready = fsm_tx_open && (send_len != 16'h0)
                     && (bnd_have || (unsent >= 32'(eff_mss)));
        // Retransmit length: outstanding data capped at the MSS
        resend_len_v = ((snd_nxt - snd_una) > 32'(eff_mss)) ? 16'(eff_mss)
                                                            : 16'(snd_nxt - snd_una);
    end

    logic        reset_pending;
    logic [15:0] adv_wnd;
    assign adv_wnd = (rx_free > 32'hFFFF) ? 16'hFFFF : 16'(rx_free);

    kind_t sched_kind;
    always_comb begin
        if      (reset_pending)                                sched_kind = K_RST;
        else if (fsm_syn_ack_pending && !ctrl_sent)            sched_kind = K_SYNACK;
        else if (fsm_fin_pending && !ctrl_sent)                sched_kind = K_FIN;
        else if (rto_expired && data_outstanding)              sched_kind = K_RESEND;
        else if (data_ready)                                   sched_kind = K_DATA;
        else if (ack_owed && ack_ctr >= 16'(ACK_DELAY_CLOCKS)) sched_kind = K_ACK;
        else                                                   sched_kind = K_NONE;
    end

    // Reset-request record from the offending segment
    logic [47:0] rst_mac;
    logic [31:0] rst_ip, rst_seq, rst_ack;
    logic [15:0] rst_sport, rst_dport, rst_len;
    logic        rst_hasack, rst_syn, rst_fin;

    //================================================================
    // Receive-side control: events, record, FIFO write, FIN token
    //================================================================
    logic pl_active, token_write;
    assign pl_active   = rxp_pl_tvalid;
    assign token_write = pending_token && !rxp_pl_tvalid && !clr;

    always_comb begin
        if (pl_active) begin
            rxf_s_tvalid = rxp_pl_tvalid;
            rxf_s_tdata  = {1'b0, rxp_pl_tdata};
            rxf_s_tlast  = rxp_pl_tlast;
            rxf_s_tuser  = rxp_pl_tuser || !accept_data_q;   // doom if bad or not accepted
        end
        else begin
            rxf_s_tvalid = token_write;
            rxf_s_tdata  = {1'b1, 8'h00};
            rxf_s_tlast  = 1'b1;
            rxf_s_tuser  = 1'b0;
        end
    end
    assign rxp_pl_tready = rxf_s_tready;

    // close_ready: the app closed, the ring is empty, all sent is acked
    assign close_ready = app_closed && (wr_seq == snd_una) && (snd_una == snd_nxt);

    always_ff @(posedge clock) begin
        // Default one-cycle pulses
        ev_syn_rx    <= 1'b0;
        ev_ctl_acked <= 1'b0;
        ev_fin_rx    <= 1'b0;
        ev_rst_rx    <= 1'b0;

        if (sreset) begin
            rcv_nxt <= 32'h0; snd_una <= 32'h0; snd_nxt <= 32'h0; data_base <= 32'h0;
            wr_seq <= 32'h0; snd_wnd <= 16'h0; eff_mss <= 16'h0;
            peer_ip_q <= 32'h0; peer_port_q <= 16'h0; peer_mac <= 48'h0;
            app_closed <= 1'b0; pending_token <= 1'b0; reset_pending <= 1'b0;
            accept_data_q <= 1'b0; foreign_q <= 1'b0;
            bnd_wr <= '0; bnd_rd <= '0;
            ctrl_sent <= 1'b0; retries <= 8'h0;
            rto_ctr <= 64'h0; idle_ctr <= 64'h0; ack_ctr <= 16'h0; ack_owed <= 1'b0;
            kind_q <= K_NONE; tx_start <= 1'b0; tx_inflight <= 1'b0;
        end
        else if (clr) begin
            // One-cycle clean-up: forget the connection
            snd_una <= 32'h0; snd_nxt <= 32'h0; wr_seq <= 32'h0; data_base <= 32'h0;
            app_closed <= 1'b0; pending_token <= 1'b0; reset_pending <= 1'b0;
            bnd_wr <= '0; bnd_rd <= '0; ctrl_sent <= 1'b0; retries <= 8'h0;
            rto_ctr <= 64'h0; idle_ctr <= 64'h0; ack_ctr <= 16'h0; ack_owed <= 1'b0;
            peer_ip_q <= 32'h0; peer_port_q <= 16'h0;
        end
        else begin
            //--------------------------------------------------------
            // Application close token
            //--------------------------------------------------------
            if (app_close_beat) app_closed <= 1'b1;

            //--------------------------------------------------------
            // Ring write pointer and push boundaries
            //--------------------------------------------------------
            if (app_data_beat)  wr_seq <= wr_seq + 32'h1;
            if (app_data_beat && s_app_tlast) begin
                bnd[bnd_wr[LOG2_RX_FRAMES-1:0]] <= wr_seq + 32'h1;
                bnd_wr <= bnd_wr + 1'b1;
            end

            //--------------------------------------------------------
            // Per-segment decisions, latched as the header lands
            //--------------------------------------------------------
            if (rx_hdr_valid) begin
                // Only the payload-doom flag needs to survive to the
                // payload beats; everything else is used combinationally
                // at seg_done (acc_*), stable meanwhile
                accept_data_q <= acc_data;
                foreign_q     <= is_foreign;   // for the RST addressing at send time
                // Capture the offending segment for a possible reset
                rst_mac   <= s_src_mac; rst_ip <= s_src_ip;
                rst_sport <= rx_src_port; rst_dport <= rx_dst_port;
                rst_seq   <= rx_seq; rst_ack <= rx_ack;
                rst_hasack <= is_ack; rst_len <= rx_paylen;
                rst_syn <= is_syn; rst_fin <= is_fin;
            end

            //--------------------------------------------------------
            // Segment end: apply the verdict
            //--------------------------------------------------------
            if (rx_seg_done) begin
                idle_ctr <= 64'h0;   // any segment end refreshes the idle limit

                if (rx_seg_ok && acc_syn) begin
                    // Accept the SYN, open the record
                    peer_ip_q   <= s_src_ip;
                    peer_port_q <= rx_src_port;
                    peer_mac    <= s_src_mac;
                    rcv_nxt     <= rx_seq + 32'h1;
                    data_base   <= isn_ctr + 32'h1;
                    snd_una     <= isn_ctr;
                    snd_nxt     <= isn_ctr;
                    wr_seq      <= isn_ctr + 32'h1;
                    snd_wnd     <= rx_window;
                    eff_mss     <= (rx_mss != 16'h0)
                                   ? ((rx_mss < 16'(MSS)) ? rx_mss : 16'(MSS))
                                   : ((16'd536 < 16'(MSS)) ? 16'd536 : 16'(MSS));
                    ctrl_sent   <= 1'b0;
                    ev_syn_rx   <= 1'b1;
                end

                if (rx_seg_ok && acc_ack) begin
                    snd_wnd <= rx_window;
                    if (ack_adv) begin
                        snd_una  <= rx_ack;
                        retries  <= 8'h0;
                        rto_ctr  <= 64'h0;
                        if ((fsm_syn_ack_pending || fsm_fin_pending) && (rx_ack == snd_nxt))
                            ev_ctl_acked <= 1'b1;
                    end
                end

                if (rx_seg_ok && acc_data) begin
                    rcv_nxt  <= rcv_nxt + {16'h0, rx_paylen};
                    ack_owed <= 1'b1;
                    ack_ctr  <= 16'h0;
                end

                if (rx_seg_ok && acc_fin) begin
                    // The FIN sits after any data this segment carried
                    rcv_nxt       <= rcv_nxt + {16'h0, rx_paylen} + 32'h1;
                    ack_owed      <= 1'b1;
                    ack_ctr       <= 16'h0;
                    pending_token <= 1'b1;
                    ev_fin_rx     <= 1'b1;
                end

                // A peer segment that carries data or a FIN but was not
                // accepted (old, out of order, or does not fit) is
                // answered with a pure acknowledgement of rcv_nxt, so the
                // peer learns what we still expect
                if (rx_seg_ok && fsm_connected && peer_match && to_us
                    && (rx_paylen != 16'h0 || is_fin) && !acc_data && !acc_fin) begin
                    ack_owed <= 1'b1;
                    ack_ctr  <= 16'h0;
                end

                if (rx_seg_ok && acc_rst) begin
                    ev_rst_rx <= 1'b1;
                end

                if (rx_seg_ok && is_foreign) begin
                    reset_pending <= 1'b1;
                end
            end

            //--------------------------------------------------------
            // The FIN token has been written into the receive FIFO
            //--------------------------------------------------------
            if (token_write && rxf_s_tready) pending_token <= 1'b0;

            //--------------------------------------------------------
            // Timers
            //--------------------------------------------------------
            if (rto_run) rto_ctr <= rto_ctr + 64'h1; else rto_ctr <= 64'h0;
            if (fsm_connected) idle_ctr <= idle_ctr + 64'h1;
            if (ack_owed) ack_ctr <= ack_ctr + 16'h1;

            //--------------------------------------------------------
            // Scheduler: launch a segment when the builder is idle
            //--------------------------------------------------------
            // A control segment is "sent" only while one is pending; once
            // the state has no control owed, forget it so the next state's
            // control is sent afresh
            if (!fsm_syn_ack_pending && !fsm_fin_pending) ctrl_sent <= 1'b0;
            tx_start <= 1'b0;
            if (!tx_inflight && sched_kind != K_NONE) begin
                tx_start    <= 1'b1;
                tx_inflight <= 1'b1;
                kind_q      <= sched_kind;
                case (sched_kind)
                    K_SYNACK: begin
                        tx_with_mss <= 1'b1; tx_pl_len <= 16'h0; tx_flags <= 8'h12; // SYN|ACK
                        tx_seq <= iss_val; tx_ack <= rcv_nxt; tx_base <= snd_nxt;
                    end
                    K_FIN: begin
                        tx_with_mss <= 1'b0; tx_pl_len <= 16'h0; tx_flags <= 8'h11; // FIN|ACK
                        tx_seq <= snd_nxt; tx_ack <= rcv_nxt; tx_base <= snd_nxt;
                    end
                    K_DATA: begin
                        tx_with_mss <= 1'b0; tx_pl_len <= send_len; tx_flags <= 8'h18; // PSH|ACK
                        tx_seq <= snd_nxt; tx_ack <= rcv_nxt; tx_base <= snd_nxt;
                    end
                    K_RESEND: begin
                        tx_with_mss <= 1'b0;
                        tx_pl_len <= resend_len_v; tx_flags <= 8'h18;
                        tx_seq <= snd_una; tx_ack <= rcv_nxt; tx_base <= snd_una;
                    end
                    K_ACK: begin
                        tx_with_mss <= 1'b0; tx_pl_len <= 16'h0; tx_flags <= 8'h10; // ACK
                        tx_seq <= snd_nxt; tx_ack <= rcv_nxt; tx_base <= snd_nxt;
                    end
                    K_RST: begin
                        tx_with_mss <= 1'b0; tx_pl_len <= 16'h0;
                        tx_flags <= rst_hasack ? 8'h04 : 8'h14;                    // RST or RST|ACK
                        tx_seq <= rst_hasack ? rst_ack : 32'h0;
                        tx_ack <= rst_seq + {16'h0, rst_len}
                                  + (rst_syn ? 32'h1 : 32'h0) + (rst_fin ? 32'h1 : 32'h0);
                        tx_base <= snd_nxt;
                    end
                    default: ;
                endcase
                // Common addressing
                tx_ip_id    <= isn_ctr[15:0];
                tx_window   <= adv_wnd;
                tx_mss      <= 16'(MSS);
                tx_src_port <= listen_port;
                if (sched_kind == K_RST && foreign_q) begin
                    tx_dst_mac  <= rst_mac;
                    tx_dst_port <= rst_sport;
                end
                else begin
                    tx_dst_mac  <= peer_mac;
                    tx_dst_port <= peer_port_q;
                end
            end

            //--------------------------------------------------------
            // Segment sent: side effects
            //--------------------------------------------------------
            if (tx_done) begin
                tx_inflight <= 1'b0;
                rto_ctr <= 64'h0;
                case (kind_q)
                    K_SYNACK: begin snd_nxt <= iss_val + 32'h1; ctrl_sent <= 1'b1; end
                    K_FIN:    begin snd_nxt <= snd_nxt + 32'h1;   ctrl_sent <= 1'b1; end
                    K_DATA: begin
                        snd_nxt <= snd_nxt + {16'h0, tx_pl_len};
                        if (bnd_have && (snd_nxt + {16'h0, tx_pl_len} == bnd_head))
                            bnd_rd <= bnd_rd + 1'b1;
                        ack_owed <= 1'b0;
                    end
                    K_ACK:    ack_owed <= 1'b0;
                    K_RESEND: retries <= retries + 8'h1;
                    K_RST:    reset_pending <= 1'b0;
                    default: ;
                endcase
                // A data or control send also carries the ACK
                if (kind_q == K_SYNACK || kind_q == K_FIN || kind_q == K_DATA)
                    ack_owed <= 1'b0;
            end

            //--------------------------------------------------------
            // Give up: retransmission budget or idle limit
            //--------------------------------------------------------
            if ((retries >= 8'(MAX_RETRIES)) || idle_expired) begin
                ev_give_up <= 1'b1;
                // On giving up, a reset is owed to the peer
                reset_pending <= 1'b1;
            end
            else begin
                ev_give_up <= 1'b0;
            end
        end
    end




endmodule
