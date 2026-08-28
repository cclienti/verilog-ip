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
// Title         : AXI Stream Ethernet Parser Testbench
//-----------------------------------------------------------------------------
// File          : axi_stream_eth_parser_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-27
// Last modified : 2026-08-28
//-----------------------------------------------------------------------------
// Description :
// Testbench of the AXI Stream Ethernet Parser, proving the documented
// chain into the packet demux. The main instance (two EtherTypes,
// destination filter active) feeds a two-output demux whose select and
// info side-band come straight from the parser: IPv4 and ARP frames to
// the local MAC or broadcast must come out whole on their output,
// unknown EtherTypes and foreign unicast DAs must vanish in the demux
// discard path, and the promiscuous bit must reopen them. A seam
// monitor between the two checks every side-band field -- select, both
// MACs, EtherType, length -- on every payload beat, for discarded
// frames included. Runt frames (tlast inside the header, the
// headers-only 14-byte frame included) must produce no beat anywhere
// and leave the next frame unharmed. A multicast group DA must take
// the discard code on the main instance (ACCEPT_MULTICAST off) and
// pass on the bare sweep instance, whose NB_ETHERTYPES=1,
// LENGTH_WIDTH=8 and ACCEPT_MULTICAST=1 cover the parameter space and
// show the discard code is only a select: its payload beats still
// flow. A random soak mixes DAs -- the multicast group included --
// EtherTypes, lengths, gaps and the promiscuous bit under random
// backpressure.

