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
// Title         : AXI Stream ICMP Echo Responder Testbench
//-----------------------------------------------------------------------------
// File          : axi_stream_icmp_echo_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-28
// Last modified : 2026-08-28
//-----------------------------------------------------------------------------
// Description :
// Testbench of the ICMP echo responder behind its documented chain:
// IPv4 frames enter the IPv4 parser, the packet demux routes protocol
// 1 to the responder, and every valid echo request -- minimum 8
// bytes, a padded short ping, a standard 64-byte one, the exact
// buffer fit -- must come back as a byte-exact complete Ethernet
// reply: swapped addresses, TTL 64 and DF with a fresh IP header
// checksum, type 0 with the request checksum incrementally adjusted,
// identifier, sequence and data echoed whole. Non-echo types and
// codes, broadcast pings, oversized payloads, truncated frames and
// tuser in header or payload must produce silence; tuser on a padding
// beat is swallowed upstream and the ping is still answered, the
// documented drop-FIFO dependency. A bare sweep instance with LOG2_DEPTH=4
// covers the parameter space plus the announced-length mismatch. A
// random soak mixes it all under random backpressure.

`timescale 1 ns / 100 ps

module axi_stream_icmp_echo_tb;

    localparam logic [47:0] LOCAL_MAC = 48'h02_12_34_56_78_9A;
    localparam logic [47:0] REQ_MAC   = 48'h02_AB_CD_EF_01_23;
    localparam logic [31:0] LOCAL_IP  = 32'hC0_A8_01_2A;
    localparam logic [31:0] REMOTE_IP = 32'hC0_A8_01_63;
    localparam logic [31:0] BCAST_IP  = 32'hFF_FF_FF_FF;

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
    // Chain: IPv4 parser -> packet demux -> ICMP echo
    //----------------------------------------------------------------
    logic [7:0]  s_tdata;
    logic        s_tuser;
    logic        s_tvalid;
    logic        s_tlast;
    logic        s_tready;
    logic [47:0] req_mac;

    logic [7:0]  pd_tdata;
    logic        pd_tuser;
    logic        pd_tvalid;
    logic        pd_tlast;
    logic        pd_tready;
    logic        pd_sel;
    logic [31:0] pd_src;
    logic [31:0] pd_dst;
    logic [7:0]  pd_proto;
    logic [15:0] pd_length;

    logic [7:0]  d_tdata;
    logic        d_tuser;
    logic        d_tvalid;
    logic        d_tlast;
    logic        d_tready;
    logic        d_info;

    logic [7:0]  r_tdata;
    logic        r_tuser;
    logic        r_tvalid;
    logic        r_tlast;
    logic        r_tready;

    axi_stream_ipv4_parser
    #(
        .NB_PROTOCOLS (1),
        .PROTOCOLS    (8'h01)
    )
    axi_stream_ipv4_parser_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .local_ip     (LOCAL_IP),
        .s_axi_tdata  (s_tdata),
        .s_axi_tuser  (s_tuser),
        .s_axi_tvalid (s_tvalid),
        .s_axi_tlast  (s_tlast),
        .s_axi_tready (s_tready),
        .m_axi_tdata  (pd_tdata),
        .m_axi_tuser  (pd_tuser),
        .m_axi_tvalid (pd_tvalid),
        .m_axi_tlast  (pd_tlast),
        .m_axi_tready (pd_tready),
        .m_sel        (pd_sel),
        .m_src_ip     (pd_src),
        .m_dst_ip     (pd_dst),
        .m_protocol   (pd_proto),
        .m_length     (pd_length)
    );

    axi_stream_packet_demux
    #(
        .NB_OUTPUTS (1),
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

    axi_stream_icmp_echo
    #(
        .LOG2_DEPTH (6)
    )
    axi_stream_icmp_echo_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .local_mac    (LOCAL_MAC),
        .local_ip     (LOCAL_IP),
        .s_axi_tdata  (d_tdata),
        .s_axi_tuser  (d_tuser),
        .s_axi_tvalid (d_tvalid),
        .s_axi_tlast  (d_tlast),
        .s_axi_tready (d_tready),
        .s_src_ip     (pd_src),
        .s_dst_ip     (pd_dst),
        .s_length     (pd_length),
        .s_src_mac    (req_mac),
        .m_axi_tdata  (r_tdata),
        .m_axi_tuser  (r_tuser),
        .m_axi_tvalid (r_tvalid),
        .m_axi_tlast  (r_tlast),
        .m_axi_tready (r_tready)
    );

    //----------------------------------------------------------------
    // Sweep instance: tiny buffer, driven bare with its side-bands
    //----------------------------------------------------------------
    logic [7:0]  p1_s_tdata;
    logic        p1_s_tuser;
    logic        p1_s_tvalid;
    logic        p1_s_tlast;
    logic        p1_s_tready;
    logic [15:0] p1_s_length;
    logic [31:0] p1_dst_ip;

    logic [7:0]  p1_m_tdata;
    logic        p1_m_tuser;
    logic        p1_m_tvalid;
    logic        p1_m_tlast;
    logic        p1_m_tready;

    axi_stream_icmp_echo
    #(
        .LOG2_DEPTH (4)
    )
    axi_stream_icmp_echo_p1_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .local_mac    (LOCAL_MAC),
        .local_ip     (LOCAL_IP),
        .s_axi_tdata  (p1_s_tdata),
        .s_axi_tuser  (p1_s_tuser),
        .s_axi_tvalid (p1_s_tvalid),
        .s_axi_tlast  (p1_s_tlast),
        .s_axi_tready (p1_s_tready),
        .s_src_ip     (REMOTE_IP),
        .s_dst_ip     (p1_dst_ip),
        .s_length     (p1_s_length),
        .s_src_mac    (REQ_MAC),
        .m_axi_tdata  (p1_m_tdata),
        .m_axi_tuser  (p1_m_tuser),
        .m_axi_tvalid (p1_m_tvalid),
        .m_axi_tlast  (p1_m_tlast),
        .m_axi_tready (p1_m_tready)
    );

    //----------------------------------------------------------------
    // Random backpressure on both reply streams
    //----------------------------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            r_tready    <= 1'b0;
            p1_m_tready <= 1'b0;
        end
        else begin
            r_tready    <= $urandom_range(0, 1) == 1;
            p1_m_tready <= $urandom_range(0, 1) == 1;
        end
    end

    //----------------------------------------------------------------
    // Expected reply beats {last, user, data}
    //----------------------------------------------------------------
    logic [9:0] exp_r [0:8191];
    integer     exp_r_count;
    integer     r_mon_idx;

    logic [9:0] p1_exp [0:1023];
    integer     p1_exp_count;
    integer     p1_mon_idx;

    //----------------------------------------------------------------
    // Payload data pattern shared by drivers and models
    //----------------------------------------------------------------
    function automatic logic [7:0] icmp_data(input logic [7:0] base, input integer k);
        return 8'(base + k);
    endfunction

    // Push the byte-exact reply expected for an answered request,
    // into the sweep instance's store or the main chain's
    task automatic push_reply(input logic sweep,
                              input logic [47:0] dst_mac, input logic [31:0] src_ip,
                              input logic [15:0] req_csum, input integer l4_len,
                              input logic [7:0] base);
        logic [15:0] total;
        logic [19:0] sum;
        logic [16:0] fold;
        logic [15:0] ip_csum, icmp_csum;
        logic [7:0]  rep [0:127];
        integer      n;

        total = 16'(20 + l4_len);
        sum   = 20'(16'h4500) + 20'(total) + 20'(16'h4000) + 20'(16'h4001)
              + 20'(LOCAL_IP[31:16]) + 20'(LOCAL_IP[15:0])
              + 20'(src_ip[31:16]) + 20'(src_ip[15:0]);
        fold    = 17'(sum[15:0]) + 17'(sum[19:16]);
        ip_csum = ~(16'(fold[15:0]) + 16'(fold[16]));

        fold      = {1'b0, ~req_csum} + 17'h0F7FF;
        icmp_csum = ~(16'(fold[15:0]) + 16'(fold[16]));

        n = 0;
        for (int i = 5; i >= 0; i--) begin rep[n] = dst_mac[8*i +: 8]; n++; end
        for (int i = 5; i >= 0; i--) begin rep[n] = LOCAL_MAC[8*i +: 8]; n++; end
        rep[n] = 8'h08; n++; rep[n] = 8'h00; n++;
        rep[n] = 8'h45; n++; rep[n] = 8'h00; n++;
        rep[n] = total[15:8]; n++; rep[n] = total[7:0]; n++;
        rep[n] = 8'h00; n++; rep[n] = 8'h00; n++;
        rep[n] = 8'h40; n++; rep[n] = 8'h00; n++;
        rep[n] = 8'h40; n++; rep[n] = 8'h01; n++;
        rep[n] = ip_csum[15:8]; n++; rep[n] = ip_csum[7:0]; n++;
        for (int i = 3; i >= 0; i--) begin rep[n] = LOCAL_IP[8*i +: 8]; n++; end
        for (int i = 3; i >= 0; i--) begin rep[n] = src_ip[8*i +: 8]; n++; end
        rep[n] = 8'h00; n++; rep[n] = 8'h00; n++;
        rep[n] = icmp_csum[15:8]; n++; rep[n] = icmp_csum[7:0]; n++;
        for (int k = 4; k < l4_len; k++) begin rep[n] = icmp_data(base, k); n++; end

        for (int k = 0; k < n; k++) begin
            if (sweep) begin
                p1_exp[p1_exp_count] = {k == n - 1, 1'b0, rep[k]};
                p1_exp_count = p1_exp_count + 1;
            end
            else begin
                exp_r[exp_r_count] = {k == n - 1, 1'b0, rep[k]};
                exp_r_count = exp_r_count + 1;
            end
        end
    endtask

    //----------------------------------------------------------------
    // Main-chain driver: a whole IPv4 frame around the ICMP payload.
    // wire_len drives padding or truncation of the IP frame;
    // user_beat is the IP-frame byte carrying tuser (-1 none).
    //----------------------------------------------------------------
    task automatic send_ping(input logic [31:0] src, input logic [31:0] dst,
                             input logic [7:0] icmp_type, input logic [7:0] icmp_code,
                             input logic [15:0] req_csum, input integer l4_len,
                             input integer wire_len, input logic [7:0] base,
                             input integer user_beat);
        logic [7:0]  hdr [0:19];
        logic [15:0] total;
        logic [19:0] sum;
        logic [16:0] fold;
        logic [15:0] csum;
        logic [7:0]  b;
        logic        last, user;
        logic        answered;

        total   = 16'(20 + l4_len);
        hdr[0]  = 8'h45;  hdr[1] = 8'h00;
        hdr[2]  = total[15:8]; hdr[3] = total[7:0];
        hdr[4]  = 8'h56;  hdr[5] = 8'h78;
        hdr[6]  = 8'h00;  hdr[7] = 8'h00;
        hdr[8]  = 8'd64;  hdr[9] = 8'h01;
        hdr[10] = 8'h00;  hdr[11] = 8'h00;
        hdr[12] = src[31:24]; hdr[13] = src[23:16];
        hdr[14] = src[15:8];  hdr[15] = src[7:0];
        hdr[16] = dst[31:24]; hdr[17] = dst[23:16];
        hdr[18] = dst[15:8];  hdr[19] = dst[7:0];
        sum = '0;
        for (int i = 0; i < 20; i += 2) begin
            sum = sum + 20'({hdr[i], hdr[i+1]});
        end
        fold = 17'(sum[15:0]) + 17'(sum[19:16]);
        fold = 17'(fold[15:0]) + 17'(fold[16]);
        csum = ~fold[15:0];
        hdr[10] = csum[15:8]; hdr[11] = csum[7:0];

        // tuser on a padding beat (>= 20 + l4_len) is swallowed by the
        // parser after the payload left clean, so the ping is answered
        answered = icmp_type == 8'h08 && icmp_code == 8'h00
                && dst == LOCAL_IP
                && l4_len >= 8 && l4_len <= 68
                && wire_len >= 20 + l4_len
                && (user_beat < 0 || user_beat >= 20 + l4_len);
        if (answered) begin
            push_reply(1'b0, req_mac, src, req_csum, l4_len, base);
        end

        for (int k = 0; k < wire_len; k++) begin
            if (k < 20)       b = hdr[k];
            else if (k == 20) b = icmp_type;
            else if (k == 21) b = icmp_code;
            else if (k == 22) b = req_csum[15:8];
            else if (k == 23) b = req_csum[7:0];
            else if (k < 20 + l4_len) b = icmp_data(base, k - 20);
            else              b = 8'h00;
            last = k == wire_len - 1;
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
    // Sweep driver: the bare L4 payload with its side-bands.
    // announce lets the length side-band lie about the beat count.
    //----------------------------------------------------------------
    task automatic p1_send(input logic [31:0] dst, input logic [7:0] icmp_type,
                           input logic [15:0] req_csum, input integer l4_len,
                           input integer announce, input logic [7:0] base);
        logic [7:0]  b;
        logic        answered;

        answered = icmp_type == 8'h08 && dst == LOCAL_IP
                && announce == l4_len && l4_len >= 8 && l4_len <= 20;
        if (answered) begin
            // Same reply image, addresses fixed by the port ties
            push_reply(1'b1, REQ_MAC, REMOTE_IP, req_csum, l4_len, base);
        end

        // Non-blocking: this executes in the same time step as the
        // posedge accepting the previous frame's last beat, and a
        // blocking write would race the DUT's live s_length read on
        // that closing beat
        p1_dst_ip   <= dst;
        p1_s_length <= 16'(announce);
        for (int k = 0; k < l4_len; k++) begin
            if (k == 0)      b = icmp_type;
            else if (k == 1) b = 8'h00;
            else if (k == 2) b = req_csum[15:8];
            else if (k == 3) b = req_csum[7:0];
            else             b = icmp_data(base, k);
            @(negedge clock);
            p1_s_tvalid = 1'b1;
            p1_s_tdata  = b;
            p1_s_tlast  = k == l4_len - 1;
            p1_s_tuser  = 1'b0;
            #1;
            while (p1_s_tready !== 1'b1) begin
                @(negedge clock);
                #1;
            end
            @(posedge clock);
        end
        p1_s_tvalid <= 1'b0;
        p1_s_tlast  <= 1'b0;
    endtask

    //----------------------------------------------------------------
    // Test sequence
    //----------------------------------------------------------------
    integer soak_len;
    integer soak_wire;

    initial begin
        s_tvalid = 1'b0; s_tdata = '0; s_tlast = 1'b0; s_tuser = 1'b0;
        p1_s_tvalid = 1'b0; p1_s_tdata = '0; p1_s_tlast = 1'b0; p1_s_tuser = 1'b0;
        p1_s_length = '0; p1_dst_ip = LOCAL_IP;
        req_mac = REQ_MAC;

        wait (sreset === 1'b0);
        @(posedge clock);

        // Answered: minimum, padded short ping, standard 64-byte,
        // exact buffer fit (LOG2_DEPTH 6 -> 68 bytes of L4)
        send_ping(REMOTE_IP, LOCAL_IP, 8'h08, 8'h00, 16'h1234, 8, 46, 8'h50, -1);
        send_ping(REMOTE_IP, LOCAL_IP, 8'h08, 8'h00, 16'hBEEF, 12, 46, 8'h60, -1);
        send_ping(REMOTE_IP, LOCAL_IP, 8'h08, 8'h00, 16'h0000, 64, 84, 8'h70, -1);
        send_ping(REMOTE_IP, LOCAL_IP, 8'h08, 8'h00, 16'hFFFF, 68, 88, 8'h80, -1);

        // Silence: echo reply type, wrong code, broadcast ping,
        // oversized, truncated, tuser in header and in payload
        send_ping(REMOTE_IP, LOCAL_IP, 8'h00, 8'h00, 16'h1111, 12, 46, 8'h90, -1);
        send_ping(REMOTE_IP, LOCAL_IP, 8'h08, 8'h01, 16'h2222, 12, 46, 8'hA0, -1);
        send_ping(REMOTE_IP, BCAST_IP, 8'h08, 8'h00, 16'h3333, 12, 46, 8'hB0, -1);
        send_ping(REMOTE_IP, LOCAL_IP, 8'h08, 8'h00, 16'h4444, 69, 89, 8'hC0, -1);
        send_ping(REMOTE_IP, LOCAL_IP, 8'h08, 8'h00, 16'h5555, 24, 30, 8'hD0, -1);
        send_ping(REMOTE_IP, LOCAL_IP, 8'h08, 8'h00, 16'h6666, 12, 46, 8'hE0, 5);
        send_ping(REMOTE_IP, LOCAL_IP, 8'h08, 8'h00, 16'h7777, 12, 46, 8'hF0, 25);

        // tuser on a padding beat lands after the payload already left
        // clean: the parser swallows it and the ping is answered (the
        // drop FIFO upstream is what removes FCS-flagged frames)
        send_ping(REMOTE_IP, LOCAL_IP, 8'h08, 8'h00, 16'hABCD, 12, 46, 8'h48, 40);

        // Back-to-back requests through the reply stall, with a
        // changing requester MAC side-band
        req_mac = 48'h02_00_00_00_00_01;
        send_ping(32'h0A_00_00_01, LOCAL_IP, 8'h08, 8'h00, 16'h8888, 8, 46, 8'h10, -1);
        req_mac = 48'h02_00_00_00_00_02;
        send_ping(32'h0A_00_00_02, LOCAL_IP, 8'h08, 8'h00, 16'h9999, 8, 46, 8'h20, -1);
        req_mac = REQ_MAC;

        // A source address that drives the reply IP checksum through
        // the double fold: with total_length 32 the eight halfwords
        // sum to 0x2FFFF, the first fold gives 0x10001, and only the
        // end-around carry makes the checksum 0xFFFD rather than
        // 0xFFFE. Random addresses reach this a few times in 65536
        send_ping(32'hFF_FF_79_0D, LOCAL_IP, 8'h08, 8'h00, 16'h5A5A, 12, 46, 8'h3A, -1);

        // Sweep instance: exact fit, oversize by one, minimum,
        // announced length mismatch, non-echo, broadcast
        p1_send(LOCAL_IP, 8'h08, 16'hCAFE, 20, 20, 8'h31);
        p1_send(LOCAL_IP, 8'h08, 16'hCAFE, 21, 21, 8'h32);
        p1_send(LOCAL_IP, 8'h08, 16'hD00D, 8, 8, 8'h33);
        p1_send(LOCAL_IP, 8'h08, 16'h1357, 12, 16, 8'h34);
        p1_send(LOCAL_IP, 8'h00, 16'h2468, 12, 12, 8'h35);
        p1_send(BCAST_IP, 8'h08, 16'h9BDF, 12, 12, 8'h36);

        // Stale-length attack: a dropped 1-beat frame leaves len_q at
        // 1, then a lying 1-beat frame announcing 8 must still be
        // silent -- the verdict reads the live s_length, not len_q
        p1_send(LOCAL_IP, 8'h08, 16'h4242, 1, 1, 8'h37);
        p1_send(LOCAL_IP, 8'h08, 16'h4242, 1, 8, 8'h38);

        // Random soak on the main chain
        for (int f = 0; f < 30; f++) begin
            soak_len  = $urandom_range(6, 72);
            soak_wire = 20 + soak_len;
            if (soak_wire < 46) soak_wire = 46;
            if ($urandom_range(0, 7) == 0) soak_wire = soak_wire - $urandom_range(1, 5);
            send_ping($urandom, $urandom_range(0, 3) != 0 ? LOCAL_IP : REMOTE_IP,
                      $urandom_range(0, 3) != 0 ? 8'h08 : 8'($urandom),
                      $urandom_range(0, 7) == 0 ? 8'($urandom) : 8'h00,
                      16'($urandom), soak_len, soak_wire, 8'($urandom),
                      $urandom_range(0, 9) == 0 ? $urandom_range(0, soak_wire - 1) : -1);
            repeat ($urandom_range(0, 2)) @(posedge clock);
        end
        repeat (300) @(posedge clock);

        if (r_mon_idx != exp_r_count) begin
            errors = errors + 1;
            $error("reply stream incomplete: %0d/%0d beats", r_mon_idx, exp_r_count);
        end
        if (p1_mon_idx != p1_exp_count) begin
            errors = errors + 1;
            $error("sweep stream incomplete: %0d/%0d beats", p1_mon_idx, p1_exp_count);
        end

        if (errors == 0)
          $display("axi_stream_icmp_echo_tb: ALL TESTS PASSED");
        else
          $display("axi_stream_icmp_echo_tb: %0d ERROR(S)", errors);
        $finish;
    end

    // Watchdog: a reply that never drains stalls the driver forever
    initial begin
        #1200000;
        errors = errors + 1;
        $error("watchdog: reply %0d/%0d sweep %0d/%0d",
               r_mon_idx, exp_r_count, p1_mon_idx, p1_exp_count);
        $display("axi_stream_icmp_echo_tb: %0d ERROR(S)", errors);
        $finish;
    end

    //----------------------------------------------------------------
    // Monitors
    //----------------------------------------------------------------
    initial begin
        exp_r_count = 0; r_mon_idx = 0;
        p1_exp_count = 0; p1_mon_idx = 0;
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
        if (sreset === 1'b0 && p1_m_tvalid === 1'b1 && p1_m_tready === 1'b1) begin
            if (p1_mon_idx >= p1_exp_count) begin
                errors = errors + 1;
                $error("sweep: unexpected beat %02x", p1_m_tdata);
            end
            else if ({p1_m_tlast, p1_m_tuser, p1_m_tdata} !== p1_exp[p1_mon_idx]) begin
                errors = errors + 1;
                $error("sweep beat %0d: got last=%b user=%b data=%02x",
                       p1_mon_idx, p1_m_tlast, p1_m_tuser, p1_m_tdata);
            end
            p1_mon_idx = p1_mon_idx + 1;
        end
    end

endmodule
