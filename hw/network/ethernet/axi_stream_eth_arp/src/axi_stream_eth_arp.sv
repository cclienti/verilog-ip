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
// Title         : AXI Stream Ethernet ARP Responder
//-----------------------------------------------------------------------------
// File          : axi_stream_eth_arp.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-28
// Last modified : 2026-08-28
//-----------------------------------------------------------------------------
// Description: This module answers ARP requests for the local IPv4
// address. It consumes ARP payload frames as the eth parser and packet
// demux deliver them -- header stripped, whole frames -- and validates
// them on the fly: HTYPE 1, PTYPE 0x0800, HLEN 6, PLEN 4, OPER request
// or reply, target IP equal to local_ip, at least the 28 ARP bytes
// before any Ethernet padding, and no tuser. Anything else is consumed
// and ignored.
//
// A valid request triggers a complete 42-byte Ethernet reply on the
// master stream -- destination the requester's SHA, source local_mac,
// EtherType 0x0806, then the is-at payload -- ready for the packet mux
// and the FCS generator, which pads to the minimum frame; no separate
// header-builder stage is needed. The input holds tready low while a
// reply drains, the packet FIFO upstream absorbs the stall. The stall
// holds the packet demux, so every receive protocol waits on the
// reply draining: the transmit merge must guarantee forward progress,
// which the round-robin packet mux does.
//
// Every valid packet, request or reply, fires the one-cycle
// learn_valid pulse with the sender's mapping on learn_mac/learn_ip,
// for a future ARP cache; leave the port open until then. local_mac
// and local_ip are sampled once per frame with its first beat, so the
// target-IP compare and the emitted reply always use the same
// identity.

