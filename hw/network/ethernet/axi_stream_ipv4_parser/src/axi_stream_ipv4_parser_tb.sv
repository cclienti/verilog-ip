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
// Title         : AXI Stream IPv4 Parser Testbench
//-----------------------------------------------------------------------------
// File          : axi_stream_ipv4_parser_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-28
// Last modified : 2026-08-28
//-----------------------------------------------------------------------------
// Description :
// Testbench of the IPv4 parser, proving the chain into the packet
// demux. The main instance (ICMP only) feeds a one-output demux whose
// select and info come straight from the parser: valid ICMP packets --
// exact, Ethernet-padded, DF set, or sent to the limited broadcast --
// must come out cut at total_length, while a bad version/IHL, a
// fragment, a wrong checksum, a foreign destination, an unknown
// protocol or tuser inside the header must take the discard code with
// every payload beat still crossing the seam. A frame ending before
// total_length must abort with tuser on its final beat; total_length
// of 20 or a frame dying inside its header must emit nothing. tuser on
// a payload beat passes through. A seam monitor checks sel and every
// side-band field on every emitted beat, and a bare NB_PROTOCOLS=2
// sweep instance covers the parameter space. A random soak mixes all
// of it under random backpressure.

`timescale 1 ns / 100 ps

module axi_stream_ipv4_parser_tb;

    localparam logic [31:0] LOCAL_IP  = 32'hC0_A8_01_2A;
    localparam logic [31:0] REMOTE_IP = 32'hC0_A8_01_63;
    localparam logic [31:0] BCAST_IP  = 32'hFF_FF_FF_FF;

    logic [31:0] my_ip = LOCAL_IP;  // the address both DUTs answer to, changed for one frame

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
    // Main chain: parser -> packet demux, ICMP only
    //----------------------------------------------------------------
    logic [7:0]  s_tdata;
    logic        s_tuser;
    logic        s_tvalid;
    logic        s_tlast;
    logic        s_tready;

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

    logic [7:0]  m_tdata;
    logic        m_tuser;
    logic        m_tvalid;
    logic        m_tlast;
    logic        m_tready;
    logic [7:0]  m_info;

    axi_stream_ipv4_parser
    #(
        .NB_PROTOCOLS (1),
        .PROTOCOLS    (8'h01)
    )
    axi_stream_ipv4_parser_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .local_ip     (my_ip),
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
        .INFO_WIDTH (8)
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
        .s_info       (pd_proto),
        .m_axi_tdata  (m_tdata),
        .m_axi_tuser  (m_tuser),
        .m_axi_tvalid (m_tvalid),
        .m_axi_tlast  (m_tlast),
        .m_axi_tready (m_tready),
        .m_info       (m_info)
    );

    //----------------------------------------------------------------
    // Sweep instance: two protocols, bare output
    //----------------------------------------------------------------
    logic [7:0]  p2_s_tdata;
    logic        p2_s_tuser;
    logic        p2_s_tvalid;
    logic        p2_s_tlast;
    logic        p2_s_tready;

    logic [7:0]  p2_m_tdata;
    logic        p2_m_tuser;
    logic        p2_m_tvalid;
    logic        p2_m_tlast;
    logic        p2_m_tready;
    logic [1:0]  p2_sel;
    logic [31:0] p2_src;
    logic [31:0] p2_dst;
    logic [7:0]  p2_proto;
    logic [15:0] p2_length;

    axi_stream_ipv4_parser
    #(
        .NB_PROTOCOLS (2),
        .PROTOCOLS    ({8'h11, 8'h01})
    )
    axi_stream_ipv4_parser_p2_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .local_ip     (my_ip),
        .s_axi_tdata  (p2_s_tdata),
        .s_axi_tuser  (p2_s_tuser),
        .s_axi_tvalid (p2_s_tvalid),
        .s_axi_tlast  (p2_s_tlast),
        .s_axi_tready (p2_s_tready),
        .m_axi_tdata  (p2_m_tdata),
        .m_axi_tuser  (p2_m_tuser),
        .m_axi_tvalid (p2_m_tvalid),
        .m_axi_tlast  (p2_m_tlast),
        .m_axi_tready (p2_m_tready),
        .m_sel        (p2_sel),
        .m_src_ip     (p2_src),
        .m_dst_ip     (p2_dst),
        .m_protocol   (p2_proto),
        .m_length     (p2_length)
    );

    //----------------------------------------------------------------
    // Random backpressure per consumer
    //----------------------------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            m_tready    <= 1'b0;
            p2_m_tready <= 1'b0;
        end
        else begin
            m_tready    <= $urandom_range(0, 1) == 1;
            p2_m_tready <= $urandom_range(0, 1) == 1;
        end
    end

    //----------------------------------------------------------------
    // Expected demux output beats {info, last, user, data} and seam
    // frames {sel, src, dst, proto, length}
    //----------------------------------------------------------------
    logic [17:0] exp_m [0:4095];
    integer      exp_m_count;
    integer      m_mon_idx;

    logic [88:0] exp_seam [0:255];
    integer      exp_seam_beats [0:255];
    integer      exp_seam_frames;
    integer      seam_frame_idx;
    integer      seam_beat_cnt;

    logic [9:0]  p2_exp [0:1023];
    integer      p2_exp_count;
    integer      p2_mon_idx;
    logic [89:0] p2_exp_hdr [0:63];
    integer      p2_exp_beats [0:63];
    integer      p2_exp_frames;
    integer      p2_frame_idx;
    integer      p2_beat_cnt;

    //----------------------------------------------------------------
    // Driver and scoreboard model, shared by both instances through
    // the p2 flag. pay_len sets total_length; wire_len is what is
    // really driven (padding, truncation). bad_kind: 0 none,
    // 1 version, 2 MF, 3 offset, 4 checksum. user_beat: frame byte
    // carrying tuser (-1 none): inside the header it discards, on a
    // payload byte it passes through.
    //----------------------------------------------------------------
    task automatic send_ip(input logic p2, input logic [31:0] src, input logic [31:0] dst,
                           input logic [7:0] proto, input logic df,
                           input integer pay_len, input integer wire_len,
                           input integer bad_kind, input integer user_beat);
        logic [7:0]  hdr [0:19];
        logic [15:0] total;
        logic [19:0] sum;
        logic [16:0] fold;
        logic [15:0] csum;
        logic [7:0]  b;
        logic        last, user, exp_last, exp_user;
        logic [1:0]  sel;
        integer      emit;

        total   = 16'(20 + pay_len);
        hdr[0]  = bad_kind == 1 ? 8'h46 : 8'h45;
        hdr[1]  = 8'h00;
        hdr[2]  = total[15:8];
        hdr[3]  = total[7:0];
        hdr[4]  = 8'h12;
        hdr[5]  = 8'h34;
        hdr[6]  = df ? 8'h40 : 8'h00;
        if (bad_kind == 2) hdr[6] = hdr[6] | 8'h20;
        hdr[7]  = bad_kind == 3 ? 8'h05 : 8'h00;
        hdr[8]  = 8'd64;
        hdr[9]  = proto;
        hdr[10] = 8'h00;
        hdr[11] = 8'h00;
        hdr[12] = src[31:24];
        hdr[13] = src[23:16];
        hdr[14] = src[15:8];
        hdr[15] = src[7:0];
        hdr[16] = dst[31:24];
        hdr[17] = dst[23:16];
        hdr[18] = dst[15:8];
        hdr[19] = dst[7:0];
        sum = '0;
        for (int i = 0; i < 20; i += 2) begin
            sum = sum + 20'({hdr[i], hdr[i+1]});
        end
        fold = 17'(sum[15:0]) + 17'(sum[19:16]);
        fold = 17'(fold[15:0]) + 17'(fold[16]);
        csum = ~fold[15:0];
        if (bad_kind == 4) csum = csum + 16'd1;
        hdr[10] = csum[15:8];
        hdr[11] = csum[7:0];

        // Reference model: select code, then what the parser emits
        if (bad_kind != 0 || (user_beat >= 0 && user_beat < 20)
            || !(dst == my_ip || dst == BCAST_IP)) begin
            sel = p2 ? 2'd2 : 2'd1;
        end
        else if (!p2) begin
            sel = proto == 8'h01 ? 2'd0 : 2'd1;
        end
        else begin
            sel = proto == 8'h01 ? 2'd0 : proto == 8'h11 ? 2'd1 : 2'd2;
        end

        emit = 0;
        if (pay_len > 0 && wire_len > 20) begin
            emit = pay_len < wire_len - 20 ? pay_len : wire_len - 20;
        end

        if (emit > 0) begin
            if (p2) begin
                p2_exp_hdr[p2_exp_frames]   = {sel, src, dst, proto, 16'(pay_len)};
                p2_exp_beats[p2_exp_frames] = emit;
                p2_exp_frames               = p2_exp_frames + 1;
            end
            else begin
                exp_seam[exp_seam_frames]       = {sel[0], src, dst, proto, 16'(pay_len)};
                exp_seam_beats[exp_seam_frames] = emit;
                exp_seam_frames                 = exp_seam_frames + 1;
            end
            for (int k = 0; k < emit; k++) begin
                exp_last = k == emit - 1;
                // A short wire aborts with tuser on the final beat;
                // otherwise payload tuser passes through
                exp_user = (exp_last && emit < pay_len) || (20 + k) == user_beat;
                b = 8'(8'h30 + k);
                // The bare sweep instance emits every beat, discard
                // frames included; the main chain only what routes
                if (p2) begin
                    p2_exp[p2_exp_count] = {exp_last, exp_user, b};
                    p2_exp_count = p2_exp_count + 1;
                end
                if (!p2 && sel == 2'd0) begin
                    exp_m[exp_m_count] = {proto, exp_last, exp_user, b};
                    exp_m_count = exp_m_count + 1;
                end
            end
        end

        for (int k = 0; k < wire_len; k++) begin
            b    = k < 20 ? hdr[k] : 8'(8'h30 + (k - 20));
            last = k == wire_len - 1;
            user = k == user_beat;
            @(negedge clock);
            if (p2) begin
                p2_s_tvalid = 1'b1; p2_s_tdata = b; p2_s_tlast = last; p2_s_tuser = user;
            end
            else begin
                s_tvalid = 1'b1; s_tdata = b; s_tlast = last; s_tuser = user;
            end
            #1;
            while ((p2 ? p2_s_tready : s_tready) !== 1'b1) begin
                @(negedge clock);
                #1;
            end
            @(posedge clock);
        end
        if (p2) begin
            p2_s_tvalid <= 1'b0; p2_s_tlast <= 1'b0; p2_s_tuser <= 1'b0;
        end
        else begin
            s_tvalid <= 1'b0; s_tlast <= 1'b0; s_tuser <= 1'b0;
        end
    endtask

    //----------------------------------------------------------------
    // Test sequence
    //----------------------------------------------------------------
    logic [31:0] soak_dst;
    logic [7:0]  soak_proto;
    integer      soak_pay;
    integer      soak_wire;
    integer      soak_bad;
    integer      soak_user;

    initial begin
        s_tvalid = 1'b0; s_tdata = '0; s_tlast = 1'b0; s_tuser = 1'b0;
        p2_s_tvalid = 1'b0; p2_s_tdata = '0; p2_s_tlast = 1'b0; p2_s_tuser = 1'b0;

        wait (sreset === 1'b0);
        @(posedge clock);

        // Valid ICMP: exact, Ethernet-padded, DF set, broadcast dst
        send_ip(1'b0, REMOTE_IP, LOCAL_IP, 8'h01, 1'b0, 28, 48, 0, -1);
        send_ip(1'b0, REMOTE_IP, LOCAL_IP, 8'h01, 1'b0, 8, 46, 0, -1);
        send_ip(1'b0, REMOTE_IP, LOCAL_IP, 8'h01, 1'b1, 12, 32, 0, -1);

        // The checksum verdict must fold the nine-halfword sum twice.
        // With the sender's checksum in, that sum is congruent to the
        // negative of the destination's low halfword, and its first
        // fold carries only when that residue is below the number of
        // 16-bit wraps, at most 9 -- impossible for LOCAL_IP, whose
        // residue is 0xFED5, for any source. An address ending in
        // 0xFFFE has residue 1, and this source makes the sum 0x1FFFF,
        // one wrap, first fold exactly 0x10000
        my_ip = 32'h0A_00_FF_FE;
        send_ip(1'b0, 32'hD5_E3_41_24, my_ip, 8'h01, 1'b0, 8, 46, 0, -1);
        my_ip = LOCAL_IP;
        send_ip(1'b0, REMOTE_IP, BCAST_IP, 8'h01, 1'b0, 8, 46, 0, -1);

        // Discards: foreign dst, bad version, MF, offset, checksum,
        // unknown protocol, tuser inside the header
        send_ip(1'b0, REMOTE_IP, REMOTE_IP, 8'h01, 1'b0, 8, 46, 0, -1);
        send_ip(1'b0, REMOTE_IP, LOCAL_IP, 8'h01, 1'b0, 8, 46, 1, -1);
        send_ip(1'b0, REMOTE_IP, LOCAL_IP, 8'h01, 1'b0, 8, 46, 2, -1);
        send_ip(1'b0, REMOTE_IP, LOCAL_IP, 8'h01, 1'b0, 8, 46, 3, -1);
        send_ip(1'b0, REMOTE_IP, LOCAL_IP, 8'h01, 1'b0, 8, 46, 4, -1);
        send_ip(1'b0, REMOTE_IP, LOCAL_IP, 8'h11, 1'b0, 8, 46, 0, -1);
        send_ip(1'b0, REMOTE_IP, LOCAL_IP, 8'h01, 1'b0, 8, 46, 0, 5);

        // A header-rejected frame with no padding exits through the
        // PAYLOAD tlast branch: its sticky drop must not leak into
        // the accepted frame that follows
        send_ip(1'b0, REMOTE_IP, LOCAL_IP, 8'h01, 1'b0, 8, 28, 1, -1);
        send_ip(1'b0, REMOTE_IP, LOCAL_IP, 8'h01, 1'b0, 8, 46, 0, -1);

        // Nothing at all: no L4 payload, death inside the header
        send_ip(1'b0, REMOTE_IP, LOCAL_IP, 8'h01, 1'b0, 0, 46, 0, -1);
        send_ip(1'b0, REMOTE_IP, LOCAL_IP, 8'h01, 1'b0, 28, 12, 0, -1);

        // Truncation aborts with tuser; payload tuser passes through
        send_ip(1'b0, REMOTE_IP, LOCAL_IP, 8'h01, 1'b0, 20, 30, 0, -1);
        send_ip(1'b0, REMOTE_IP, LOCAL_IP, 8'h01, 1'b0, 8, 28, 0, 25);

        // Sweep instance: both protocol codes and the discard code
        send_ip(1'b1, REMOTE_IP, LOCAL_IP, 8'h01, 1'b0, 8, 46, 0, -1);
        send_ip(1'b1, REMOTE_IP, LOCAL_IP, 8'h11, 1'b0, 8, 46, 0, -1);
        send_ip(1'b1, REMOTE_IP, LOCAL_IP, 8'h06, 1'b0, 8, 46, 0, -1);
        send_ip(1'b1, REMOTE_IP, REMOTE_IP, 8'h11, 1'b0, 8, 46, 0, -1);

        // Random soak on the main chain
        for (int f = 0; f < 40; f++) begin
            soak_dst   = $urandom_range(0, 2) != 0 ? LOCAL_IP : REMOTE_IP;
            soak_proto = $urandom_range(0, 2) != 0 ? 8'h01 : 8'($urandom);
            soak_bad   = $urandom_range(0, 7) == 0 ? $urandom_range(1, 4) : 0;
            soak_pay   = $urandom_range(0, 40);
            case ($urandom_range(0, 3))
                0: soak_wire = 20 + soak_pay;
                1: soak_wire = (20 + soak_pay) > 46 ? 20 + soak_pay : 46;
                2: soak_wire = 20 + soak_pay + $urandom_range(0, 10);
                default: soak_wire = $urandom_range(21, 20 + soak_pay > 21 ? 20 + soak_pay : 21);
            endcase
            soak_user = $urandom_range(0, 9) == 0 && soak_wire >= 20 + soak_pay
                      ? $urandom_range(0, soak_wire - 1) : -1;
            send_ip(1'b0, $urandom, soak_dst, soak_proto, $urandom_range(0, 1) == 1,
                    soak_pay, soak_wire, soak_bad, soak_user);
            repeat ($urandom_range(0, 2)) @(posedge clock);
        end
        repeat (100) @(posedge clock);

        if (m_mon_idx != exp_m_count) begin
            errors = errors + 1;
            $error("demux stream incomplete: %0d/%0d beats", m_mon_idx, exp_m_count);
        end
        if (seam_frame_idx != exp_seam_frames) begin
            errors = errors + 1;
            $error("seam incomplete: %0d/%0d frames", seam_frame_idx, exp_seam_frames);
        end
        if (p2_mon_idx != p2_exp_count || p2_frame_idx != p2_exp_frames) begin
            errors = errors + 1;
            $error("sweep incomplete: %0d/%0d beats, %0d/%0d frames",
                   p2_mon_idx, p2_exp_count, p2_frame_idx, p2_exp_frames);
        end

        if (errors == 0)
          $display("axi_stream_ipv4_parser_tb: ALL TESTS PASSED");
        else
          $display("axi_stream_ipv4_parser_tb: %0d ERROR(S)", errors);
        $finish;
    end

    // Watchdog: a stalled payload phase hangs the driver forever
    initial begin
        #600000;
        errors = errors + 1;
        $error("watchdog: %0d/%0d seam %0d/%0d p2 %0d/%0d",
               m_mon_idx, exp_m_count, seam_frame_idx, exp_seam_frames,
               p2_mon_idx, p2_exp_count);
        $display("axi_stream_ipv4_parser_tb: %0d ERROR(S)", errors);
        $finish;
    end

    //----------------------------------------------------------------
    // Monitors
    //----------------------------------------------------------------
    initial begin
        exp_m_count = 0; m_mon_idx = 0;
        exp_seam_frames = 0; seam_frame_idx = 0; seam_beat_cnt = 0;
        p2_exp_count = 0; p2_mon_idx = 0;
        p2_exp_frames = 0; p2_frame_idx = 0; p2_beat_cnt = 0;
    end

    always @(posedge clock) begin
        if (sreset === 1'b0 && pd_tvalid === 1'b1 && pd_tready === 1'b1) begin
            if (seam_frame_idx >= exp_seam_frames) begin
                errors = errors + 1;
                $error("seam: unexpected frame, beat %02x", pd_tdata);
            end
            else begin
                if ({pd_sel, pd_src, pd_dst, pd_proto, pd_length}
                    !== exp_seam[seam_frame_idx]) begin
                    errors = errors + 1;
                    $error("seam frame %0d: sel=%0d src=%08x dst=%08x proto=%02x len=%0d",
                           seam_frame_idx, pd_sel, pd_src, pd_dst, pd_proto, pd_length);
                end
                seam_beat_cnt = seam_beat_cnt + 1;
                if (pd_tlast === 1'b1) begin
                    if (seam_beat_cnt != exp_seam_beats[seam_frame_idx]) begin
                        errors = errors + 1;
                        $error("seam frame %0d: %0d beats, expected %0d",
                               seam_frame_idx, seam_beat_cnt, exp_seam_beats[seam_frame_idx]);
                    end
                    seam_beat_cnt  = 0;
                    seam_frame_idx = seam_frame_idx + 1;
                end
            end
        end
    end

    always @(posedge clock) begin
        if (sreset === 1'b0 && m_tvalid === 1'b1 && m_tready === 1'b1) begin
            if (m_mon_idx >= exp_m_count) begin
                errors = errors + 1;
                $error("out: unexpected beat %02x", m_tdata);
            end
            else if ({m_info, m_tlast, m_tuser, m_tdata} !== exp_m[m_mon_idx]) begin
                errors = errors + 1;
                $error("out beat %0d: got info=%02x last=%b user=%b data=%02x",
                       m_mon_idx, m_info, m_tlast, m_tuser, m_tdata);
            end
            m_mon_idx = m_mon_idx + 1;
        end
    end

    always @(posedge clock) begin
        if (sreset === 1'b0 && p2_m_tvalid === 1'b1 && p2_m_tready === 1'b1) begin
            if (p2_frame_idx >= p2_exp_frames || p2_mon_idx >= p2_exp_count) begin
                errors = errors + 1;
                $error("sweep: unexpected beat %02x", p2_m_tdata);
            end
            else begin
                if ({p2_sel, p2_src, p2_dst, p2_proto, p2_length}
                    !== p2_exp_hdr[p2_frame_idx]) begin
                    errors = errors + 1;
                    $error("sweep frame %0d: sel=%0d src=%08x dst=%08x proto=%02x len=%0d",
                           p2_frame_idx, p2_sel, p2_src, p2_dst, p2_proto, p2_length);
                end
                if ({p2_m_tlast, p2_m_tuser, p2_m_tdata} !== p2_exp[p2_mon_idx]) begin
                    errors = errors + 1;
                    $error("sweep beat %0d mismatch", p2_mon_idx);
                end
                p2_mon_idx  = p2_mon_idx + 1;
                p2_beat_cnt = p2_beat_cnt + 1;
                if (p2_m_tlast === 1'b1) begin
                    if (p2_beat_cnt != p2_exp_beats[p2_frame_idx]) begin
                        errors = errors + 1;
                        $error("sweep frame %0d: %0d beats, expected %0d",
                               p2_frame_idx, p2_beat_cnt, p2_exp_beats[p2_frame_idx]);
                    end
                    p2_beat_cnt  = 0;
                    p2_frame_idx = p2_frame_idx + 1;
                end
            end
        end
    end

endmodule
