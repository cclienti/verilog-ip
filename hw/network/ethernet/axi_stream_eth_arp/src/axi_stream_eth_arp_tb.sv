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
// Title         : AXI Stream Ethernet ARP Responder Testbench
//-----------------------------------------------------------------------------
// File          : axi_stream_eth_arp_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-28
// Last modified : 2026-08-28
//-----------------------------------------------------------------------------
// Description :
// Testbench of the ARP responder behind its documented chain: Ethernet
// frames enter the eth parser, the packet demux routes EtherType
// 0x0806 to the responder, and the IPv4 output must never see a beat.
// Valid requests -- broadcast or unicast, padded to the minimum frame
// or the bare 28 ARP bytes -- must come back as byte-exact 42-byte
// replies and fire the learn pulse; valid ARP replies addressed to us
// must fire learn only. Wrong target IP, corrupted HTYPE / PTYPE /
// HLEN / PLEN / OPER, payloads shorter than 28 bytes and frames with
// tuser on a payload beat must produce neither, while tuser on an
// Ethernet header beat is swallowed by the parser and must change
// nothing. Back-to-back requests prove the input
// stalls cleanly while a reply drains, and a random soak mixes all of
// it under random backpressure.

`timescale 1 ns / 100 ps

module axi_stream_eth_arp_tb;

    localparam logic [47:0] LOCAL_MAC  = 48'h02_12_34_56_78_9A;
    localparam logic [47:0] REMOTE_MAC = 48'h02_AB_CD_EF_01_23;
    localparam logic [47:0] BCAST_MAC  = 48'hFF_FF_FF_FF_FF_FF;
    localparam logic [31:0] LOCAL_IP   = 32'hC0_A8_01_2A;
    localparam logic [31:0] REMOTE_IP  = 32'hC0_A8_01_63;

    integer errors = 0;

    //----------------------------------------------------------------
    // Clock and reset generation
    //----------------------------------------------------------------
    logic clock;
    logic sreset;

    initial begin
        clock       = 0;
        sreset      = 1;
        #40 sreset  = 0;
    end

    always
        #10 clock = !clock;

    //----------------------------------------------------------------
    // Chain: eth parser -> packet demux -> ARP responder
    //----------------------------------------------------------------
    logic [7:0]  s_tdata;
    logic        s_tuser;
    logic        s_tvalid;
    logic        s_tlast;
    logic        s_tready;
    logic [11:0] s_length;

    logic [7:0]  pd_tdata;
    logic        pd_tuser;
    logic        pd_tvalid;
    logic        pd_tlast;
    logic        pd_tready;
    logic [1:0]  pd_sel;
    logic [47:0] pd_dst;
    logic [47:0] pd_src;
    logic [15:0] pd_ethertype;
    logic [11:0] pd_length;

    logic [15:0] d_tdata;
    logic [1:0]  d_tuser;
    logic [1:0]  d_tvalid;
    logic [1:0]  d_tlast;
    logic [1:0]  d_tready;
    logic        d_info;

    logic [7:0]  r_tdata;
    logic        r_tuser;
    logic        r_tvalid;
    logic        r_tlast;
    logic        r_tready;
    logic        learn_valid;
    logic [47:0] learn_mac;
    logic [31:0] learn_ip;

    axi_stream_eth_parser
    #(
        .NB_ETHERTYPES    (2),
        .ETHERTYPES       ({16'h0806, 16'h0800}),
        .LENGTH_WIDTH     (12),
        .ACCEPT_MULTICAST (0)
    )
    axi_stream_eth_parser_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .local_mac    (LOCAL_MAC),
        .promiscuous  (1'b0),
        .s_axi_tdata  (s_tdata),
        .s_axi_tuser  (s_tuser),
        .s_axi_tvalid (s_tvalid),
        .s_axi_tlast  (s_tlast),
        .s_axi_tready (s_tready),
        .s_length     (s_length),
        .m_axi_tdata  (pd_tdata),
        .m_axi_tuser  (pd_tuser),
        .m_axi_tvalid (pd_tvalid),
        .m_axi_tlast  (pd_tlast),
        .m_axi_tready (pd_tready),
        .m_sel        (pd_sel),
        .m_dst_mac    (pd_dst),
        .m_src_mac    (pd_src),
        .m_ethertype  (pd_ethertype),
        .m_length     (pd_length)
    );

    axi_stream_packet_demux
    #(
        .NB_OUTPUTS (2),
        .DATA_WIDTH (8),
        .INFO_WIDTH (1)
    )
    axi_stream_packet_demux_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (pd_tdata),
        .s_axi_tuser  (pd_tuser),
        .s_axi_tvalid (pd_tvalid),
        .s_axi_tlast  (pd_tlast),
        .s_axi_tready (pd_tready),
        .s_sel        (pd_sel),
        .s_info       (1'b0),
        .m_axi_tdata  (d_tdata),
        .m_axi_tuser  (d_tuser),
        .m_axi_tvalid (d_tvalid),
        .m_axi_tlast  (d_tlast),
        .m_axi_tready (d_tready),
        .m_info       (d_info)
    );

    // The IPv4 output must stay silent, its ready is kept high
    assign d_tready[0] = 1'b1;

    axi_stream_eth_arp
    axi_stream_eth_arp_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .local_mac    (LOCAL_MAC),
        .local_ip     (LOCAL_IP),
        .s_axi_tdata  (d_tdata[15:8]),
        .s_axi_tuser  (d_tuser[1]),
        .s_axi_tvalid (d_tvalid[1]),
        .s_axi_tlast  (d_tlast[1]),
        .s_axi_tready (d_tready[1]),
        .m_axi_tdata  (r_tdata),
        .m_axi_tuser  (r_tuser),
        .m_axi_tvalid (r_tvalid),
        .m_axi_tlast  (r_tlast),
        .m_axi_tready (r_tready),
        .learn_valid  (learn_valid),
        .learn_mac    (learn_mac),
        .learn_ip     (learn_ip)
    );

    //----------------------------------------------------------------
    // Random backpressure on the reply stream
    //----------------------------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            r_tready <= 1'b0;
        end
        else begin
            r_tready <= $urandom_range(0, 1) == 1;
        end
    end

    //----------------------------------------------------------------
    // Expected reply beats {last, user, data} and learn pulses
    //----------------------------------------------------------------
    logic [9:0]  exp_r [0:4095];
    integer      exp_r_count;
    integer      r_mon_idx;

    logic [79:0] exp_learn [0:127];
    integer      exp_learn_count;
    integer      learn_idx;

    //----------------------------------------------------------------
    // Frame builders
    //----------------------------------------------------------------
    function automatic logic [7:0] eth_byte(input logic [47:0] dst, input logic [47:0] src,
                                            input logic [15:0] ethertype, input integer k);
        if (k < 6)   return dst[8*(5-k) +: 8];
        if (k < 12)  return src[8*(11-k) +: 8];
        if (k == 12) return ethertype[15:8];
        return ethertype[7:0];
    endfunction

    // ARP payload byte k, with a selectable corruption:
    // 0 none, 1 htype, 2 ptype, 3 hlen, 4 plen, 5 oper
    function automatic logic [7:0] arp_byte(input logic [7:0] oper,
                                            input logic [47:0] sha, input logic [31:0] spa,
                                            input logic [47:0] tha, input logic [31:0] tpa,
                                            input integer bad_kind, input integer k);
        logic [7:0] b;
        if (k < 2)       b = k == 0 ? 8'h00 : 8'h01;
        else if (k < 4)  b = k == 2 ? 8'h08 : 8'h00;
        else if (k == 4) b = 8'd6;
        else if (k == 5) b = 8'd4;
        else if (k == 6) b = 8'h00;
        else if (k == 7) b = oper;
        else if (k < 14) b = sha[8*(13-k) +: 8];
        else if (k < 18) b = spa[8*(17-k) +: 8];
        else if (k < 24) b = tha[8*(23-k) +: 8];
        else if (k < 28) b = tpa[8*(27-k) +: 8];
        else             b = 8'h00;
        case (bad_kind)
            1: if (k == 1) b = 8'h02;
            2: if (k == 2) b = 8'h86;
            3: if (k == 4) b = 8'd7;
            4: if (k == 5) b = 8'd6;
            5: if (k == 7) b = 8'h03;
            default: ;
        endcase
        return b;
    endfunction

    //----------------------------------------------------------------
    // Driver and scoreboard model. user_beat injects tuser on that
    // frame byte (-1 for none): on a payload byte (14 and up) it must
    // void reply and learn, on an Ethernet header byte (below 14) the
    // parser swallows it and nothing may change.
    //----------------------------------------------------------------
    task automatic send_arp(input logic [47:0] eth_dst, input logic [7:0] oper,
                            input logic [47:0] sha, input logic [31:0] spa,
                            input logic [31:0] tpa, input integer pay_len,
                            input integer bad_kind, input integer user_beat);
        logic [7:0]   b;
        logic         last, user;
        logic         valid;
        logic [335:0] rv;
        integer       total;

        valid = bad_kind == 0 && pay_len >= 28
             && !(user_beat >= 14 && user_beat < 14 + pay_len)
             && tpa == LOCAL_IP && (oper == 8'h01 || oper == 8'h02);

        if (valid) begin
            exp_learn[exp_learn_count] = {sha, spa};
            exp_learn_count = exp_learn_count + 1;
            if (oper == 8'h01) begin
                rv = {sha, LOCAL_MAC, 16'h0806,
                      16'h0001, 16'h0800, 8'd6, 8'd4, 16'h0002,
                      LOCAL_MAC, LOCAL_IP, sha, spa};
                for (int k = 0; k < 42; k++) begin
                    exp_r[exp_r_count] = {k == 41, 1'b0, rv[8*(41-k) +: 8]};
                    exp_r_count = exp_r_count + 1;
                end
            end
        end

        total    = 14 + pay_len;
        s_length = 12'(total);

        for (int k = 0; k < total; k++) begin
            if (k < 14) begin
                b = eth_byte(eth_dst, sha, 16'h0806, k);
            end
            else begin
                b = arp_byte(oper, sha, spa, REMOTE_MAC, tpa, bad_kind, k - 14);
            end
            last = (k == total - 1);
            user = k == user_beat;
            @(negedge clock);
            s_tvalid = 1'b1;
            s_tdata  = b;
            s_tlast  = last;
            s_tuser  = user;
            #1;
            while (s_tready !== 1'b1) begin
                @(negedge clock);
                #1;
            end
            @(posedge clock);
        end
        s_tvalid <= 1'b0;
        s_tlast  <= 1'b0;
        s_tuser  <= 1'b0;
    endtask

    //----------------------------------------------------------------
    // Test sequence
    //----------------------------------------------------------------
    logic [47:0] soak_sha;
    logic [31:0] soak_spa;
    logic [31:0] soak_tpa;
    logic [7:0]  soak_oper;
    integer      soak_bad;
    integer      soak_len;
    integer      soak_user;

    initial begin
        s_tvalid = 1'b0; s_tdata = '0; s_tlast = 1'b0; s_tuser = 1'b0;
        s_length = '0;

        wait (sreset === 1'b0);
        @(posedge clock);

        // Valid requests: broadcast padded, unicast bare 28 bytes
        send_arp(BCAST_MAC, 8'h01, REMOTE_MAC, REMOTE_IP, LOCAL_IP, 46, 0, -1);
        send_arp(LOCAL_MAC, 8'h01, REMOTE_MAC, REMOTE_IP, LOCAL_IP, 28, 0, -1);

        // A valid ARP reply to us: learn only, no frame back
        send_arp(LOCAL_MAC, 8'h02, REMOTE_MAC, REMOTE_IP, LOCAL_IP, 46, 0, -1);

        // Rejections: wrong target IP, each corrupted field, a short
        // payload, and a tuser-marked frame
        send_arp(BCAST_MAC, 8'h01, REMOTE_MAC, REMOTE_IP, REMOTE_IP, 46, 0, -1);
        send_arp(BCAST_MAC, 8'h01, REMOTE_MAC, REMOTE_IP, LOCAL_IP, 46, 1, -1);
        send_arp(BCAST_MAC, 8'h01, REMOTE_MAC, REMOTE_IP, LOCAL_IP, 46, 2, -1);
        send_arp(BCAST_MAC, 8'h01, REMOTE_MAC, REMOTE_IP, LOCAL_IP, 46, 3, -1);
        send_arp(BCAST_MAC, 8'h01, REMOTE_MAC, REMOTE_IP, LOCAL_IP, 46, 4, -1);
        send_arp(BCAST_MAC, 8'h01, REMOTE_MAC, REMOTE_IP, LOCAL_IP, 46, 5, -1);
        send_arp(BCAST_MAC, 8'h01, REMOTE_MAC, REMOTE_IP, LOCAL_IP, 20, 0, -1);
        send_arp(BCAST_MAC, 8'h01, REMOTE_MAC, REMOTE_IP, LOCAL_IP, 46, 0, 31);

        // tuser on an Ethernet header byte: the parser swallows it,
        // the request must still be answered
        send_arp(BCAST_MAC, 8'h01, REMOTE_MAC, REMOTE_IP, LOCAL_IP, 46, 0, 13);

        // Back-to-back requests: the input must stall while each
        // reply drains, and every request must still be answered
        send_arp(BCAST_MAC, 8'h01, 48'h02_00_00_00_00_01, 32'h0A_00_00_01, LOCAL_IP, 28, 0, -1);
        send_arp(BCAST_MAC, 8'h01, 48'h02_00_00_00_00_02, 32'h0A_00_00_02, LOCAL_IP, 28, 0, -1);
        send_arp(BCAST_MAC, 8'h01, 48'h02_00_00_00_00_03, 32'h0A_00_00_03, LOCAL_IP, 28, 0, -1);

        // Random soak
        for (int f = 0; f < 40; f++) begin
            soak_sha  = {8'h02, 8'($urandom), $urandom};
            soak_spa  = $urandom;
            soak_tpa  = $urandom_range(0, 2) != 0 ? LOCAL_IP : REMOTE_IP;
            soak_oper = $urandom_range(0, 3) != 0 ? 8'h01 : 8'h02;
            soak_bad  = $urandom_range(0, 7) == 0 ? $urandom_range(1, 5) : 0;
            soak_user = $urandom_range(0, 9) == 0 ? $urandom_range(0, 41) : -1;
            case ($urandom_range(0, 2))
                0: soak_len = 28;
                1: soak_len = 46;
                default: soak_len = $urandom_range(20, 46);
            endcase
            send_arp($urandom_range(0, 1) == 0 ? BCAST_MAC : LOCAL_MAC,
                     soak_oper, soak_sha, soak_spa, soak_tpa,
                     soak_len, soak_bad, soak_user);
            repeat ($urandom_range(0, 2)) @(posedge clock);
        end
        repeat (200) @(posedge clock);

        if (r_mon_idx != exp_r_count) begin
            errors = errors + 1;
            $error("reply stream incomplete: %0d/%0d beats", r_mon_idx, exp_r_count);
        end
        if (learn_idx != exp_learn_count) begin
            errors = errors + 1;
            $error("learn pulses incomplete: %0d/%0d", learn_idx, exp_learn_count);
        end

        if (errors == 0)
          $display("axi_stream_eth_arp_tb: ALL TESTS PASSED");
        else
          $display("axi_stream_eth_arp_tb: %0d ERROR(S)", errors);
        $finish;
    end

    // Watchdog: a reply that never drains stalls the driver forever
    initial begin
        #800000;
        errors = errors + 1;
        $error("watchdog: reply %0d/%0d learn %0d/%0d",
               r_mon_idx, exp_r_count, learn_idx, exp_learn_count);
        $display("axi_stream_eth_arp_tb: %0d ERROR(S)", errors);
        $finish;
    end

    //----------------------------------------------------------------
    // Monitors
    //----------------------------------------------------------------
    initial begin
        exp_r_count = 0; r_mon_idx = 0;
        exp_learn_count = 0; learn_idx = 0;
    end

    always @(posedge clock) begin
        if (sreset === 1'b0 && r_tvalid === 1'b1 && r_tready === 1'b1) begin
            if (r_mon_idx >= exp_r_count) begin
                errors = errors + 1;
                $error("reply: unexpected beat %02x", r_tdata);
            end
            else if ({r_tlast, r_tuser, r_tdata} !== exp_r[r_mon_idx]) begin
                errors = errors + 1;
                $error("reply beat %0d: got last=%b user=%b data=%02x",
                       r_mon_idx, r_tlast, r_tuser, r_tdata);
            end
            r_mon_idx = r_mon_idx + 1;
        end
    end

    always @(posedge clock) begin
        if (sreset === 1'b0 && learn_valid === 1'b1) begin
            if (learn_idx >= exp_learn_count) begin
                errors = errors + 1;
                $error("learn: unexpected pulse mac=%012x ip=%08x", learn_mac, learn_ip);
            end
            else if ({learn_mac, learn_ip} !== exp_learn[learn_idx]) begin
                errors = errors + 1;
                $error("learn %0d: got mac=%012x ip=%08x", learn_idx, learn_mac, learn_ip);
            end
            learn_idx = learn_idx + 1;
        end
    end

    // The IPv4 demux output must never see a beat
    always @(posedge clock) begin
        if (sreset === 1'b0 && d_tvalid[0] === 1'b1) begin
            errors = errors + 1;
            $error("ipv4 output: unexpected beat %02x", d_tdata[7:0]);
        end
    end

endmodule
