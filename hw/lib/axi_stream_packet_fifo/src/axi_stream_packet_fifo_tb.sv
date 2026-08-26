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
// Title         : AXI Stream Packet FIFO Testbench
//-----------------------------------------------------------------------------
// File          : axi_stream_packet_fifo_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-24
// Last modified : 2026-08-24
//-----------------------------------------------------------------------------
// Description :
// Testbench of the AXI Stream Packet FIFO, sweeping the configuration
// space with three instances. A lossless one (DROP_ON_FULL=0, 16 beats, 4
// frames) covers commit, rollback on tuser (at tlast and mid-frame),
// pointer wraparound, info/length delivery, and writer stalls on both a
// full data FIFO and a full info FIFO -- every clean frame must come out.
// A drop one (DROP_ON_FULL=1) checks that tready never falls, that a
// frame meeting a full FIFO vanishes whole while committed neighbours
// survive, and that an oversize frame is disposed of. A narrow 2-bit
// instance proves the width generic. Readers apply random backpressure
// and every output beat, tlast, info and length is compared.

`timescale 1 ns / 100 ps

module axi_stream_packet_fifo_tb;

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
    // Lossless instance: 16 beats, 4 frames, 4-bit info
    //----------------------------------------------------------------
    logic [7:0] mn_s_tdata;
    logic       mn_s_tuser;
    logic       mn_s_tvalid;
    logic       mn_s_tlast;
    logic       mn_s_tready;
    logic [3:0] mn_s_info;
    logic [7:0] mn_m_tdata;
    logic       mn_m_tvalid;
    logic       mn_m_tlast;
    logic       mn_m_tready;
    logic [3:0] mn_m_info;
    logic [4:0] mn_m_length;
    logic       mn_reader_en;
    logic       mn_force_ready;

    axi_stream_packet_fifo
    #(
        .DATA_WIDTH   (8),
        .LOG2_DEPTH   (4),
        .LOG2_FRAMES  (2),
        .INFO_WIDTH   (4),
        .DROP_ON_FULL (0)
    )
    axi_stream_packet_fifo_mn_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (mn_s_tdata),
        .s_axi_tuser  (mn_s_tuser),
        .s_axi_tvalid (mn_s_tvalid),
        .s_axi_tlast  (mn_s_tlast),
        .s_axi_tready (mn_s_tready),
        .s_info       (mn_s_info),
        .m_axi_tdata  (mn_m_tdata),
        .m_axi_tvalid (mn_m_tvalid),
        .m_axi_tlast  (mn_m_tlast),
        .m_axi_tready (mn_m_tready),
        .m_info       (mn_m_info),
        .m_length     (mn_m_length)
    );

    //----------------------------------------------------------------
    // Drop instance: same sizes, never stalls
    //----------------------------------------------------------------
    logic [7:0] dr_s_tdata;
    logic       dr_s_tuser;
    logic       dr_s_tvalid;
    logic       dr_s_tlast;
    logic       dr_s_tready;
    logic [3:0] dr_s_info;
    logic [7:0] dr_m_tdata;
    logic       dr_m_tvalid;
    logic       dr_m_tlast;
    logic       dr_m_tready;
    logic [3:0] dr_m_info;
    logic [4:0] dr_m_length;
    logic       dr_reader_en;

    axi_stream_packet_fifo
    #(
        .DATA_WIDTH   (8),
        .LOG2_DEPTH   (4),
        .LOG2_FRAMES  (2),
        .INFO_WIDTH   (4),
        .DROP_ON_FULL (1)
    )
    axi_stream_packet_fifo_dr_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (dr_s_tdata),
        .s_axi_tuser  (dr_s_tuser),
        .s_axi_tvalid (dr_s_tvalid),
        .s_axi_tlast  (dr_s_tlast),
        .s_axi_tready (dr_s_tready),
        .s_info       (dr_s_info),
        .m_axi_tdata  (dr_m_tdata),
        .m_axi_tvalid (dr_m_tvalid),
        .m_axi_tlast  (dr_m_tlast),
        .m_axi_tready (dr_m_tready),
        .m_info       (dr_m_info),
        .m_length     (dr_m_length)
    );

    //----------------------------------------------------------------
    // Narrow instance: 2-bit data
    //----------------------------------------------------------------
    logic [1:0] nw_s_tdata;
    logic       nw_s_tuser;
    logic       nw_s_tvalid;
    logic       nw_s_tlast;
    logic       nw_s_tready;
    logic [1:0] nw_m_tdata;
    logic       nw_m_tvalid;
    logic       nw_m_tlast;
    logic       nw_m_tready;
    logic       nw_m_info;
    logic [5:0] nw_m_length;

    axi_stream_packet_fifo
    #(
        .DATA_WIDTH   (2),
        .LOG2_DEPTH   (5),
        .LOG2_FRAMES  (3),
        .INFO_WIDTH   (1),
        .DROP_ON_FULL (0)
    )
    axi_stream_packet_fifo_nw_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (nw_s_tdata),
        .s_axi_tuser  (nw_s_tuser),
        .s_axi_tvalid (nw_s_tvalid),
        .s_axi_tlast  (nw_s_tlast),
        .s_axi_tready (nw_s_tready),
        .s_info       (1'b0),
        .m_axi_tdata  (nw_m_tdata),
        .m_axi_tvalid (nw_m_tvalid),
        .m_axi_tlast  (nw_m_tlast),
        .m_axi_tready (nw_m_tready),
        .m_info       (nw_m_info),
        .m_length     (nw_m_length)
    );

    //----------------------------------------------------------------
    // Random backpressure, gated per reader
    //----------------------------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            mn_m_tready <= 1'b0;
            dr_m_tready <= 1'b0;
            nw_m_tready <= 1'b0;
        end
        else begin
            mn_m_tready <= (mn_reader_en && $urandom_range(0, 1) == 1) || mn_force_ready;
            dr_m_tready <= dr_reader_en && $urandom_range(0, 1) == 1;
            nw_m_tready <= $urandom_range(0, 1) == 1;
        end
    end

    //----------------------------------------------------------------
    // Expected streams: beats {last, data} plus per-frame info/length
    //----------------------------------------------------------------
    logic [8:0] mn_exp [0:511];
    logic [3:0] mn_exp_info [0:63];
    integer     mn_exp_len [0:63];
    integer     mn_exp_count = 0;
    integer     mn_exp_frames = 0;
    integer     mn_mon_idx = 0;
    integer     mn_frame_idx = 0;

    logic [8:0] dr_exp [0:511];
    logic [3:0] dr_exp_info [0:63];
    integer     dr_exp_len [0:63];
    integer     dr_exp_count = 0;
    integer     dr_exp_frames = 0;
    integer     dr_mon_idx = 0;
    integer     dr_frame_idx = 0;

    logic [2:0] nw_exp [0:127];
    integer     nw_exp_len [0:15];
    integer     nw_exp_count = 0;
    integer     nw_exp_frames = 0;
    integer     nw_mon_idx = 0;
    integer     nw_frame_idx = 0;

    //----------------------------------------------------------------
    // Drivers
    //----------------------------------------------------------------
    // The beat is presented mid-cycle with blocking assignments and
    // tready sampled right after: this FIFO's tready is combinational
    // and may change on the accept edge itself, and simulators disagree
    // on which side of a posedge a resumed process reads -- mid-cycle
    // everything is settled and they all agree.
    task automatic mn_send_beat(input logic [7:0] data, input logic last, input logic user);
        @(negedge clock);
        mn_s_tvalid = 1'b1;
        mn_s_tdata  = data;
        mn_s_tlast  = last;
        mn_s_tuser  = user;
        #1;
        while (mn_s_tready !== 1'b1) begin
            @(negedge clock);
            #1;
        end
        @(posedge clock);
    endtask

    // A clean frame of nbeats bytes base+i, expected back unchanged
    task automatic mn_send_frame(input integer nbeats, input logic [7:0] base,
                                 input logic [3:0] info);
        for (int i = 0; i < nbeats; i++) begin
            mn_exp[mn_exp_count] = {i == nbeats-1, 8'(base + i)};
            mn_exp_count = mn_exp_count + 1;
        end
        mn_exp_info[mn_exp_frames] = info;
        mn_exp_len[mn_exp_frames]  = nbeats;
        mn_exp_frames = mn_exp_frames + 1;
        mn_s_info <= info;
        for (int i = 0; i < nbeats; i++) begin
            mn_send_beat(8'(base + i), i == nbeats-1, 1'b0);
        end
        mn_s_tvalid <= 1'b0;
        mn_s_tlast  <= 1'b0;
    endtask

    task automatic dr_send_beat(input logic [7:0] data, input logic last, input logic user);
        @(negedge clock);
        dr_s_tvalid = 1'b1;
        dr_s_tdata  = data;
        dr_s_tlast  = last;
        dr_s_tuser  = user;
        #1;
        while (dr_s_tready !== 1'b1) begin
            @(negedge clock);
            #1;
        end
        @(posedge clock);
    endtask

    task automatic dr_send_frame(input integer nbeats, input logic [7:0] base,
                                 input logic [3:0] info, input logic expected);
        if (expected) begin
            for (int i = 0; i < nbeats; i++) begin
                dr_exp[dr_exp_count] = {i == nbeats-1, 8'(base + i)};
                dr_exp_count = dr_exp_count + 1;
            end
            dr_exp_info[dr_exp_frames] = info;
            dr_exp_len[dr_exp_frames]  = nbeats;
            dr_exp_frames = dr_exp_frames + 1;
        end
        dr_s_info <= info;
        for (int i = 0; i < nbeats; i++) begin
            dr_send_beat(8'(base + i), i == nbeats-1, 1'b0);
        end
        dr_s_tvalid <= 1'b0;
        dr_s_tlast  <= 1'b0;
    endtask

    task automatic nw_send_beat(input logic [1:0] data, input logic last, input logic user);
        @(negedge clock);
        nw_s_tvalid = 1'b1;
        nw_s_tdata  = data;
        nw_s_tlast  = last;
        nw_s_tuser  = user;
        #1;
        while (nw_s_tready !== 1'b1) begin
            @(negedge clock);
            #1;
        end
        @(posedge clock);
    endtask

    task automatic nw_send_frame(input integer nbeats, input integer base);
        for (int i = 0; i < nbeats; i++) begin
            nw_exp[nw_exp_count] = {i == nbeats-1, 2'(base + i)};
            nw_exp_count = nw_exp_count + 1;
        end
        nw_exp_len[nw_exp_frames] = nbeats;
        nw_exp_frames = nw_exp_frames + 1;
        for (int i = 0; i < nbeats; i++) begin
            nw_send_beat(2'(base + i), i == nbeats-1, 1'b0);
        end
        nw_s_tvalid <= 1'b0;
        nw_s_tlast  <= 1'b0;
    endtask

    //----------------------------------------------------------------
    // Stall helpers: re-enable the reader while the driver is blocked
    // in a send task, so the lossless writer stalls are exercised
    //----------------------------------------------------------------
    logic stall1 = 1'b0;
    logic stall2 = 1'b0;

    initial begin
        wait (stall1);
        repeat (60) @(posedge clock);
        mn_reader_en = 1'b1;
        wait (stall2);
        repeat (60) @(posedge clock);
        mn_reader_en = 1'b1;
    end

    // Both stall scenarios must actually block the writer: a beat held
    // with tready low. Without this the sequences pass even if the full
    // detection is broken, since every frame still flows.
    integer mn_stall_count = 0;
    integer stall_mark = 0;

    always @(posedge clock) begin
        if (sreset === 1'b0 && mn_s_tvalid === 1'b1 && mn_s_tready === 1'b0) begin
            mn_stall_count = mn_stall_count + 1;
        end
    end

    //----------------------------------------------------------------
    // Test sequence
    //----------------------------------------------------------------
    initial begin
        mn_s_tvalid = 1'b0; mn_s_tdata = '0; mn_s_tlast = 1'b0; mn_s_tuser = 1'b0;
        mn_s_info = '0; mn_reader_en = 1'b1; mn_force_ready = 1'b0;
        dr_s_tvalid = 1'b0; dr_s_tdata = '0; dr_s_tlast = 1'b0; dr_s_tuser = 1'b0;
        dr_s_info = '0; dr_reader_en = 1'b0;
        nw_s_tvalid = 1'b0; nw_s_tdata = '0; nw_s_tlast = 1'b0; nw_s_tuser = 1'b0;

        wait (sreset === 1'b0);
        @(posedge clock);

        //--- Lossless instance ---------------------------------------
        // Clean frames back to back, the third fills the whole FIFO
        mn_send_frame(5, 8'h10, 4'h3);
        mn_send_frame(1, 8'hA0, 4'h7);
        mn_send_frame(16, 8'h40, 4'hC);

        // Rollback on tuser with tlast: the frame vanishes
        mn_send_beat(8'hE0, 1'b0, 1'b0);
        mn_send_beat(8'hE1, 1'b0, 1'b0);
        mn_send_beat(8'hE2, 1'b0, 1'b0);
        mn_send_beat(8'hE3, 1'b1, 1'b1);
        mn_s_tvalid <= 1'b0; mn_s_tlast <= 1'b0; mn_s_tuser <= 1'b0;

        // Mid-frame tuser: the rest is drained, the frame vanishes
        mn_send_beat(8'hF0, 1'b0, 1'b0);
        mn_send_beat(8'hF1, 1'b0, 1'b0);
        mn_send_beat(8'hF2, 1'b0, 1'b1);
        mn_send_beat(8'hF3, 1'b0, 1'b0);
        mn_send_beat(8'hF4, 1'b1, 1'b0);
        mn_s_tvalid <= 1'b0; mn_s_tlast <= 1'b0; mn_s_tuser <= 1'b0;

        // Clean frame after the rollbacks
        mn_send_frame(4, 8'h60, 4'h9);

        // Wraparound: 30 more beats through a 16-beat FIFO
        for (int f = 0; f < 6; f++) begin
            mn_send_frame(5, 8'(8'h20 + 16*f), 4'(f));
        end

        // Writer stall on a full data FIFO: reader off, three frames
        // committed, the fourth blocks mid-frame until the helper
        // re-enables the reader. Lossless: everything must come out.
        // The FIFO is fully drained first, so the stall point is the
        // one the frames below construct, not leftover backlog.
        wait (mn_mon_idx == mn_exp_count);
        mn_reader_en = 1'b0;
        repeat (5) @(posedge clock);
        mn_send_frame(4, 8'h80, 4'h1);
        mn_send_frame(4, 8'h90, 4'h2);
        mn_send_frame(4, 8'hB0, 4'h3);
        stall1 = 1'b1;
        stall_mark = mn_stall_count;
        mn_send_frame(8, 8'hC0, 4'h4);
        if (mn_stall_count == stall_mark) begin
            errors = errors + 1;
            $error("the data-full scenario never stalled the writer");
        end

        // Writer stall on a full info FIFO: four one-beat frames fill
        // the frame capacity, the fifth blocks until the reader drains
        wait (mn_mon_idx == mn_exp_count);
        mn_reader_en = 1'b0;
        repeat (5) @(posedge clock);
        mn_send_frame(1, 8'h51, 4'h5);
        mn_send_frame(1, 8'h52, 4'h6);
        mn_send_frame(1, 8'h53, 4'h7);
        mn_send_frame(1, 8'h54, 4'h8);
        stall2 = 1'b1;
        stall_mark = mn_stall_count;
        mn_send_frame(1, 8'h55, 4'h9);
        if (mn_stall_count == stall_mark) begin
            errors = errors + 1;
            $error("the info-full scenario never stalled the writer");
        end
        repeat (60) @(posedge clock);

        // Reader caught up with tready held high: a one-beat frame lands
        // in a recycled slot and must fall through with the committed
        // data, not whatever the slot held before -- this pins the
        // valid-versus-RAM-latency alignment
        wait (mn_mon_idx == mn_exp_count);
        mn_force_ready = 1'b1;
        repeat (4) @(posedge clock);
        mn_send_frame(1, 8'h77, 4'hA);
        mn_send_frame(1, 8'h88, 4'hB);
        mn_send_frame(1, 8'h99, 4'hC);
        repeat (20) @(posedge clock);
        mn_force_ready = 1'b0;

        //--- Drop instance -------------------------------------------
        // Reader off: one frame commits, the next meets the full FIFO
        // mid-frame and must vanish whole, a third fits again
        dr_send_frame(4, 8'h30, 4'hA, 1'b1);
        dr_send_frame(20, 8'h70, 4'hB, 1'b0); // dropped on full
        dr_send_frame(3, 8'hD0, 4'hC, 1'b1);
        dr_reader_en = 1'b1;
        repeat (60) @(posedge clock);

        // Oversize frame with the reader running: dropped by the same
        // path, the next frame passes
        dr_send_frame(24, 8'h00, 4'hD, 1'b0); // larger than the FIFO
        dr_send_frame(17, 8'h48, 4'hF, 1'b0); // one beat past capacity: dropped
        dr_send_frame(5, 8'hE8, 4'hE, 1'b1);
        repeat (60) @(posedge clock);

        // A burst of one-beat frames against a full INFO FIFO: the data
        // FIFO has plenty of room, the fifth and sixth frame meet
        // !info_room and must vanish whole
        dr_reader_en = 1'b0;
        repeat (5) @(posedge clock);
        dr_send_frame(1, 8'h11, 4'h1, 1'b1);
        dr_send_frame(1, 8'h22, 4'h2, 1'b1);
        dr_send_frame(1, 8'h33, 4'h3, 1'b1);
        dr_send_frame(1, 8'h44, 4'h4, 1'b1);
        dr_send_frame(1, 8'h55, 4'h5, 1'b0); // dropped: info FIFO full
        dr_send_frame(1, 8'h66, 4'h6, 1'b0); // dropped: info FIFO full
        dr_reader_en = 1'b1;
        repeat (60) @(posedge clock);
        dr_send_frame(2, 8'h77, 4'h7, 1'b1); // recovery after the drops
        repeat (60) @(posedge clock);

        //--- Narrow instance -----------------------------------------
        nw_send_frame(3, 1);
        nw_send_frame(5, 2);
        repeat (60) @(posedge clock);

        //--- Verdict -------------------------------------------------
        if (mn_mon_idx != mn_exp_count || mn_frame_idx != mn_exp_frames) begin
            errors = errors + 1;
            $error("lossless stream incomplete: %0d/%0d beats, %0d/%0d frames",
                   mn_mon_idx, mn_exp_count, mn_frame_idx, mn_exp_frames);
        end
        if (dr_mon_idx != dr_exp_count || dr_frame_idx != dr_exp_frames) begin
            errors = errors + 1;
            $error("drop stream incomplete: %0d/%0d beats, %0d/%0d frames",
                   dr_mon_idx, dr_exp_count, dr_frame_idx, dr_exp_frames);
        end
        if (nw_mon_idx != nw_exp_count || nw_frame_idx != nw_exp_frames) begin
            errors = errors + 1;
            $error("narrow stream incomplete: %0d/%0d beats, %0d/%0d frames",
                   nw_mon_idx, nw_exp_count, nw_frame_idx, nw_exp_frames);
        end

        if (errors == 0)
          $display("axi_stream_packet_fifo_tb: ALL TESTS PASSED");
        else
          $display("axi_stream_packet_fifo_tb: %0d ERROR(S)", errors);
        $finish;
    end

    // Watchdog: a broken stall path would hang the sequence forever
    initial begin
        #1000000;
        errors = errors + 1;
        $error("watchdog: test sequence did not finish");
        $display("watchdog: mn %0d/%0d beats %0d/%0d frames, dr %0d/%0d, nw %0d/%0d",
                 mn_mon_idx, mn_exp_count, mn_frame_idx, mn_exp_frames,
                 dr_mon_idx, dr_exp_count, nw_mon_idx, nw_exp_count);
        $display("axi_stream_packet_fifo_tb: %0d ERROR(S)", errors);
        $finish;
    end

    //----------------------------------------------------------------
    // Check outputs
    //----------------------------------------------------------------
    always @(posedge clock) begin
        if (sreset === 1'b0 && mn_m_tvalid === 1'b1 && mn_m_tready === 1'b1) begin
            if (mn_mon_idx >= mn_exp_count) begin
                errors = errors + 1;
                $error("lossless: unexpected beat %02x at index %0d", mn_m_tdata, mn_mon_idx);
            end
            else begin
                if ({mn_m_tlast, mn_m_tdata} !== mn_exp[mn_mon_idx]) begin
                    errors = errors + 1;
                    $error("lossless beat %0d: got last=%b data=%02x, expected last=%b data=%02x",
                           mn_mon_idx, mn_m_tlast, mn_m_tdata,
                           mn_exp[mn_mon_idx][8], mn_exp[mn_mon_idx][7:0]);
                end
                if (mn_m_info !== mn_exp_info[mn_frame_idx]) begin
                    errors = errors + 1;
                    $error("lossless frame %0d: got info %h, expected %h",
                           mn_frame_idx, mn_m_info, mn_exp_info[mn_frame_idx]);
                end
                if (mn_m_length !== 5'(mn_exp_len[mn_frame_idx])) begin
                    errors = errors + 1;
                    $error("lossless frame %0d: got length %0d, expected %0d",
                           mn_frame_idx, mn_m_length, mn_exp_len[mn_frame_idx]);
                end
            end
            mn_mon_idx = mn_mon_idx + 1;
            if (mn_m_tlast === 1'b1) mn_frame_idx = mn_frame_idx + 1;
        end
    end

    always @(posedge clock) begin
        if (sreset === 1'b0 && dr_m_tvalid === 1'b1 && dr_m_tready === 1'b1) begin
            if (dr_mon_idx >= dr_exp_count) begin
                errors = errors + 1;
                $error("drop: unexpected beat %02x at index %0d", dr_m_tdata, dr_mon_idx);
            end
            else begin
                if ({dr_m_tlast, dr_m_tdata} !== dr_exp[dr_mon_idx]) begin
                    errors = errors + 1;
                    $error("drop beat %0d: got last=%b data=%02x, expected last=%b data=%02x",
                           dr_mon_idx, dr_m_tlast, dr_m_tdata,
                           dr_exp[dr_mon_idx][8], dr_exp[dr_mon_idx][7:0]);
                end
                if (dr_m_info !== dr_exp_info[dr_frame_idx]) begin
                    errors = errors + 1;
                    $error("drop frame %0d: got info %h, expected %h",
                           dr_frame_idx, dr_m_info, dr_exp_info[dr_frame_idx]);
                end
                if (dr_m_length !== 5'(dr_exp_len[dr_frame_idx])) begin
                    errors = errors + 1;
                    $error("drop frame %0d: got length %0d, expected %0d",
                           dr_frame_idx, dr_m_length, dr_exp_len[dr_frame_idx]);
                end
            end
            dr_mon_idx = dr_mon_idx + 1;
            if (dr_m_tlast === 1'b1) dr_frame_idx = dr_frame_idx + 1;
        end
    end

    // The drop instance must never backpressure
    always @(posedge clock) begin
        if (sreset === 1'b0 && dr_s_tready !== 1'b1) begin
            errors = errors + 1;
            $error("drop instance deasserted s_axi_tready");
        end
    end

    always @(posedge clock) begin
        if (sreset === 1'b0 && nw_m_tvalid === 1'b1 && nw_m_tready === 1'b1) begin
            if (nw_mon_idx >= nw_exp_count) begin
                errors = errors + 1;
                $error("narrow: unexpected beat %b at index %0d", nw_m_tdata, nw_mon_idx);
            end
            else begin
                if ({nw_m_tlast, nw_m_tdata} !== nw_exp[nw_mon_idx]) begin
                    errors = errors + 1;
                    $error("narrow beat %0d: got last=%b data=%b, expected last=%b data=%b",
                           nw_mon_idx, nw_m_tlast, nw_m_tdata,
                           nw_exp[nw_mon_idx][2], nw_exp[nw_mon_idx][1:0]);
                end
                if (nw_m_info !== 1'b0) begin
                    errors = errors + 1;
                    $error("narrow frame %0d: info raised, input is tied low", nw_frame_idx);
                end
                if (nw_m_length !== 6'(nw_exp_len[nw_frame_idx])) begin
                    errors = errors + 1;
                    $error("narrow frame %0d: got length %0d, expected %0d",
                           nw_frame_idx, nw_m_length, nw_exp_len[nw_frame_idx]);
                end
            end
            nw_mon_idx = nw_mon_idx + 1;
            if (nw_m_tlast === 1'b1) nw_frame_idx = nw_frame_idx + 1;
        end
    end

endmodule
