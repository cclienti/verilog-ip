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
// generated (padding included) with tuser never raised.
//-----------------------------------------------------------------------------
// Copyright (c) 2026 by Christophe Clienti. This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

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
        end
        else begin
            chk_m_tready <= $urandom_range(0, 1) == 1 ? 1'b1 : 1'b0;
            lp_m_tready  <= $urandom_range(0, 1) == 1 ? 1'b1 : 1'b0;
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
        chk_idle(400);

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

endmodule