`timescale 1 ns / 100 ps

module axi_stream_eth_parser_tb;

    localparam logic [47:0] LOCAL_MAC  = 48'h02_12_34_56_78_9A;
    localparam logic [47:0] REMOTE_MAC = 48'h02_AB_CD_EF_01_23;
    localparam logic [47:0] FOREIGN_MAC = 48'h0A_0B_0C_0D_0E_0F;
    localparam logic [47:0] MCAST_MAC  = 48'h01_00_5E_00_00_FB;
    localparam logic [47:0] BCAST_MAC  = 48'hFF_FF_FF_FF_FF_FF;

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
    // Main chain: parser -> packet demux
    //----------------------------------------------------------------
    logic        promiscuous;
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

    logic [15:0] m_tdata;
    logic [1:0]  m_tuser;
    logic [1:0]  m_tvalid;
    logic [1:0]  m_tlast;
    logic [1:0]  m_tready;
    logic [15:0] m_info;

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
        .promiscuous  (promiscuous),
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
        .INFO_WIDTH (16)
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
        .s_info       (pd_ethertype),
        .m_axi_tdata  (m_tdata),
        .m_axi_tuser  (m_tuser),
        .m_axi_tvalid (m_tvalid),
        .m_axi_tlast  (m_tlast),
        .m_axi_tready (m_tready),
        .m_info       (m_info)
    );

    //----------------------------------------------------------------
    // Sweep instance: one EtherType, narrow length, bare output
    //----------------------------------------------------------------
    logic       p1_promiscuous;
    logic [7:0] p1_s_tdata;
    logic       p1_s_tuser;
    logic       p1_s_tvalid;
    logic       p1_s_tlast;
    logic       p1_s_tready;
    logic [7:0] p1_s_length;

    logic [7:0]  p1_m_tdata;
    logic        p1_m_tuser;
    logic        p1_m_tvalid;
    logic        p1_m_tlast;
    logic        p1_m_tready;
    logic        p1_sel;
    logic [47:0] p1_dst;
    logic [47:0] p1_src;
    logic [15:0] p1_ethertype;
    logic [7:0]  p1_length;

    axi_stream_eth_parser
    #(
        .NB_ETHERTYPES    (1),
        .ETHERTYPES       (16'h0800),
        .LENGTH_WIDTH     (8),
        .ACCEPT_MULTICAST (1)
    )
    axi_stream_eth_parser_p1_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .local_mac    (LOCAL_MAC),
        .promiscuous  (p1_promiscuous),
        .s_axi_tdata  (p1_s_tdata),
        .s_axi_tuser  (p1_s_tuser),
        .s_axi_tvalid (p1_s_tvalid),
        .s_axi_tlast  (p1_s_tlast),
        .s_axi_tready (p1_s_tready),
        .s_length     (p1_s_length),
        .m_axi_tdata  (p1_m_tdata),
        .m_axi_tuser  (p1_m_tuser),
        .m_axi_tvalid (p1_m_tvalid),
        .m_axi_tlast  (p1_m_tlast),
        .m_axi_tready (p1_m_tready),
        .m_sel        (p1_sel),
        .m_dst_mac    (p1_dst),
        .m_src_mac    (p1_src),
        .m_ethertype  (p1_ethertype),
        .m_length     (p1_length)
    );

    //----------------------------------------------------------------
    // Random backpressure per consumer
    //----------------------------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            m_tready    <= '0;
            p1_m_tready <= 1'b0;
        end
        else begin
            for (int i = 0; i < 2; i++) begin
                m_tready[i] <= $urandom_range(0, 1) == 1;
            end
            p1_m_tready <= $urandom_range(0, 1) == 1;
        end
    end

    //----------------------------------------------------------------
    // Expected demux output beats: {info, last, user, data}
    //----------------------------------------------------------------
    logic [25:0] exp0 [0:4095];
    logic [25:0] exp1 [0:4095];
    integer      exp_count [0:1];
    integer      mon_idx [0:1];

    task automatic push_exp(input integer o, input logic [15:0] info,
                            input logic last, input logic user, input logic [7:0] data);
        case (o)
            0: exp0[exp_count[0]] = {info, last, user, data};
            default: exp1[exp_count[1]] = {info, last, user, data};
        endcase
        exp_count[o] = exp_count[o] + 1;
    endtask

    //----------------------------------------------------------------
    // Expected seam frames: {sel, dst, src, ethertype, length}
    //----------------------------------------------------------------
    logic [125:0] exp_seam [0:255];
    integer       exp_seam_beats [0:255];
    integer       exp_seam_frames;
    integer       seam_frame_idx;
    integer       seam_beat_cnt;

    //----------------------------------------------------------------
    // Expected sweep-instance frames and beats
    //----------------------------------------------------------------
    logic [120:0] p1_exp_hdr [0:63];
    integer       p1_exp_beats [0:63];
    integer       p1_exp_frames;
    integer       p1_frame_idx;
    integer       p1_beat_cnt;

    logic [9:0]   p1_exp [0:1023];
    integer       p1_exp_count;
    integer       p1_mon_idx;

    //----------------------------------------------------------------
    // Reference select model, shared by both instances: DA filter,
    // then lowest matching index, the discard code nb otherwise
    //----------------------------------------------------------------
    function automatic logic [1:0] model_sel(input logic promisc, input logic [47:0] dst,
                                             input logic [15:0] ethertype,
                                             input logic [31:0] ethertypes, input integer nb,
                                             input logic accept_mc);
        logic [1:0] sel;
        logic       da_ok;
        sel = 2'(nb);
        for (int i = nb - 1; i >= 0; i--) begin
            if (ethertype == ethertypes[i*16 +: 16]) begin
                sel = 2'(i);
            end
        end
        da_ok = promisc || dst === LOCAL_MAC
             || (accept_mc ? dst[40] === 1'b1 : dst === BCAST_MAC);
        if (!da_ok) begin
            sel = 2'(nb);
        end
        return sel;
    endfunction

    // Header/payload byte mux, shared by both frame drivers
    function automatic logic [7:0] frame_byte(input logic [47:0] dst, input logic [47:0] src,
                                              input logic [15:0] ethertype, input logic [7:0] base,
                                              input integer k);
        if (k < 6)   return dst[8*(5-k) +: 8];
        if (k < 12)  return src[8*(11-k) +: 8];
        if (k == 12) return ethertype[15:8];
        if (k == 13) return ethertype[7:0];
        return 8'(base + k - 14);
    endfunction

    //----------------------------------------------------------------
    // Drivers. The parser tready is combinational on the demux
    // readies during the payload, hence the demux-bench mid-cycle
    // blocking drive with the settled negedge sample point.
    //----------------------------------------------------------------
    task automatic send_eth_frame(input logic [47:0] dst, input logic [47:0] src,
                                  input logic [15:0] ethertype, input integer nbytes,
                                  input logic [7:0] base);
        logic [7:0] b;
        logic       last, user;
        logic [1:0] sel;
        integer     total;

        sel   = model_sel(promiscuous, dst, ethertype, {16'h0806, 16'h0800}, 2, 1'b0);
        total = 14 + nbytes;

        if (nbytes > 0) begin
            exp_seam[exp_seam_frames]       = {sel, dst, src, ethertype, 12'(nbytes)};
            exp_seam_beats[exp_seam_frames] = nbytes;
            exp_seam_frames                 = exp_seam_frames + 1;
        end

        s_length = 12'(total);

        for (int k = 0; k < total; k++) begin
            b = frame_byte(dst, src, ethertype, base, k);
            last = (k == total - 1);
            user = $urandom_range(0, 7) == 0;
            if (k >= 14 && 32'(sel) < 2) begin
                push_exp(32'(sel), ethertype, last, user, b);
            end
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

    // A frame dying inside its header: no expectation anywhere
    task automatic send_runt(input integer nbytes);
        s_length = 12'(nbytes);
        for (int k = 0; k < nbytes; k++) begin
            @(negedge clock);
            s_tvalid = 1'b1;
            s_tdata  = 8'($urandom);
            s_tlast  = (k == nbytes - 1);
            s_tuser  = 1'b0;
            #1;
            while (s_tready !== 1'b1) begin
                @(negedge clock);
                #1;
            end
            @(posedge clock);
        end
        s_tvalid <= 1'b0;
        s_tlast  <= 1'b0;
    endtask

    task automatic p1_send_frame(input logic [47:0] dst, input logic [47:0] src,
                                 input logic [15:0] ethertype, input integer nbytes,
                                 input logic [7:0] base);
        logic [7:0] b;
        logic       last, user;
        logic       sel;
        integer     total;

        sel   = 1'(model_sel(p1_promiscuous, dst, ethertype, {16'h0000, 16'h0800}, 1, 1'b1));
        total = 14 + nbytes;

        if (nbytes > 0) begin
            p1_exp_hdr[p1_exp_frames]   = {sel, dst, src, ethertype, 8'(nbytes)};
            p1_exp_beats[p1_exp_frames] = nbytes;
            p1_exp_frames               = p1_exp_frames + 1;
        end

        p1_s_length = 8'(total);

        for (int k = 0; k < total; k++) begin
            b = frame_byte(dst, src, ethertype, base, k);
            last = (k == total - 1);
            user = $urandom_range(0, 7) == 0;
            if (k >= 14) begin
                // The bare parser emits every payload beat, the
                // discard code is only a select
                p1_exp[p1_exp_count] = {last, user, b};
                p1_exp_count = p1_exp_count + 1;
            end
            @(negedge clock);
            p1_s_tvalid = 1'b1;
            p1_s_tdata  = b;
            p1_s_tlast  = last;
            p1_s_tuser  = user;
            #1;
            while (p1_s_tready !== 1'b1) begin
                @(negedge clock);
                #1;
            end
            @(posedge clock);
        end
        p1_s_tvalid <= 1'b0;
        p1_s_tlast  <= 1'b0;
        p1_s_tuser  <= 1'b0;
    endtask

    //----------------------------------------------------------------
    // Test sequence
    //----------------------------------------------------------------
    logic [47:0] soak_dst;
    logic [15:0] soak_et;
    integer      soak_nbytes;

    initial begin
        s_tvalid = 1'b0; s_tdata = '0; s_tlast = 1'b0; s_tuser = 1'b0;
        s_length = '0; promiscuous = 1'b0;
        p1_s_tvalid = 1'b0; p1_s_tdata = '0; p1_s_tlast = 1'b0; p1_s_tuser = 1'b0;
        p1_s_length = '0; p1_promiscuous = 1'b0;

        wait (sreset === 1'b0);
        @(posedge clock);

        // The two handled protocols, minimum real frame first
        send_eth_frame(LOCAL_MAC, REMOTE_MAC, 16'h0800, 46, 8'h10);
        send_eth_frame(BCAST_MAC, REMOTE_MAC, 16'h0806, 46, 8'h20);
        send_eth_frame(BCAST_MAC, REMOTE_MAC, 16'h0800, 5, 8'h30);
        send_eth_frame(LOCAL_MAC, REMOTE_MAC, 16'h0806, 1, 8'h80);

        // Unknown EtherType, foreign unicast DA, and a multicast group
        // with ACCEPT_MULTICAST off: the discard code
        send_eth_frame(LOCAL_MAC, REMOTE_MAC, 16'h86DD, 20, 8'h40);
        send_eth_frame(FOREIGN_MAC, REMOTE_MAC, 16'h0800, 20, 8'h50);
        send_eth_frame(MCAST_MAC, REMOTE_MAC, 16'h0800, 12, 8'h55);

        // The promiscuous bit reopens the foreign DA
        promiscuous = 1'b1;
        send_eth_frame(FOREIGN_MAC, REMOTE_MAC, 16'h0800, 8, 8'h60);
        send_eth_frame(FOREIGN_MAC, REMOTE_MAC, 16'h0806, 3, 8'h70);
        promiscuous = 1'b0;

        // Runts, the headers-only 14-byte frame included, then recovery
        send_runt(1);
        send_runt(7);
        send_runt(13);
        send_eth_frame(LOCAL_MAC, REMOTE_MAC, 16'h0800, 0, 8'h00);
        send_eth_frame(LOCAL_MAC, REMOTE_MAC, 16'h0800, 4, 8'h90);

        // Random soak across DAs, EtherTypes, lengths and gaps
        for (int f = 0; f < 40; f++) begin
            case ($urandom_range(0, 4))
                0: soak_dst = LOCAL_MAC;
                1: soak_dst = BCAST_MAC;
                2: soak_dst = MCAST_MAC;
                default: soak_dst = {16'($urandom), $urandom};
            endcase
            case ($urandom_range(0, 3))
                0: soak_et = 16'h0800;
                1: soak_et = 16'h0806;
                default: soak_et = 16'($urandom);
            endcase
            promiscuous = $urandom_range(0, 1) == 1;
            soak_nbytes = $urandom_range(1, 64);
            send_eth_frame(soak_dst, REMOTE_MAC, soak_et, soak_nbytes, 8'($urandom));
            repeat ($urandom_range(0, 2)) @(posedge clock);
        end
        repeat (80) @(posedge clock);

        // Sweep instance: single EtherType, narrow length counter,
        // multicast accepted through the I/G bit
        p1_send_frame(LOCAL_MAC, REMOTE_MAC, 16'h0800, 6, 8'hA0);
        p1_send_frame(LOCAL_MAC, REMOTE_MAC, 16'h0806, 6, 8'hB0);
        p1_send_frame(FOREIGN_MAC, REMOTE_MAC, 16'h0800, 6, 8'hC0);
        p1_send_frame(MCAST_MAC, REMOTE_MAC, 16'h0800, 6, 8'hC8);
        p1_send_frame(BCAST_MAC, REMOTE_MAC, 16'h0800, 200, 8'hD0);
        p1_send_frame(LOCAL_MAC, REMOTE_MAC, 16'h0800, 0, 8'h00);
        p1_send_frame(LOCAL_MAC, REMOTE_MAC, 16'h0800, 3, 8'hE0);
        repeat (60) @(posedge clock);

        if (mon_idx[0] != exp_count[0] || mon_idx[1] != exp_count[1]) begin
            errors = errors + 1;
            $error("demux streams incomplete: %0d/%0d %0d/%0d",
                   mon_idx[0], exp_count[0], mon_idx[1], exp_count[1]);
        end
        if (seam_frame_idx != exp_seam_frames) begin
            errors = errors + 1;
            $error("seam incomplete: %0d/%0d frames", seam_frame_idx, exp_seam_frames);
        end
        if (p1_mon_idx != p1_exp_count || p1_frame_idx != p1_exp_frames) begin
            errors = errors + 1;
            $error("sweep stream incomplete: %0d/%0d beats, %0d/%0d frames",
                   p1_mon_idx, p1_exp_count, p1_frame_idx, p1_exp_frames);
        end

        if (errors == 0)
          $display("axi_stream_eth_parser_tb: ALL TESTS PASSED");
        else
          $display("axi_stream_eth_parser_tb: %0d ERROR(S)", errors);
        $finish;
    end

    // Watchdog: a stalled discard path hangs the driver forever
    initial begin
        #600000;
        errors = errors + 1;
        $error("watchdog: %0d/%0d %0d/%0d seam %0d/%0d p1 %0d/%0d",
               mon_idx[0], exp_count[0], mon_idx[1], exp_count[1],
               seam_frame_idx, exp_seam_frames, p1_mon_idx, p1_exp_count);
        $display("axi_stream_eth_parser_tb: %0d ERROR(S)", errors);
        $finish;
    end

    //----------------------------------------------------------------
    // Seam monitor: every side-band field on every payload beat
    //----------------------------------------------------------------
    initial begin
        exp_count[0] = 0; exp_count[1] = 0;
        mon_idx[0] = 0; mon_idx[1] = 0;
        exp_seam_frames = 0; seam_frame_idx = 0; seam_beat_cnt = 0;
        p1_exp_frames = 0; p1_frame_idx = 0; p1_beat_cnt = 0;
        p1_exp_count = 0; p1_mon_idx = 0;
    end

    always @(posedge clock) begin
        if (sreset === 1'b0 && pd_tvalid === 1'b1 && pd_tready === 1'b1) begin
            if (seam_frame_idx >= exp_seam_frames) begin
                errors = errors + 1;
                $error("seam: unexpected frame, beat %02x", pd_tdata);
            end
            else begin
                if ({pd_sel, pd_dst, pd_src, pd_ethertype, pd_length}
                    !== exp_seam[seam_frame_idx]) begin
                    errors = errors + 1;
                    $error("seam frame %0d: sel=%0d dst=%012x src=%012x type=%04x len=%0d",
                           seam_frame_idx, pd_sel, pd_dst, pd_src, pd_ethertype, pd_length);
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

    //----------------------------------------------------------------
    // Demux output monitors
    //----------------------------------------------------------------
    always @(posedge clock) begin
        if (sreset === 1'b0 && m_tvalid[0] === 1'b1 && m_tready[0] === 1'b1) begin
            if (mon_idx[0] >= exp_count[0]) begin
                errors = errors + 1;
                $error("out0: unexpected beat %02x", m_tdata[7:0]);
            end
            else if ({m_info, m_tlast[0], m_tuser[0], m_tdata[7:0]} !== exp0[mon_idx[0]]) begin
                errors = errors + 1;
                $error("out0 beat %0d mismatch", mon_idx[0]);
            end
            mon_idx[0] = mon_idx[0] + 1;
        end
    end

    always @(posedge clock) begin
        if (sreset === 1'b0 && m_tvalid[1] === 1'b1 && m_tready[1] === 1'b1) begin
            if (mon_idx[1] >= exp_count[1]) begin
                errors = errors + 1;
                $error("out1: unexpected beat %02x", m_tdata[15:8]);
            end
            else if ({m_info, m_tlast[1], m_tuser[1], m_tdata[15:8]} !== exp1[mon_idx[1]]) begin
                errors = errors + 1;
                $error("out1 beat %0d mismatch", mon_idx[1]);
            end
            mon_idx[1] = mon_idx[1] + 1;
        end
    end

    //----------------------------------------------------------------
    // Sweep instance monitor: side-band per frame, beats compared
    //----------------------------------------------------------------
    always @(posedge clock) begin
        if (sreset === 1'b0 && p1_m_tvalid === 1'b1 && p1_m_tready === 1'b1) begin
            if (p1_frame_idx >= p1_exp_frames || p1_mon_idx >= p1_exp_count) begin
                errors = errors + 1;
                $error("sweep: unexpected beat %02x", p1_m_tdata);
            end
            else begin
                if ({p1_sel, p1_dst, p1_src, p1_ethertype, p1_length}
                    !== p1_exp_hdr[p1_frame_idx]) begin
                    errors = errors + 1;
                    $error("sweep frame %0d: sel=%0d dst=%012x src=%012x type=%04x len=%0d",
                           p1_frame_idx, p1_sel, p1_dst, p1_src, p1_ethertype, p1_length);
                end
                if ({p1_m_tlast, p1_m_tuser, p1_m_tdata} !== p1_exp[p1_mon_idx]) begin
                    errors = errors + 1;
                    $error("sweep beat %0d mismatch", p1_mon_idx);
                end
                p1_mon_idx  = p1_mon_idx + 1;
                p1_beat_cnt = p1_beat_cnt + 1;
                if (p1_m_tlast === 1'b1) begin
                    if (p1_beat_cnt != p1_exp_beats[p1_frame_idx]) begin
                        errors = errors + 1;
                        $error("sweep frame %0d: %0d beats, expected %0d",
                               p1_frame_idx, p1_beat_cnt, p1_exp_beats[p1_frame_idx]);
                    end
                    p1_beat_cnt  = 0;
                    p1_frame_idx = p1_frame_idx + 1;
                end
            end
        end
    end

endmodule
