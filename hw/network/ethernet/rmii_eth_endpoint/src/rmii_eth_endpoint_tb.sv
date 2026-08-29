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
// Title         : RMII Ethernet Endpoint Testbench
//-----------------------------------------------------------------------------
// File          : rmii_eth_endpoint_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-29
// Last modified : 2026-08-29
//-----------------------------------------------------------------------------
// Description :
// Wire-level testbench of the whole endpoint: complete Ethernet frames
// -- preamble, SFD, payload, real FCS -- are driven onto the RMII
// receive pins at line rate, and the transmit pins are captured dibit
// by dibit, preamble and inter-frame gap verified, and compared
// byte-exact against expected reply frames, FCS included. ARP requests
// and pings for the local IP must be answered; wrong MAC, wrong IP,
// wrong EtherType, wrong protocol, non-echo ICMP, broadcast pings, a
// corrupted FCS and a frame cut mid-air must produce silence. Two
// endpoints share the receive wire: a default-parameter one and a
// small sweep instance with its own identity, whose tiny ICMP buffer
// also turns the large ping into a drop. A back-to-back burst checks
// replies come out in order across the reply-drain stall.

`timescale 1 ns / 100 ps

module rmii_eth_endpoint_tb;

    localparam logic [47:0] LOCAL_MAC  = 48'h02_12_34_56_78_9A;
    localparam logic [31:0] LOCAL_IP   = 32'hC0_A8_01_2A;
    localparam logic [47:0] P1_MAC     = 48'h02_12_34_56_78_9B;
    localparam logic [31:0] P1_IP      = 32'hC0_A8_01_2B;
    localparam logic [47:0] REQ_MAC    = 48'h02_AB_CD_EF_01_23;
    localparam logic [31:0] REQ_IP     = 32'hC0_A8_01_63;
    localparam logic [47:0] BCAST_MAC  = 48'hFF_FF_FF_FF_FF_FF;
    localparam logic [31:0] BCAST_IP   = 32'hFF_FF_FF_FF;
    localparam logic [47:0] OTHER_MAC  = 48'h02_00_00_00_BE_EF;

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
    // Two endpoints on one receive wire, each with its own transmit
    //----------------------------------------------------------------
    logic [1:0] rxd;
    logic       rxen;

    logic [1:0]  txd;
    logic        txen;
    logic        learn_valid;
    logic [47:0] learn_mac;
    logic [31:0] learn_ip;

    logic [1:0]  p1_txd;
    logic        p1_txen;
    logic        p1_learn_valid;
    logic [47:0] p1_learn_mac;
    logic [31:0] p1_learn_ip;

    rmii_eth_endpoint
    #(
        .LOG2_FIFO_DEPTH (11),
        .LOG2_ICMP_DEPTH (11)
    )
    rmii_eth_endpoint_inst
    (
        .clock       (clock),
        .sreset      (sreset),
        .local_mac   (LOCAL_MAC),
        .local_ip    (LOCAL_IP),
        .phy_rxd     (rxd),
        .phy_crs_dv  (rxen),
        .phy_txd     (txd),
        .phy_txen    (txen),
        .learn_valid (learn_valid),
        .learn_mac   (learn_mac),
        .learn_ip    (learn_ip)
    );

    rmii_eth_endpoint
    #(
        .LOG2_FIFO_DEPTH (8),
        .LOG2_ICMP_DEPTH (4)
    )
    rmii_eth_endpoint_p1_inst
    (
        .clock       (clock),
        .sreset      (sreset),
        .local_mac   (P1_MAC),
        .local_ip    (P1_IP),
        .phy_rxd     (rxd),
        .phy_crs_dv  (rxen),
        .phy_txd     (p1_txd),
        .phy_txen    (p1_txen),
        .learn_valid (p1_learn_valid),
        .learn_mac   (p1_learn_mac),
        .learn_ip    (p1_learn_ip)
    );

    //----------------------------------------------------------------
    // Frame under construction, shared by drivers and expectations
    //----------------------------------------------------------------
    logic [7:0] fr [0:2047];  // frame bytes, FCS included once appended
    integer     fr_len;       // bytes built so far

    // Reflected CRC-32, one byte: matches the Ethernet FCS
    function automatic logic [31:0] crc_step(input logic [31:0] crc, input logic [7:0] b);
        logic [31:0] c;
        c = crc ^ 32'(b);
        for (int i = 0; i < 8; i++) begin
            c = c[0] ? {1'b0, c[31:1]} ^ 32'hEDB8_8320 : {1'b0, c[31:1]};
        end
        return c;
    endfunction

    // Ones-complement checksum fold of a 32-bit accumulator
    function automatic logic [15:0] csum_fold(input logic [31:0] sum);
        logic [31:0] s;
        s = sum;
        while (s[31:16] != 16'h0000) begin
            s = 32'(s[15:0]) + 32'(s[31:16]);
        end
        return ~s[15:0];
    endfunction

    // ICMP data pattern shared by builders on both sides
    function automatic logic [7:0] icmp_data(input logic [7:0] base, input integer k);
        return 8'(base + k);
    endfunction

    task automatic append_fcs;
        logic [31:0] crc;
        crc = 32'hFFFF_FFFF;
        for (int i = 0; i < fr_len; i++) begin
            crc = crc_step(crc, fr[i]);
        end
        crc = ~crc;
        for (int i = 0; i < 4; i++) begin
            fr[fr_len] = crc[8*i +: 8];
            fr_len = fr_len + 1;
        end
    endtask

    task automatic pad_to(input integer nbytes);
        while (fr_len < nbytes) begin
            fr[fr_len] = 8'h00;
            fr_len = fr_len + 1;
        end
    endtask

    task automatic build_eth(input logic [47:0] dst, input logic [47:0] src,
                             input logic [15:0] ethertype);
        fr_len = 0;
        for (int i = 5; i >= 0; i--) begin fr[fr_len] = dst[8*i +: 8]; fr_len++; end
        for (int i = 5; i >= 0; i--) begin fr[fr_len] = src[8*i +: 8]; fr_len++; end
        fr[fr_len] = ethertype[15:8]; fr_len++;
        fr[fr_len] = ethertype[7:0];  fr_len++;
    endtask

    task automatic build_arp(input logic [7:0] oper, input logic [47:0] sha,
                             input logic [31:0] spa, input logic [47:0] tha,
                             input logic [31:0] tpa);
        fr[fr_len] = 8'h00; fr_len++; fr[fr_len] = 8'h01; fr_len++;
        fr[fr_len] = 8'h08; fr_len++; fr[fr_len] = 8'h00; fr_len++;
        fr[fr_len] = 8'h06; fr_len++; fr[fr_len] = 8'h04; fr_len++;
        fr[fr_len] = 8'h00; fr_len++; fr[fr_len] = oper;  fr_len++;
        for (int i = 5; i >= 0; i--) begin fr[fr_len] = sha[8*i +: 8]; fr_len++; end
        for (int i = 3; i >= 0; i--) begin fr[fr_len] = spa[8*i +: 8]; fr_len++; end
        for (int i = 5; i >= 0; i--) begin fr[fr_len] = tha[8*i +: 8]; fr_len++; end
        for (int i = 3; i >= 0; i--) begin fr[fr_len] = tpa[8*i +: 8]; fr_len++; end
    endtask

    // IPv4 header plus ICMP, both checksums real; the DUT's reply
    // (id 0, DF, TTL 64) is built with the same task, type 0: a full
    // recomputation equals the RFC 1624 adjust of a correct request
    task automatic build_ipv4_icmp(input logic [31:0] src, input logic [31:0] dst,
                                   input logic [15:0] ident, input logic df,
                                   input logic [7:0] proto, input logic [7:0] icmp_type,
                                   input logic [7:0] icmp_code, input integer l4_len,
                                   input logic [7:0] base);
        logic [15:0] total;
        logic [31:0] sum;
        logic [15:0] ip_csum, ic_csum;
        logic [7:0]  b0, b1;
        integer      hdr0;

        hdr0  = fr_len;
        total = 16'(20 + l4_len);

        sum = 32'(16'h4500) + 32'(total) + 32'(ident)
            + 32'({1'b0, df, 14'h0000}) + 32'({8'd64, proto})
            + 32'(src[31:16]) + 32'(src[15:0])
            + 32'(dst[31:16]) + 32'(dst[15:0]);
        ip_csum = csum_fold(sum);

        sum = 32'({icmp_type, icmp_code});
        for (int k = 4; k < l4_len; k += 2) begin
            b0 = icmp_data(base, k);
            b1 = (k + 1 < l4_len) ? icmp_data(base, k + 1) : 8'h00;
            sum = sum + 32'({b0, b1});
        end
        ic_csum = csum_fold(sum);

        fr[fr_len] = 8'h45;         fr_len++; fr[fr_len] = 8'h00;        fr_len++;
        fr[fr_len] = total[15:8];   fr_len++; fr[fr_len] = total[7:0];   fr_len++;
        fr[fr_len] = ident[15:8];   fr_len++; fr[fr_len] = ident[7:0];   fr_len++;
        fr[fr_len] = {1'b0, df, 6'h00}; fr_len++; fr[fr_len] = 8'h00;    fr_len++;
        fr[fr_len] = 8'd64;         fr_len++; fr[fr_len] = proto;        fr_len++;
        fr[fr_len] = ip_csum[15:8]; fr_len++; fr[fr_len] = ip_csum[7:0]; fr_len++;
        for (int i = 3; i >= 0; i--) begin fr[fr_len] = src[8*i +: 8]; fr_len++; end
        for (int i = 3; i >= 0; i--) begin fr[fr_len] = dst[8*i +: 8]; fr_len++; end
        fr[fr_len] = icmp_type;     fr_len++; fr[fr_len] = icmp_code;    fr_len++;
        fr[fr_len] = ic_csum[15:8]; fr_len++; fr[fr_len] = ic_csum[7:0]; fr_len++;
        for (int k = 4; k < l4_len; k++) begin
            fr[fr_len] = icmp_data(base, k);
            fr_len++;
        end
        if (hdr0 != fr_len - 20 - l4_len) begin
            errors = errors + 1;
            $error("builder length bug: %0d bytes emitted", fr_len - hdr0);
        end
    endtask

    //----------------------------------------------------------------
    // Expected reply queues, one per endpoint
    //----------------------------------------------------------------
    logic [7:0] exp_b [0:8191];     // main: concatenated reply bytes
    integer     exp_flen [0:63];    // main: per-frame lengths
    integer     exp_nf, exp_nb;     // main: frames and bytes pushed

    logic [7:0] p1_exp_b [0:2047];  // sweep: concatenated reply bytes
    integer     p1_exp_flen [0:63]; // sweep: per-frame lengths
    integer     p1_exp_nf, p1_exp_nb;

    // Push the frame under construction as an expected reply
    task automatic expect_fr(input logic p1);
        for (int i = 0; i < fr_len; i++) begin
            if (p1) begin
                p1_exp_b[p1_exp_nb] = fr[i];
                p1_exp_nb = p1_exp_nb + 1;
            end
            else begin
                exp_b[exp_nb] = fr[i];
                exp_nb = exp_nb + 1;
            end
        end
        if (p1) begin
            p1_exp_flen[p1_exp_nf] = fr_len;
            p1_exp_nf = p1_exp_nf + 1;
        end
        else begin
            exp_flen[exp_nf] = fr_len;
            exp_nf = exp_nf + 1;
        end
    endtask

    //----------------------------------------------------------------
    // Wire driver: preamble, SFD, then the frame, one dibit per clock
    //----------------------------------------------------------------
    task automatic send_wire(input integer cut_at);
        logic [7:0] b;
        @(negedge clock);
        rxen = 1'b1;
        for (int p = 0; p < 8; p++) begin
            b = (p == 7) ? 8'hD5 : 8'h55;
            for (int d = 0; d < 4; d++) begin
                rxd = b[2*d +: 2];
                @(negedge clock);
            end
        end
        for (int i = 0; i < fr_len; i++) begin
            if (cut_at >= 0 && i == cut_at) begin
                break;
            end
            for (int d = 0; d < 4; d++) begin
                rxd = fr[i][2*d +: 2];
                @(negedge clock);
            end
        end
        rxen = 1'b0;
        rxd  = 2'b00;
        // The wire inter-frame gap, 96 bit times
        repeat (48) @(negedge clock);
    endtask

    //----------------------------------------------------------------
    // Transmit monitors: collect dibits, verify preamble and IFG,
    // compare each frame byte-exact against the expected queue
    //----------------------------------------------------------------
    logic [1:0] mon_d [0:8191];  // main: captured dibits of the frame
    integer     mon_nd;          // main: dibits captured
    integer     mon_frames;      // main: frames checked
    integer     mon_boff;        // main: read offset in exp_b
    logic       mon_active;      // main: txen seen high
    integer     mon_gap;         // main: clocks since txen fell

    logic [1:0] p1_mon_d [0:8191];
    integer     p1_mon_nd;
    integer     p1_mon_frames;
    integer     p1_mon_boff;
    logic       p1_mon_active;
    integer     p1_mon_gap;

    task automatic check_frame(input logic p1);
        integer     nd, nb, flen, boff;
        logic [7:0] b;
        nd = p1 ? p1_mon_nd : mon_nd;

        // 32 preamble dibits: 31 times "01" then the SFD end "11"
        if (nd < 32) begin
            errors = errors + 1;
            $error("%s: burst of %0d dibits, no room for a preamble", p1 ? "p1" : "main", nd);
            return;
        end
        for (int i = 0; i < 31; i++) begin
            if ((p1 ? p1_mon_d[i] : mon_d[i]) !== 2'b01) begin
                errors = errors + 1;
                $error("%s: preamble dibit %0d is %b", p1 ? "p1" : "main", i,
                       p1 ? p1_mon_d[i] : mon_d[i]);
                return;
            end
        end
        if ((p1 ? p1_mon_d[31] : mon_d[31]) !== 2'b11) begin
            errors = errors + 1;
            $error("%s: SFD dibit is %b", p1 ? "p1" : "main", p1 ? p1_mon_d[31] : mon_d[31]);
            return;
        end

        if ((nd - 32) % 4 != 0) begin
            errors = errors + 1;
            $error("%s: %0d payload dibits, not whole bytes", p1 ? "p1" : "main", nd - 32);
            return;
        end
        nb = (nd - 32) / 4;

        if ((p1 ? p1_mon_frames : mon_frames) >= (p1 ? p1_exp_nf : exp_nf)) begin
            errors = errors + 1;
            $error("%s: unexpected frame of %0d bytes", p1 ? "p1" : "main", nb);
            return;
        end
        flen = p1 ? p1_exp_flen[p1_mon_frames] : exp_flen[mon_frames];
        boff = p1 ? p1_mon_boff : mon_boff;
        if (nb != flen) begin
            errors = errors + 1;
            $error("%s: frame %0d is %0d bytes, expected %0d",
                   p1 ? "p1" : "main", p1 ? p1_mon_frames : mon_frames, nb, flen);
        end
        for (int i = 0; i < nb && i < flen; i++) begin
            b = {(p1 ? p1_mon_d[32 + 4*i + 3] : mon_d[32 + 4*i + 3]),
                 (p1 ? p1_mon_d[32 + 4*i + 2] : mon_d[32 + 4*i + 2]),
                 (p1 ? p1_mon_d[32 + 4*i + 1] : mon_d[32 + 4*i + 1]),
                 (p1 ? p1_mon_d[32 + 4*i + 0] : mon_d[32 + 4*i + 0])};
            if (b !== (p1 ? p1_exp_b[boff + i] : exp_b[boff + i])) begin
                errors = errors + 1;
                $error("%s: frame %0d byte %0d is %02x, expected %02x",
                       p1 ? "p1" : "main", p1 ? p1_mon_frames : mon_frames, i, b,
                       p1 ? p1_exp_b[boff + i] : exp_b[boff + i]);
            end
        end
        if (p1) begin
            p1_mon_boff   = p1_mon_boff + flen;
            p1_mon_frames = p1_mon_frames + 1;
        end
        else begin
            mon_boff   = mon_boff + flen;
            mon_frames = mon_frames + 1;
        end
    endtask

    always @(posedge clock) begin
        if (sreset === 1'b1) begin
            mon_nd = 0; mon_active = 1'b0; mon_gap = 1000;
        end
        else if (txen === 1'b1) begin
            if (!mon_active && mon_frames > 0 && mon_gap < 48) begin
                errors = errors + 1;
                $error("main: inter-frame gap of %0d clocks", mon_gap);
            end
            mon_d[mon_nd] = txd;
            mon_nd = mon_nd + 1;
            mon_active = 1'b1;
        end
        else begin
            if (mon_active) begin
                check_frame(1'b0);
                mon_nd  = 0;
                mon_gap = 0;
            end
            else if (mon_gap < 1000) begin
                mon_gap = mon_gap + 1;
            end
            mon_active = 1'b0;
        end
    end

    always @(posedge clock) begin
        if (sreset === 1'b1) begin
            p1_mon_nd = 0; p1_mon_active = 1'b0; p1_mon_gap = 1000;
        end
        else if (p1_txen === 1'b1) begin
            if (!p1_mon_active && p1_mon_frames > 0 && p1_mon_gap < 48) begin
                errors = errors + 1;
                $error("p1: inter-frame gap of %0d clocks", p1_mon_gap);
            end
            p1_mon_d[p1_mon_nd] = p1_txd;
            p1_mon_nd = p1_mon_nd + 1;
            p1_mon_active = 1'b1;
        end
        else begin
            if (p1_mon_active) begin
                check_frame(1'b1);
                p1_mon_nd  = 0;
                p1_mon_gap = 0;
            end
            else if (p1_mon_gap < 1000) begin
                p1_mon_gap = p1_mon_gap + 1;
            end
            p1_mon_active = 1'b0;
        end
    end

    //----------------------------------------------------------------
    // Learn pulse monitors
    //----------------------------------------------------------------
    integer      learn_count;
    logic [47:0] learn_mac_seen;  // latest learned mapping
    logic [31:0] learn_ip_seen;
    integer      p1_learn_count;

    always @(posedge clock) begin
        if (learn_valid === 1'b1) begin
            learn_count    = learn_count + 1;
            learn_mac_seen = learn_mac;
            learn_ip_seen  = learn_ip;
        end
        if (p1_learn_valid === 1'b1) begin
            p1_learn_count = p1_learn_count + 1;
        end
    end

    //----------------------------------------------------------------
    // Reply waits, bounded
    //----------------------------------------------------------------
    task automatic wait_main(input integer target);
        integer waited;
        waited = 0;
        while (mon_frames < target && waited < 20000) begin
            @(posedge clock);
            waited = waited + 1;
        end
        if (mon_frames < target) begin
            errors = errors + 1;
            $error("main: reply %0d never came", target);
        end
    endtask

    task automatic wait_p1(input integer target);
        integer waited;
        waited = 0;
        while (p1_mon_frames < target && waited < 20000) begin
            @(posedge clock);
            waited = waited + 1;
        end
        if (p1_mon_frames < target) begin
            errors = errors + 1;
            $error("p1: reply %0d never came", target);
        end
    endtask

    //----------------------------------------------------------------
    // Test sequence
    //----------------------------------------------------------------
    initial begin
        rxd  = 2'b00;
        rxen = 1'b0;
        exp_nf = 0; exp_nb = 0; mon_frames = 0; mon_boff = 0;
        p1_exp_nf = 0; p1_exp_nb = 0; p1_mon_frames = 0; p1_mon_boff = 0;
        learn_count = 0; p1_learn_count = 0;

        wait (sreset === 1'b0);
        repeat (10) @(posedge clock);

        // ARP request for the main endpoint: reply plus a learn pulse
        build_eth(REQ_MAC, LOCAL_MAC, 16'h0806);
        build_arp(8'h02, LOCAL_MAC, LOCAL_IP, REQ_MAC, REQ_IP);
        pad_to(60);
        append_fcs;
        expect_fr(1'b0);
        build_eth(BCAST_MAC, REQ_MAC, 16'h0806);
        build_arp(8'h01, REQ_MAC, REQ_IP, 48'h00_00_00_00_00_00, LOCAL_IP);
        pad_to(60);
        append_fcs;
        send_wire(-1);
        wait_main(1);
        if (learn_count != 1 || learn_mac_seen !== REQ_MAC || learn_ip_seen !== REQ_IP) begin
            errors = errors + 1;
            $error("learn: count %0d mac %012x ip %08x", learn_count, learn_mac_seen, learn_ip_seen);
        end

        // ARP request for the sweep endpoint: only it answers
        build_eth(REQ_MAC, P1_MAC, 16'h0806);
        build_arp(8'h02, P1_MAC, P1_IP, REQ_MAC, REQ_IP);
        pad_to(60);
        append_fcs;
        expect_fr(1'b1);
        build_eth(BCAST_MAC, REQ_MAC, 16'h0806);
        build_arp(8'h01, REQ_MAC, REQ_IP, 48'h00_00_00_00_00_00, P1_IP);
        pad_to(60);
        append_fcs;
        send_wire(-1);
        wait_p1(1);

        // Pings: a 32-byte-data one, the 8-byte minimum, and a large
        // one the sweep instance's 16-byte ICMP buffer cannot hold
        build_eth(REQ_MAC, LOCAL_MAC, 16'h0800);
        build_ipv4_icmp(LOCAL_IP, REQ_IP, 16'h0000, 1'b1, 8'h01, 8'h00, 8'h00, 40, 8'h50);
        pad_to(60);
        append_fcs;
        expect_fr(1'b0);
        build_eth(LOCAL_MAC, REQ_MAC, 16'h0800);
        build_ipv4_icmp(REQ_IP, LOCAL_IP, 16'h5678, 1'b0, 8'h01, 8'h08, 8'h00, 40, 8'h50);
        pad_to(60);
        append_fcs;
        send_wire(-1);
        wait_main(2);

        build_eth(REQ_MAC, LOCAL_MAC, 16'h0800);
        build_ipv4_icmp(LOCAL_IP, REQ_IP, 16'h0000, 1'b1, 8'h01, 8'h00, 8'h00, 8, 8'h60);
        pad_to(60);
        append_fcs;
        expect_fr(1'b0);
        build_eth(LOCAL_MAC, REQ_MAC, 16'h0800);
        build_ipv4_icmp(REQ_IP, LOCAL_IP, 16'h0001, 1'b0, 8'h01, 8'h08, 8'h00, 8, 8'h60);
        pad_to(60);
        append_fcs;
        send_wire(-1);
        wait_main(3);

        // The large ping answered by the main endpoint; the same bytes
        // reach the sweep instance addressed to it right after, and
        // its LOG2_ICMP_DEPTH=4 buffer drops the 200-byte payload
        build_eth(REQ_MAC, LOCAL_MAC, 16'h0800);
        build_ipv4_icmp(LOCAL_IP, REQ_IP, 16'h0000, 1'b1, 8'h01, 8'h00, 8'h00, 200, 8'h70);
        append_fcs;
        expect_fr(1'b0);
        build_eth(LOCAL_MAC, REQ_MAC, 16'h0800);
        build_ipv4_icmp(REQ_IP, LOCAL_IP, 16'h0002, 1'b0, 8'h01, 8'h08, 8'h00, 200, 8'h70);
        append_fcs;
        send_wire(-1);
        wait_main(4);
        build_eth(P1_MAC, REQ_MAC, 16'h0800);
        build_ipv4_icmp(REQ_IP, P1_IP, 16'h0003, 1'b0, 8'h01, 8'h08, 8'h00, 200, 8'h71);
        append_fcs;
        send_wire(-1);

        // Silence: wrong destination MAC, wrong destination IP, IPv6
        // EtherType, UDP protocol, echo reply type, broadcast ping,
        // corrupted FCS, and a frame cut on the wire
        build_eth(OTHER_MAC, REQ_MAC, 16'h0800);
        build_ipv4_icmp(REQ_IP, LOCAL_IP, 16'h0004, 1'b0, 8'h01, 8'h08, 8'h00, 12, 8'h80);
        pad_to(60);
        append_fcs;
        send_wire(-1);
        build_eth(LOCAL_MAC, REQ_MAC, 16'h0800);
        build_ipv4_icmp(REQ_IP, REQ_IP, 16'h0005, 1'b0, 8'h01, 8'h08, 8'h00, 12, 8'h81);
        pad_to(60);
        append_fcs;
        send_wire(-1);
        build_eth(LOCAL_MAC, REQ_MAC, 16'h86DD);
        build_ipv4_icmp(REQ_IP, LOCAL_IP, 16'h0006, 1'b0, 8'h01, 8'h08, 8'h00, 12, 8'h82);
        pad_to(60);
        append_fcs;
        send_wire(-1);
        build_eth(LOCAL_MAC, REQ_MAC, 16'h0800);
        build_ipv4_icmp(REQ_IP, LOCAL_IP, 16'h0007, 1'b0, 8'h11, 8'h08, 8'h00, 12, 8'h83);
        pad_to(60);
        append_fcs;
        send_wire(-1);
        build_eth(LOCAL_MAC, REQ_MAC, 16'h0800);
        build_ipv4_icmp(REQ_IP, LOCAL_IP, 16'h0008, 1'b0, 8'h01, 8'h00, 8'h00, 12, 8'h84);
        pad_to(60);
        append_fcs;
        send_wire(-1);
        build_eth(BCAST_MAC, REQ_MAC, 16'h0800);
        build_ipv4_icmp(REQ_IP, BCAST_IP, 16'h0009, 1'b0, 8'h01, 8'h08, 8'h00, 12, 8'h85);
        pad_to(60);
        append_fcs;
        send_wire(-1);
        build_eth(LOCAL_MAC, REQ_MAC, 16'h0800);
        build_ipv4_icmp(REQ_IP, LOCAL_IP, 16'h000A, 1'b0, 8'h01, 8'h08, 8'h00, 12, 8'h86);
        pad_to(60);
        append_fcs;
        fr[fr_len-1] = fr[fr_len-1] ^ 8'h01;
        send_wire(-1);
        build_eth(LOCAL_MAC, REQ_MAC, 16'h0800);
        build_ipv4_icmp(REQ_IP, LOCAL_IP, 16'h000B, 1'b0, 8'h01, 8'h08, 8'h00, 12, 8'h87);
        pad_to(60);
        append_fcs;
        send_wire(30);

        // An ARP for a foreign IP: no reply, no learn either
        build_eth(BCAST_MAC, REQ_MAC, 16'h0806);
        build_arp(8'h01, REQ_MAC, REQ_IP, 48'h00_00_00_00_00_00, REQ_IP);
        pad_to(60);
        append_fcs;
        send_wire(-1);

        // Back-to-back burst at minimum gap: an ARP request and two
        // pings; the replies drain across the head-of-line stall the
        // FIFO absorbs, and must come out in order with a legal IFG
        build_eth(REQ_MAC, LOCAL_MAC, 16'h0806);
        build_arp(8'h02, LOCAL_MAC, LOCAL_IP, REQ_MAC, REQ_IP);
        pad_to(60);
        append_fcs;
        expect_fr(1'b0);
        build_eth(REQ_MAC, LOCAL_MAC, 16'h0800);
        build_ipv4_icmp(LOCAL_IP, REQ_IP, 16'h0000, 1'b1, 8'h01, 8'h00, 8'h00, 24, 8'h90);
        pad_to(60);
        append_fcs;
        expect_fr(1'b0);
        build_eth(REQ_MAC, LOCAL_MAC, 16'h0800);
        build_ipv4_icmp(LOCAL_IP, REQ_IP, 16'h0000, 1'b1, 8'h01, 8'h00, 8'h00, 16, 8'hA0);
        pad_to(60);
        append_fcs;
        expect_fr(1'b0);

        build_eth(BCAST_MAC, REQ_MAC, 16'h0806);
        build_arp(8'h01, REQ_MAC, REQ_IP, 48'h00_00_00_00_00_00, LOCAL_IP);
        pad_to(60);
        append_fcs;
        send_wire(-1);
        build_eth(LOCAL_MAC, REQ_MAC, 16'h0800);
        build_ipv4_icmp(REQ_IP, LOCAL_IP, 16'h000C, 1'b0, 8'h01, 8'h08, 8'h00, 24, 8'h90);
        pad_to(60);
        append_fcs;
        send_wire(-1);
        build_eth(LOCAL_MAC, REQ_MAC, 16'h0800);
        build_ipv4_icmp(REQ_IP, LOCAL_IP, 16'h000D, 1'b0, 8'h01, 8'h08, 8'h00, 16, 8'hA0);
        pad_to(60);
        append_fcs;
        send_wire(-1);
        wait_main(7);

        // Let any wrong extra reply surface, then the verdict
        repeat (2000) @(posedge clock);

        if (mon_frames != exp_nf) begin
            errors = errors + 1;
            $error("main: %0d/%0d replies", mon_frames, exp_nf);
        end
        if (p1_mon_frames != p1_exp_nf) begin
            errors = errors + 1;
            $error("p1: %0d/%0d replies", p1_mon_frames, p1_exp_nf);
        end
        if (learn_count != 2) begin
            errors = errors + 1;
            $error("main learn: %0d pulses, expected 2", learn_count);
        end
        if (p1_learn_count != 1) begin
            errors = errors + 1;
            $error("p1 learn: %0d pulses", p1_learn_count);
        end

        if (errors == 0)
          $display("rmii_eth_endpoint_tb: ALL TESTS PASSED");
        else
          $display("rmii_eth_endpoint_tb: %0d ERROR(S)", errors);
        $finish;
    end

    // Watchdog: a lost reply stalls a bounded wait, not the bench
    initial begin
        #2000000;
        errors = errors + 1;
        $error("watchdog: main %0d/%0d p1 %0d/%0d",
               mon_frames, exp_nf, p1_mon_frames, p1_exp_nf);
        $display("rmii_eth_endpoint_tb: %0d ERROR(S)", errors);
        $finish;
    end

endmodule
