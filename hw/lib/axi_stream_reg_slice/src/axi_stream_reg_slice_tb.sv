//-----------------------------------------------------------------------------
// Title         : AXI Stream Register Slice Testbench
//-----------------------------------------------------------------------------
// File          : axi_stream_reg_slice_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-24
// Last modified : 2026-08-24
//-----------------------------------------------------------------------------
// Description :
// Testbench of the AXI Stream Register Slice. Every beat is compared in
// order (data, tlast, tuser) under random tvalid gaps and random
// backpressure. Two properties pin the slice's contract beyond data
// integrity: s_axi_tready must equal (beats in flight < 2) on every
// cycle -- which is exactly what a two-slot slice with a registered
// ready looks like from outside, and fails for any combinational
// passthrough or mis-sized variant -- and a forced full-rate window
// must accept one beat per clock with no bubble. A long soak at
// contrasting ready duty cycles (mostly stalled, then balanced) hunts
// for handshake deadlocks: a lost beat parks the driver and trips the
// watchdog. A second instance sweeps the width parameters (2-bit data,
// 4-bit user).
//-----------------------------------------------------------------------------
// Copyright (c) 2026 by Christophe Clienti. This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module axi_stream_reg_slice_tb;

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

    integer cycle_count = 0;
    always @(posedge clock) cycle_count = cycle_count + 1;

    //----------------------------------------------------------------
    // Main instance: 8-bit data, 1-bit user
    //----------------------------------------------------------------
    logic [7:0] mn_s_tdata;
    logic       mn_s_tuser;
    logic       mn_s_tvalid;
    logic       mn_s_tlast;
    logic       mn_s_tready;
    logic [7:0] mn_m_tdata;
    logic       mn_m_tuser;
    logic       mn_m_tvalid;
    logic       mn_m_tlast;
    logic       mn_m_tready;
    logic [1:0] mn_ready_mode; // 0: random, 1: ready, 2: stalled, 3: mostly stalled

    axi_stream_reg_slice
    #(
        .DATA_WIDTH (8),
        .USER_WIDTH (1)
    )
    axi_stream_reg_slice_mn_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (mn_s_tdata),
        .s_axi_tuser  (mn_s_tuser),
        .s_axi_tvalid (mn_s_tvalid),
        .s_axi_tlast  (mn_s_tlast),
        .s_axi_tready (mn_s_tready),
        .m_axi_tdata  (mn_m_tdata),
        .m_axi_tuser  (mn_m_tuser),
        .m_axi_tvalid (mn_m_tvalid),
        .m_axi_tlast  (mn_m_tlast),
        .m_axi_tready (mn_m_tready)
    );

    //----------------------------------------------------------------
    // Width-sweep instance: 2-bit data, 4-bit user
    //----------------------------------------------------------------
    logic [1:0] alt_s_tdata;
    logic [3:0] alt_s_tuser;
    logic       alt_s_tvalid;
    logic       alt_s_tlast;
    logic       alt_s_tready;
    logic [1:0] alt_m_tdata;
    logic [3:0] alt_m_tuser;
    logic       alt_m_tvalid;
    logic       alt_m_tlast;
    logic       alt_m_tready;

    axi_stream_reg_slice
    #(
        .DATA_WIDTH (2),
        .USER_WIDTH (4)
    )
    axi_stream_reg_slice_alt_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (alt_s_tdata),
        .s_axi_tuser  (alt_s_tuser),
        .s_axi_tvalid (alt_s_tvalid),
        .s_axi_tlast  (alt_s_tlast),
        .s_axi_tready (alt_s_tready),
        .m_axi_tdata  (alt_m_tdata),
        .m_axi_tuser  (alt_m_tuser),
        .m_axi_tvalid (alt_m_tvalid),
        .m_axi_tlast  (alt_m_tlast),
        .m_axi_tready (alt_m_tready)
    );

    //----------------------------------------------------------------
    // Backpressure
    //----------------------------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            mn_m_tready  <= 1'b0;
            alt_m_tready <= 1'b0;
        end
        else begin
            case (mn_ready_mode)
                2'd1:    mn_m_tready <= 1'b1;
                2'd2:    mn_m_tready <= 1'b0;
                2'd3:    mn_m_tready <= $urandom_range(0, 7) == 0; // mostly stalled
                default: mn_m_tready <= $urandom_range(0, 1) == 1;
            endcase
            alt_m_tready <= $urandom_range(0, 1) == 1;
        end
    end

    //----------------------------------------------------------------
    // Expected beats: {user, last, data}
    //----------------------------------------------------------------
    logic [9:0] mn_exp [0:4095];
    integer     mn_exp_count = 0;
    integer     mn_mon_idx = 0;

    logic [6:0] alt_exp [0:255];
    integer     alt_exp_count = 0;
    integer     alt_mon_idx = 0;

    //----------------------------------------------------------------
    // Drivers
    //----------------------------------------------------------------
    task automatic mn_send_beat(input logic [7:0] data, input logic last, input logic user);
        mn_exp[mn_exp_count] = {user, last, data};
        mn_exp_count = mn_exp_count + 1;
        mn_s_tvalid <= 1'b1;
        mn_s_tdata  <= data;
        mn_s_tlast  <= last;
        mn_s_tuser  <= user;
        @(posedge clock);
        while (mn_s_tready !== 1'b1) @(posedge clock);
    endtask

    task automatic mn_idle(input integer cycles);
        mn_s_tvalid <= 1'b0;
        mn_s_tlast  <= 1'b0;
        mn_s_tuser  <= 1'b0;
        repeat (cycles) @(posedge clock);
    endtask

    task automatic alt_send_beat(input logic [1:0] data, input logic last,
                                 input logic [3:0] user);
        alt_exp[alt_exp_count] = {user, last, data};
        alt_exp_count = alt_exp_count + 1;
        alt_s_tvalid <= 1'b1;
        alt_s_tdata  <= data;
        alt_s_tlast  <= last;
        alt_s_tuser  <= user;
        @(posedge clock);
        while (alt_s_tready !== 1'b1) @(posedge clock);
    endtask

    //----------------------------------------------------------------
    // Test sequence
    //----------------------------------------------------------------
    integer mark;

    initial begin
        mn_s_tvalid  = 1'b0; mn_s_tdata = '0; mn_s_tlast = 1'b0; mn_s_tuser = 1'b0;
        mn_ready_mode = 2'd1;
        alt_s_tvalid = 1'b0; alt_s_tdata = '0; alt_s_tlast = 1'b0; alt_s_tuser = 1'b0;

        wait (sreset === 1'b0);
        @(posedge clock);

        // Full-rate window: with the sink always ready, 40 back-to-back
        // beats must be accepted in exactly 40 cycles -- no bubble.
        // The marks are read at negedges, where the cycle counter is
        // stable, so the measurement cannot race its increment.
        @(negedge clock);
        mark = cycle_count;
        for (int i = 0; i < 40; i++) begin
            mn_send_beat(8'(3*i + 5), i % 8 == 7, i[0]);
        end
        @(negedge clock);
        if (cycle_count - mark != 40) begin
            errors = errors + 1;
            $error("full-rate window took %0d cycles for 40 beats", cycle_count - mark);
        end
        mn_idle(5);

        // Exposed-cycle corner, deterministically: fill the output
        // register, stall the sink, and launch the beat the registered
        // ready still announces room for -- it must land in the skid
        // and come out in order once the sink resumes
        mn_ready_mode <= 2'd2;
        mn_idle(3);
        mn_send_beat(8'hA1, 1'b0, 1'b0); // into the output register
        mn_send_beat(8'hA2, 1'b0, 1'b1); // the exposed beat, into the skid
        mn_idle(5);
        mn_ready_mode <= 2'd1;
        mn_idle(5);

        // Random gaps against random backpressure
        mn_ready_mode <= 2'd0;
        for (int i = 0; i < 200; i++) begin
            mn_send_beat(8'($urandom), $urandom_range(0, 7) == 0, 1'($urandom));
            if ($urandom_range(0, 3) == 0) begin
                mn_idle($urandom_range(1, 3));
            end
        end
        mn_idle(30);

        // Deadlock soak: a long run at contrasting ready duty cycles.
        // Any lost beat or handshake deadlock parks the driver in its
        // wait loop and trips the watchdog; the counters then show how
        // far the stream got.
        mn_ready_mode <= 2'd3; // sink mostly stalled
        for (int i = 0; i < 400; i++) begin
            mn_send_beat(8'($urandom), $urandom_range(0, 7) == 0, 1'($urandom));
        end
        mn_ready_mode <= 2'd0;
        for (int i = 0; i < 1000; i++) begin
            mn_send_beat(8'($urandom), $urandom_range(0, 7) == 0, 1'($urandom));
            if ($urandom_range(0, 7) == 0) begin
                mn_idle($urandom_range(1, 2));
            end
        end
        mn_ready_mode <= 2'd1; // drain fast
        mn_idle(30);

        // Width-sweep instance under random backpressure
        for (int i = 0; i < 60; i++) begin
            alt_send_beat(2'($urandom), $urandom_range(0, 7) == 0, 4'($urandom));
        end
        alt_s_tvalid <= 1'b0;
        alt_s_tlast  <= 1'b0;
        repeat (30) @(posedge clock);

        if (mn_mon_idx != mn_exp_count) begin
            errors = errors + 1;
            $error("main stream incomplete: %0d beats seen, %0d expected",
                   mn_mon_idx, mn_exp_count);
        end
        if (alt_mon_idx != alt_exp_count) begin
            errors = errors + 1;
            $error("alt stream incomplete: %0d beats seen, %0d expected",
                   alt_mon_idx, alt_exp_count);
        end

        if (errors == 0)
          $display("axi_stream_reg_slice_tb: ALL TESTS PASSED");
        else
          $display("axi_stream_reg_slice_tb: %0d ERROR(S)", errors);
        $finish;
    end

    // Watchdog: a lost beat leaves the driver waiting forever
    initial begin
        #2000000;
        errors = errors + 1;
        $error("watchdog: test sequence did not finish (%0d/%0d, %0d/%0d)",
               mn_mon_idx, mn_exp_count, alt_mon_idx, alt_exp_count);
        $display("axi_stream_reg_slice_tb: %0d ERROR(S)", errors);
        $finish;
    end

    //----------------------------------------------------------------
    // Check outputs, in order
    //----------------------------------------------------------------
    always @(posedge clock) begin
        if (sreset === 1'b0 && mn_m_tvalid === 1'b1 && mn_m_tready === 1'b1) begin
            if (mn_mon_idx >= mn_exp_count) begin
                errors = errors + 1;
                $error("main: unexpected beat %02x at index %0d", mn_m_tdata, mn_mon_idx);
            end
            else if ({mn_m_tuser, mn_m_tlast, mn_m_tdata} !== mn_exp[mn_mon_idx]) begin
                errors = errors + 1;
                $error("main beat %0d: got user=%b last=%b data=%02x, expected user=%b last=%b data=%02x",
                       mn_mon_idx, mn_m_tuser, mn_m_tlast, mn_m_tdata,
                       mn_exp[mn_mon_idx][9], mn_exp[mn_mon_idx][8], mn_exp[mn_mon_idx][7:0]);
            end
            mn_mon_idx = mn_mon_idx + 1;
        end
    end

    always @(posedge clock) begin
        if (sreset === 1'b0 && alt_m_tvalid === 1'b1 && alt_m_tready === 1'b1) begin
            if (alt_mon_idx >= alt_exp_count) begin
                errors = errors + 1;
                $error("alt: unexpected beat %b at index %0d", alt_m_tdata, alt_mon_idx);
            end
            else if ({alt_m_tuser, alt_m_tlast, alt_m_tdata} !== alt_exp[alt_mon_idx]) begin
                errors = errors + 1;
                $error("alt beat %0d: got user=%b last=%b data=%b, expected user=%b last=%b data=%b",
                       alt_mon_idx, alt_m_tuser, alt_m_tlast, alt_m_tdata,
                       alt_exp[alt_mon_idx][6:3], alt_exp[alt_mon_idx][2], alt_exp[alt_mon_idx][1:0]);
            end
            alt_mon_idx = alt_mon_idx + 1;
        end
    end

    //----------------------------------------------------------------
    // Contract check: from outside, a two-slot slice with a registered
    // ready is exactly "s_axi_tready == (beats in flight < 2)". Any
    // combinational passthrough of m_axi_tready, a mis-registered
    // ready, or a wrong slot count breaks this on some cycle.
    //----------------------------------------------------------------
    integer mn_inflight = 0;
    integer alt_inflight = 0;

    always @(posedge clock) begin
        if (sreset === 1'b0) begin
            if (mn_s_tready !== (mn_inflight < 2)) begin
                errors = errors + 1;
                $error("main: s_axi_tready=%b with %0d beats in flight",
                       mn_s_tready, mn_inflight);
            end
            if (mn_s_tvalid === 1'b1 && mn_s_tready === 1'b1)
              mn_inflight = mn_inflight + 1;
            if (mn_m_tvalid === 1'b1 && mn_m_tready === 1'b1)
              mn_inflight = mn_inflight - 1;

            if (alt_s_tready !== (alt_inflight < 2)) begin
                errors = errors + 1;
                $error("alt: s_axi_tready=%b with %0d beats in flight",
                       alt_s_tready, alt_inflight);
            end
            if (alt_s_tvalid === 1'b1 && alt_s_tready === 1'b1)
              alt_inflight = alt_inflight + 1;
            if (alt_m_tvalid === 1'b1 && alt_m_tready === 1'b1)
              alt_inflight = alt_inflight - 1;
        end
    end

endmodule