`timescale 1 ns / 100 ps

module axi_stream_eth_arp (
    input logic        clock,
    input logic        sreset,

    // Endpoint identity, sampled with each frame's first beat
    input logic [47:0] local_mac,
    input logic [31:0] local_ip,

    // AXI Stream input, ARP payload frames from the packet demux
    input logic [7:0]  s_axi_tdata,
    input logic        s_axi_tuser,
    input logic        s_axi_tvalid,
    input logic        s_axi_tlast,
    output logic       s_axi_tready,

    // AXI Stream output, complete Ethernet reply frames
    output logic [7:0] m_axi_tdata,
    output logic       m_axi_tuser,
    output logic       m_axi_tvalid,
    output logic       m_axi_tlast,
    input logic        m_axi_tready,

    // Sender mapping of every valid packet, one-cycle pulse
    output logic        learn_valid,
    output logic [47:0] learn_mac,
    output logic [31:0] learn_ip
);

    // ARP constants, bytes 0..6 of the payload (OPER low byte apart)
    localparam logic [55:0] ARP_HEAD = {16'h0001, 16'h0800, 8'd6, 8'd4, 8'h00};

    logic         in_reply;     // a reply drains, the receive side stalls
    logic [4:0]   rx_cnt;       // payload byte index, saturates at 28
    logic [5:0]   tx_cnt;       // reply byte index, 0..41
    logic         s_accept;     // input beat accepted this cycle
    logic         byte_bad;     // live mismatch on the current byte
    logic         frame_ok;     // whole-frame verdict on the closing beat
    logic         bad_q;        // sticky field mismatch
    logic         err_q;        // sticky input tuser
    logic         oper_reply_q; // OPER said reply, learn without answering
    logic [47:0]  sha_q;        // captured sender MAC
    logic [31:0]  spa_q;        // captured sender IPv4
    logic [47:0]  my_mac_q;     // identity sample of the frame start
    logic [31:0]  my_ip_q;      // identity sample of the frame start
    logic [335:0] reply_vec;    // 42-byte reply frame image

    //-------------------------------------------
    // Handshake: receive stalls while the reply
    // drains, the reply follows its consumer
    //-------------------------------------------
    assign s_axi_tready = !in_reply;
    assign s_accept     = s_axi_tvalid && s_axi_tready;

    //-------------------------------------------
    // On-the-fly validation of the request
    //-------------------------------------------
    always_comb begin
        byte_bad = 1'b0;
        if (rx_cnt <= 5'd6) begin
            byte_bad = s_axi_tdata != ARP_HEAD[8*(6 - 32'(rx_cnt)) +: 8];
        end
        else if (rx_cnt == 5'd7) begin
            byte_bad = s_axi_tdata != 8'h01 && s_axi_tdata != 8'h02;
        end
        else if (rx_cnt >= 5'd24 && rx_cnt <= 5'd27) begin
            byte_bad = s_axi_tdata != my_ip_q[8*(27 - 32'(rx_cnt)) +: 8];
        end
    end

    // The whole verdict on the closing beat: nothing bad so far or
    // live, no error flag, and the 28 ARP bytes all seen
    assign frame_ok = !bad_q && !byte_bad && !err_q && !s_axi_tuser
                   && rx_cnt >= 5'd27;

    //-------------------------------------------
    // Receive, decide, emit
    //-------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            in_reply     <= 1'b0;
            rx_cnt       <= '0;
            tx_cnt       <= '0;
            bad_q        <= 1'b0;
            err_q        <= 1'b0;
            oper_reply_q <= 1'b0;
            learn_valid  <= 1'b0;
        end
        else begin
            learn_valid <= 1'b0;

            if (!in_reply && s_accept) begin
                rx_cnt <= rx_cnt == 5'd28 ? 5'd28 : rx_cnt + 5'd1;

                // One identity per frame: the target-IP compare and
                // the emitted reply use the same sample
                if (rx_cnt == 5'd0) begin
                    my_mac_q <= local_mac;
                    my_ip_q  <= local_ip;
                end
                if (rx_cnt >= 5'd8 && rx_cnt <= 5'd13) begin
                    sha_q <= {sha_q[39:0], s_axi_tdata};
                end
                if (rx_cnt >= 5'd14 && rx_cnt <= 5'd17) begin
                    spa_q <= {spa_q[23:0], s_axi_tdata};
                end
                if (rx_cnt == 5'd7 && s_axi_tdata == 8'h02) begin
                    oper_reply_q <= 1'b1;
                end
                if (byte_bad) begin
                    bad_q <= 1'b1;
                end
                if (s_axi_tuser) begin
                    err_q <= 1'b1;
                end

                if (s_axi_tlast) begin
                    rx_cnt       <= '0;
                    bad_q        <= 1'b0;
                    err_q        <= 1'b0;
                    oper_reply_q <= 1'b0;
                    if (frame_ok) begin
                        learn_valid <= 1'b1;
                        learn_mac   <= sha_q;
                        learn_ip    <= spa_q;
                        if (!oper_reply_q) begin
                            in_reply <= 1'b1;
                            tx_cnt   <= '0;
                        end
                    end
                end
            end
            else if (in_reply && m_axi_tready) begin
                if (tx_cnt == 6'd41) begin
                    in_reply <= 1'b0;
                    tx_cnt   <= '0;
                end
                else begin
                    tx_cnt <= tx_cnt + 6'd1;
                end
            end
        end
    end

    //-------------------------------------------
    // The reply frame, oldest byte in the MSBs
    //-------------------------------------------
    // ARP_HEAD plus the reply OPER low byte: the validator and the
    // builder share one encoding of the fixed protocol bytes
    assign reply_vec = {sha_q, my_mac_q, 16'h0806,
                        ARP_HEAD, 8'h02,
                        my_mac_q, my_ip_q, sha_q, spa_q};

    assign m_axi_tdata  = reply_vec[8*(41 - 32'(tx_cnt)) +: 8];
    assign m_axi_tvalid = in_reply;
    assign m_axi_tlast  = tx_cnt == 6'd41;
    assign m_axi_tuser  = 1'b0;

endmodule
