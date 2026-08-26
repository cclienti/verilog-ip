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
// Title         : AXI Stream Ethernet FCS Checker Testbench
//-----------------------------------------------------------------------------
// File          : axi_stream_eth_fcs_check_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-23
// Last modified : 2026-08-23
//-----------------------------------------------------------------------------
// Description :
// Testbench of the AXI Stream Ethernet FCS Checker. Directed tests feed
// frames whose FCS was computed offline with zlib.crc32 (good FCS, corrupt
// FCS, corrupt payload, runt frames, upstream tuser) and compare every
// output beat, tlast and tuser included, under random backpressure. A
// second checker chained behind an axi_stream_eth_fcs_gen instance closes
// the loop: random frames of assorted lengths must come back exactly as
// generated (padding included) with tuser never raised. Finally the full
// RMII chain of the family README (generator, downsizer, MAC tx, MAC rx,
// upsizer, checker, packet FIFO) is instantiated with its documented
// tuser/tkeep glue: clean frames must survive it byte for byte, a frame
// aborted mid-chain comes back flagged from the checker, and after the
// packet FIFO it has vanished entirely.

`timescale 1 ns / 100 ps

module axi_stream_eth_fcs_check_tb;
    //----------------------------------------------------------------
    // Constants
    //----------------------------------------------------------------
    localparam int MIN_FRAME_BYTES = 60;
    localparam int MAX_BEATS       = 2048;

    //----------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------
    logic       clock;
    logic       sreset;

    // Directed-test checker
    logic [7:0] chk_s_tdata;
    logic       chk_s_tuser;
    logic       chk_s_tvalid;
    logic       chk_s_tlast;
    logic       chk_s_tready;
    logic [7:0] chk_m_tdata;
    logic       chk_m_tuser;
    logic       chk_m_tvalid;
    logic       chk_m_tlast;
    logic       chk_m_tready;

    // Generator -> checker loopback chain
    logic [7:0] gen_s_tdata;
    logic       gen_s_tuser;
    logic       gen_s_tvalid;
    logic       gen_s_tlast;
    logic       gen_s_tready;
    logic [7:0] gen_m_tdata;
    logic       gen_m_tuser;
    logic       gen_m_tvalid;
    logic       gen_m_tlast;
    logic       gen_m_tready;
    logic [7:0] lp_m_tdata;
    logic       lp_m_tuser;
    logic       lp_m_tvalid;
    logic       lp_m_tlast;
    logic       lp_m_tready;

    integer     errors = 0;

    //----------------------------------------------------------------
    // DUT
    //----------------------------------------------------------------
    axi_stream_eth_fcs_check axi_stream_eth_fcs_check_inst (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (chk_s_tdata),
        .s_axi_tuser  (chk_s_tuser),
        .s_axi_tvalid (chk_s_tvalid),
        .s_axi_tlast  (chk_s_tlast),
        .s_axi_tready (chk_s_tready),
        .m_axi_tdata  (chk_m_tdata),
        .m_axi_tuser  (chk_m_tuser),
        .m_axi_tvalid (chk_m_tvalid),
        .m_axi_tlast  (chk_m_tlast),
        .m_axi_tready (chk_m_tready)
    );

    //----------------------------------------------------------------
    // Loopback: generator into a second checker
    //----------------------------------------------------------------
    axi_stream_eth_fcs_gen
    #(
        .MIN_FRAME_BYTES (MIN_FRAME_BYTES)
    )
    axi_stream_eth_fcs_gen_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (gen_s_tdata),
        .s_axi_tuser  (gen_s_tuser),
        .s_axi_tvalid (gen_s_tvalid),
        .s_axi_tlast  (gen_s_tlast),
        .s_axi_tready (gen_s_tready),
        .m_axi_tdata  (gen_m_tdata),
        .m_axi_tuser  (gen_m_tuser),
        .m_axi_tvalid (gen_m_tvalid),
        .m_axi_tlast  (gen_m_tlast),
        .m_axi_tready (gen_m_tready)
    );

    axi_stream_eth_fcs_check axi_stream_eth_fcs_check_lp_inst (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (gen_m_tdata),
        .s_axi_tuser  (gen_m_tuser),
        .s_axi_tvalid (gen_m_tvalid),
        .s_axi_tlast  (gen_m_tlast),
        .s_axi_tready (gen_m_tready),
        .m_axi_tdata  (lp_m_tdata),
        .m_axi_tuser  (lp_m_tuser),
        .m_axi_tvalid (lp_m_tvalid),
        .m_axi_tlast  (lp_m_tlast),
        .m_axi_tready (lp_m_tready)
    );

    //----------------------------------------------------------------
    // Full RMII chain: generator -> downsizer -> MAC tx -> MAC rx ->
    // upsizer -> checker, glued exactly as the family README documents
    //----------------------------------------------------------------
    logic [7:0] ch_s_tdata;
    logic       ch_s_tuser;
    logic       ch_s_tvalid;
    logic       ch_s_tlast;
    logic       ch_s_tready;

    logic [7:0] cg_m_tdata;
    logic       cg_m_tuser;
    logic       cg_m_tvalid;
    logic       cg_m_tlast;
    logic       cg_m_tready;

    logic [1:0] dz_m_tdata;
    logic       dz_m_tuser;
    logic       dz_m_tvalid;
    logic       dz_m_tlast;
    logic       dz_m_tready;

    logic [1:0] txd;
    logic       txen;

    logic [1:0] rx_m_tdata;
    logic       rx_m_tuser;
    logic       rx_m_tvalid;
    logic       rx_m_tlast;
    logic       rx_m_tready;

    logic [7:0] up_m_tdata;
    logic [3:0] up_m_tuser;
    logic [3:0] up_m_tkeep;
    logic       up_m_tvalid;
    logic       up_m_tlast;
    logic       up_m_tready;

    logic       chain_check_tuser;
    logic [7:0] cc_m_tdata;
    logic       cc_m_tuser;
    logic       cc_m_tvalid;
    logic       cc_m_tlast;
    logic       cc_m_tready;

    logic [7:0] pf_m_tdata;
    logic       pf_m_tvalid;
    logic       pf_m_tlast;
    logic       pf_m_tready;
    logic       pf_m_info;
    logic [8:0] pf_m_length;

    axi_stream_eth_fcs_gen
    #(
        .MIN_FRAME_BYTES (MIN_FRAME_BYTES)
    )
    chain_gen_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (ch_s_tdata),
        .s_axi_tuser  (ch_s_tuser),
        .s_axi_tvalid (ch_s_tvalid),
        .s_axi_tlast  (ch_s_tlast),
        .s_axi_tready (ch_s_tready),
        .m_axi_tdata  (cg_m_tdata),
        .m_axi_tuser  (cg_m_tuser),
        .m_axi_tvalid (cg_m_tvalid),
        .m_axi_tlast  (cg_m_tlast),
        .m_axi_tready (cg_m_tready)
    );

    axi_stream_downsizer
    #(
        .DOWNSIZE_RATIO (4),
        .OUT_DATA_WIDTH (2),
        .OUT_USER_WIDTH (1)
    )
    chain_downsizer_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (cg_m_tdata),
        .s_axi_tuser  ({4{cg_m_tuser}}), // one error bit replicated per dibit
        .s_axi_tvalid (cg_m_tvalid),
        .s_axi_tlast  (cg_m_tlast),
        .s_axi_tkeep  (4'b1111),         // frames are whole bytes
        .s_axi_tready (cg_m_tready),
        .m_axi_tdata  (dz_m_tdata),
        .m_axi_tuser  (dz_m_tuser),
        .m_axi_tvalid (dz_m_tvalid),
        .m_axi_tlast  (dz_m_tlast),
        .m_axi_tready (dz_m_tready)
    );

    rmii_mac_tx chain_mac_tx_inst (
        .clock      (clock),
        .srst       (sreset),
        .axi_tvalid (dz_m_tvalid),
        .axi_tlast  (dz_m_tlast),
        .axi_tdata  (dz_m_tdata),
        .axi_tuser  (dz_m_tuser),
        .axi_tready (dz_m_tready),
        .txd        (txd),
        .txen       (txen)
    );

    rmii_mac_rx chain_mac_rx_inst (
        .clock      (clock),
        .srst       (sreset),
        .rxd        (txd),
        .rxen       (txen),
        .axi_tvalid (rx_m_tvalid),
        .axi_tlast  (rx_m_tlast),
        .axi_tdata  (rx_m_tdata),
        .axi_tuser  (rx_m_tuser),
        .axi_tready (rx_m_tready)
    );

    axi_stream_upsizer
    #(
        .UPSIZE_RATIO  (4),
        .IN_DATA_WIDTH (2),
        .IN_USER_WIDTH (1)
    )
    chain_upsizer_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (rx_m_tdata),
        .s_axi_tuser  (rx_m_tuser),
        .s_axi_tvalid (rx_m_tvalid),
        .s_axi_tlast  (rx_m_tlast),
        .s_axi_tready (rx_m_tready),
        .m_axi_tdata  (up_m_tdata),
        .m_axi_tuser  (up_m_tuser),
        .m_axi_tvalid (up_m_tvalid),
        .m_axi_tlast  (up_m_tlast),
        .m_axi_tkeep  (up_m_tkeep),
        .m_axi_tready (up_m_tready)
    );

    // The glue the family README documents: the per-dibit error bits
    // reduce to one flag, and a frame whose last byte came back
    // incomplete from the wire is flagged as well
    assign chain_check_tuser = |up_m_tuser || (up_m_tlast && up_m_tkeep != 4'b1111);

    axi_stream_eth_fcs_check chain_check_inst (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (up_m_tdata),
        .s_axi_tuser  (chain_check_tuser),
        .s_axi_tvalid (up_m_tvalid),
        .s_axi_tlast  (up_m_tlast),
        .s_axi_tready (up_m_tready),
        .m_axi_tdata  (cc_m_tdata),
        .m_axi_tuser  (cc_m_tuser),
        .m_axi_tvalid (cc_m_tvalid),
        .m_axi_tlast  (cc_m_tlast),
        .m_axi_tready (cc_m_tready)
    );

    // The packet FIFO ends the receive chain: flagged frames vanish and
    // the consumer only ever parses complete valid frames. DROP_ON_FULL
    // keeps its tready at one, which the MAC rx path requires.
    axi_stream_packet_fifo
    #(
        .DATA_WIDTH   (8),
        .LOG2_DEPTH   (8),
        .LOG2_FRAMES  (3),
        .INFO_WIDTH   (1),
        .DROP_ON_FULL (1)
    )
    chain_packet_fifo_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (cc_m_tdata),
        .s_axi_tuser  (cc_m_tuser),
        .s_axi_tvalid (cc_m_tvalid),
        .s_axi_tlast  (cc_m_tlast),
        .s_axi_tready (cc_m_tready),
        .s_info       (1'b0),
        .m_axi_tdata  (pf_m_tdata),
        .m_axi_tvalid (pf_m_tvalid),
        .m_axi_tlast  (pf_m_tlast),
        .m_axi_tready (pf_m_tready),
        .m_info       (pf_m_info),
        .m_length     (pf_m_length)
    );

    //----------------------------------------------------------------
    // Clock and reset generation
    //----------------------------------------------------------------
    initial begin
        clock       = 0;
        sreset      = 1;
        #40 sreset  = 0;
    end

    always
        #10 clock = !clock;

    //----------------------------------------------------------------
    // Random backpressure on both output sides
    //----------------------------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            chk_m_tready <= 1'b1;
            lp_m_tready  <= 1'b1;
            pf_m_tready  <= 1'b1;
        end
        else begin
            chk_m_tready <= $urandom_range(0, 1) == 1 ? 1'b1 : 1'b0;
            lp_m_tready  <= $urandom_range(0, 1) == 1 ? 1'b1 : 1'b0;
            pf_m_tready  <= $urandom_range(0, 1) == 1 ? 1'b1 : 1'b0;
        end
    end

    //----------------------------------------------------------------
    // Expected output beats: {last, user, data}
    //----------------------------------------------------------------
    logic [9:0] exp_chk [0:MAX_BEATS-1];
    integer     exp_chk_count = 0;
    integer     chk_mon_idx = 0;

    logic [9:0] exp_lp [0:MAX_BEATS-1];
    integer     exp_lp_count = 0;
    integer     lp_mon_idx = 0;

    //----------------------------------------------------------------
    // Directed-test driver
    //----------------------------------------------------------------
    logic [7:0] chk_in_bytes [0:127];

    task automatic chk_send_beat(input logic [7:0] data, input logic last, input logic user);
        chk_s_tvalid <= 1'b1;
        chk_s_tdata  <= data;
        chk_s_tlast  <= last;
        chk_s_tuser  <= user;
        @(posedge clock);
        while (chk_s_tready !== 1'b1) @(posedge clock);
    endtask

    task automatic chk_idle(input integer cycles);
        chk_s_tvalid <= 1'b0;
        chk_s_tlast  <= 1'b0;
        chk_s_tuser  <= 1'b0;
        repeat (cycles) @(posedge clock);
    endtask

    // Send chk_in_bytes[0:ntotal-1] (FCS included) as one frame; expect
    // the first ntotal-4 bytes back, tuser on tlast when exp_user is set.
    // A frame of 4 bytes or fewer must produce nothing. An input tuser is
    // raised on beat user_beat when it is 0 or more.
    task automatic chk_send_frame(input integer ntotal, input logic exp_user,
                                  input integer user_beat);
        for (int i = 0; i < ntotal-4; i++) begin
            exp_chk[exp_chk_count] = {i == ntotal-5, (i == ntotal-5) && exp_user,
                                      chk_in_bytes[i]};
            exp_chk_count = exp_chk_count + 1;
        end
        for (int i = 0; i < ntotal; i++) begin
            chk_send_beat(chk_in_bytes[i], i == ntotal-1, i == user_beat);
        end
        chk_s_tvalid <= 1'b0;
        chk_s_tlast  <= 1'b0;
        chk_s_tuser  <= 1'b0;
    endtask

    task automatic load_frame_k;  // 20-byte payload, FCS from zlib.crc32
        for (int i = 0; i < 20; i++) chk_in_bytes[i] = 8'(5*i + 1);
        chk_in_bytes[20] = 8'hC8;
        chk_in_bytes[21] = 8'h85;
        chk_in_bytes[22] = 8'h3A;
        chk_in_bytes[23] = 8'hEB;
    endtask

    //----------------------------------------------------------------
    // Loopback driver
    //----------------------------------------------------------------
    logic [7:0] lp_bytes [0:127];

    task automatic gen_send_beat(input logic [7:0] data, input logic last);
        gen_s_tvalid <= 1'b1;
        gen_s_tdata  <= data;
        gen_s_tlast  <= last;
        gen_s_tuser  <= 1'b0;
        @(posedge clock);
        while (gen_s_tready !== 1'b1) @(posedge clock);
    endtask

    // Random frame through generator and checker: it must come back as
    // sent, zero-padded to MIN_FRAME_BYTES, with tuser never raised
    task automatic lp_send_frame(input integer nbytes);
        integer nout;
        nout = (nbytes < MIN_FRAME_BYTES) ? MIN_FRAME_BYTES : nbytes;
        for (int i = 0; i < nbytes; i++) lp_bytes[i] = 8'($urandom);
        for (int i = nbytes; i < nout; i++) lp_bytes[i] = 8'h00;
        for (int i = 0; i < nout; i++) begin
            exp_lp[exp_lp_count] = {i == nout-1, 1'b0, lp_bytes[i]};
            exp_lp_count = exp_lp_count + 1;
        end
        for (int i = 0; i < nbytes; i++) begin
            gen_send_beat(lp_bytes[i], i == nbytes-1);
        end
        gen_s_tvalid <= 1'b0;
        gen_s_tlast  <= 1'b0;
    endtask

    //----------------------------------------------------------------
    // Full-chain driver
    //----------------------------------------------------------------
    logic [9:0] exp_cc [0:MAX_BEATS-1];
    integer     exp_cc_count = 0;
    integer     cc_mon_idx = 0;

    task automatic push_cc(input logic last, input logic user, input logic [7:0] data);
        exp_cc[exp_cc_count] = {last, user, data};
        exp_cc_count = exp_cc_count + 1;
    endtask

    logic [8:0] exp_pf [0:MAX_BEATS-1];
    integer     exp_pf_len [0:15];
    integer     exp_pf_count = 0;
    integer     exp_pf_frames = 0;
    integer     pf_mon_idx = 0;
    integer     pf_frame_idx = 0;

    task automatic ch_send_beat(input logic [7:0] data, input logic last, input logic user);
        ch_s_tvalid <= 1'b1;
        ch_s_tdata  <= data;
        ch_s_tlast  <= last;
        ch_s_tuser  <= user;
        @(posedge clock);
        while (ch_s_tready !== 1'b1) @(posedge clock);
    endtask

    // A clean frame through the whole chain comes back zero-padded to
    // MIN_FRAME_BYTES with tuser never raised
    task automatic ch_send_frame(input integer nbytes);
        integer nout;
        nout = (nbytes < MIN_FRAME_BYTES) ? MIN_FRAME_BYTES : nbytes;
        for (int i = 0; i < nout; i++) begin
            push_cc(i == nout-1, 1'b0, (i < nbytes) ? lp_bytes[i] : 8'h00);
            exp_pf[exp_pf_count] = {i == nout-1, (i < nbytes) ? lp_bytes[i] : 8'h00};
            exp_pf_count = exp_pf_count + 1;
        end
        exp_pf_len[exp_pf_frames] = nout;
        exp_pf_frames = exp_pf_frames + 1;
        for (int i = 0; i < nbytes; i++) begin
            ch_send_beat(lp_bytes[i], i == nbytes-1, 1'b0);
        end
        ch_s_tvalid <= 1'b0;
        ch_s_tlast  <= 1'b0;
    endtask

    //----------------------------------------------------------------
    // Test sequence
    //----------------------------------------------------------------
    initial begin
        chk_s_tvalid = 1'b0;
        chk_s_tdata  = 8'h00;
        chk_s_tlast  = 1'b0;
        chk_s_tuser  = 1'b0;
        gen_s_tvalid = 1'b0;
        gen_s_tdata  = 8'h00;
        gen_s_tlast  = 1'b0;
        gen_s_tuser  = 1'b0;
        ch_s_tvalid  = 1'b0;
        ch_s_tdata   = 8'h00;
        ch_s_tlast   = 1'b0;
        ch_s_tuser   = 1'b0;

        wait (sreset === 1'b0);
        @(posedge clock);

        // Valid frame
        load_frame_k();
        chk_send_frame(24, 1'b0, -1);

        // Corrupt FCS, back to back with the previous frame
        load_frame_k();
        chk_in_bytes[23] = chk_in_bytes[23] ^ 8'h01;
        chk_send_frame(24, 1'b1, -1);

        // Corrupt payload byte, original FCS
        load_frame_k();
        chk_in_bytes[5] = chk_in_bytes[5] ^ 8'h80;
        chk_send_frame(24, 1'b1, -1);
        chk_idle(5);

        // Single-byte payload
        chk_in_bytes[0] = 8'h3C;
        chk_in_bytes[1] = 8'h0A;
        chk_in_bytes[2] = 8'h93;
        chk_in_bytes[3] = 8'h6D;
        chk_in_bytes[4] = 8'hFD;
        chk_send_frame(5, 1'b0, -1);

        // Runt frames: no payload at all, nothing may come out
        chk_send_frame(3, 1'b0, -1);
        chk_send_frame(4, 1'b0, -1);
        chk_idle(5);

        // Upstream error flagged mid-frame on an otherwise valid frame
        load_frame_k();
        chk_send_frame(24, 1'b1, 7);

        // Valid frame again: the error must not stick across frames
        load_frame_k();
        chk_send_frame(24, 1'b0, -1);
        chk_idle(20);

        // Loopback chain, assorted lengths around the padding threshold
        lp_send_frame(1);
        lp_send_frame(5);
        lp_send_frame(59);
        lp_send_frame(60);
        lp_send_frame(61);
        lp_send_frame(100);
        gen_s_tvalid <= 1'b0;

        // Full RMII chain: clean frames on both sides of the padding
        // threshold, then one aborted mid-frame, then a recovery frame
        for (int i = 0; i < 18; i++) lp_bytes[i] = 8'(7*i + 1);
        ch_send_frame(18);
        for (int i = 0; i < 61; i++) lp_bytes[i] = 8'(3*i + 11);
        ch_send_frame(61);

        // Abort on beat 10 of 20: ten bytes reach the wire, the checker
        // recovers six and must flag the frame, since the FCS slot
        // holds payload bytes instead of a CRC
        for (int i = 0; i < 20; i++) lp_bytes[i] = 8'(9*i + 2);
        for (int i = 0; i < 6; i++) push_cc(i == 5, i == 5, lp_bytes[i]);
        for (int i = 0; i < 20; i++) begin
            ch_send_beat(lp_bytes[i], i == 19, i == 10);
        end
        ch_s_tvalid <= 1'b0;
        ch_s_tlast  <= 1'b0;
        ch_s_tuser  <= 1'b0;

        for (int i = 0; i < 4; i++) lp_bytes[i] = 8'(8'hC0 + i);
        ch_send_frame(4);
        chk_idle(700);

        if (chk_mon_idx != exp_chk_count) begin
            errors = errors + 1;
            $error("checker stream incomplete: %0d beats seen, %0d expected",
                   chk_mon_idx, exp_chk_count);
        end
        if (lp_mon_idx != exp_lp_count) begin
            errors = errors + 1;
            $error("loopback stream incomplete: %0d beats seen, %0d expected",
                   lp_mon_idx, exp_lp_count);
        end
        if (cc_mon_idx != exp_cc_count) begin
            errors = errors + 1;
            $error("chain stream incomplete: %0d beats seen, %0d expected",
                   cc_mon_idx, exp_cc_count);
        end
        if (pf_mon_idx != exp_pf_count || pf_frame_idx != exp_pf_frames) begin
            errors = errors + 1;
            $error("packet FIFO stream incomplete: %0d/%0d beats, %0d/%0d frames",
                   pf_mon_idx, exp_pf_count, pf_frame_idx, exp_pf_frames);
        end

        if (errors == 0)
          $display("axi_stream_eth_fcs_check_tb: ALL TESTS PASSED");
        else
          $display("axi_stream_eth_fcs_check_tb: %0d ERROR(S)", errors);
        $finish;
    end

    //----------------------------------------------------------------
    // Check outputs
    //----------------------------------------------------------------
    always @(posedge clock) begin
        if (sreset === 1'b0 && chk_m_tvalid === 1'b1 && chk_m_tready === 1'b1) begin
            if (chk_mon_idx >= exp_chk_count) begin
                errors = errors + 1;
                $error("unexpected checker beat %02x at index %0d", chk_m_tdata, chk_mon_idx);
            end
            else if ({chk_m_tlast, chk_m_tuser, chk_m_tdata} !== exp_chk[chk_mon_idx]) begin
                errors = errors + 1;
                $error("checker beat %0d: got last=%b user=%b data=%02x, expected last=%b user=%b data=%02x",
                       chk_mon_idx, chk_m_tlast, chk_m_tuser, chk_m_tdata,
                       exp_chk[chk_mon_idx][9], exp_chk[chk_mon_idx][8], exp_chk[chk_mon_idx][7:0]);
            end
            chk_mon_idx = chk_mon_idx + 1;
        end
    end

    always @(posedge clock) begin
        if (sreset === 1'b0 && lp_m_tvalid === 1'b1 && lp_m_tready === 1'b1) begin
            if (lp_mon_idx >= exp_lp_count) begin
                errors = errors + 1;
                $error("unexpected loopback beat %02x at index %0d", lp_m_tdata, lp_mon_idx);
            end
            else if ({lp_m_tlast, lp_m_tuser, lp_m_tdata} !== exp_lp[lp_mon_idx]) begin
                errors = errors + 1;
                $error("loopback beat %0d: got last=%b user=%b data=%02x, expected last=%b user=%b data=%02x",
                       lp_mon_idx, lp_m_tlast, lp_m_tuser, lp_m_tdata,
                       exp_lp[lp_mon_idx][9], exp_lp[lp_mon_idx][8], exp_lp[lp_mon_idx][7:0]);
            end
            lp_mon_idx = lp_mon_idx + 1;
        end
    end

    always @(posedge clock) begin
        if (sreset === 1'b0 && cc_m_tvalid === 1'b1 && cc_m_tready === 1'b1) begin
            if (cc_mon_idx >= exp_cc_count) begin
                errors = errors + 1;
                $error("unexpected chain beat %02x at index %0d", cc_m_tdata, cc_mon_idx);
            end
            else if ({cc_m_tlast, cc_m_tuser, cc_m_tdata} !== exp_cc[cc_mon_idx]) begin
                errors = errors + 1;
                $error("chain beat %0d: got last=%b user=%b data=%02x, expected last=%b user=%b data=%02x",
                       cc_mon_idx, cc_m_tlast, cc_m_tuser, cc_m_tdata,
                       exp_cc[cc_mon_idx][9], exp_cc[cc_mon_idx][8], exp_cc[cc_mon_idx][7:0]);
            end
            cc_mon_idx = cc_mon_idx + 1;
        end
    end

    // After the packet FIFO only the clean frames remain, the aborted
    // one has vanished whole, and the length rides with each frame
    always @(posedge clock) begin
        if (sreset === 1'b0 && pf_m_tvalid === 1'b1 && pf_m_tready === 1'b1) begin
            if (pf_mon_idx >= exp_pf_count) begin
                errors = errors + 1;
                $error("unexpected FIFO beat %02x at index %0d", pf_m_tdata, pf_mon_idx);
            end
            else begin
                if ({pf_m_tlast, pf_m_tdata} !== exp_pf[pf_mon_idx]) begin
                    errors = errors + 1;
                    $error("FIFO beat %0d: got last=%b data=%02x, expected last=%b data=%02x",
                           pf_mon_idx, pf_m_tlast, pf_m_tdata,
                           exp_pf[pf_mon_idx][8], exp_pf[pf_mon_idx][7:0]);
                end
                if (pf_m_info !== 1'b0) begin
                    errors = errors + 1;
                    $error("FIFO frame %0d: info raised, input is tied low", pf_frame_idx);
                end
                if (pf_m_length !== 9'(exp_pf_len[pf_frame_idx])) begin
                    errors = errors + 1;
                    $error("FIFO frame %0d: got length %0d, expected %0d",
                           pf_frame_idx, pf_m_length, exp_pf_len[pf_frame_idx]);
                end
            end
            pf_mon_idx = pf_mon_idx + 1;
            if (pf_m_tlast === 1'b1) pf_frame_idx = pf_frame_idx + 1;
        end
    end

endmodule
