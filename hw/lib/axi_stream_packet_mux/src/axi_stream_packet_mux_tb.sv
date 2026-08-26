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
// Title         : AXI Stream Packet Mux Testbench
//-----------------------------------------------------------------------------
// File          : axi_stream_packet_mux_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-25
// Last modified : 2026-08-25
//-----------------------------------------------------------------------------
// Description :
// Testbench of the AXI Stream Packet Mux, closed into a round trip with
// its counterpart demux: three sources feed the mux, the demux routes
// the merged stream back by the info tag, and each sink must receive
// exactly its own source's frames, in order, beat for beat -- any
// interleaving, misrouting or corruption lands in the wrong sink's
// comparison. A first phase saturates all three sources with equal
// frames and checks strict round-robin rotation at the mux output; a
// second phase runs random lengths, gaps and per-sink backpressure. The
// mux-output monitor also checks the info word never changes mid-frame.

`timescale 1 ns / 100 ps

module axi_stream_packet_mux_tb;

    integer errors = 0;
    integer phase  = 1;

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
    // Sources, mux, demux, sinks
    //----------------------------------------------------------------
    logic [7:0] s0_tdata, s1_tdata, s2_tdata;
    logic       s0_tuser, s1_tuser, s2_tuser;
    logic       s0_tvalid, s1_tvalid, s2_tvalid;
    logic       s0_tlast, s1_tlast, s2_tlast;
    logic       s0_tready, s1_tready, s2_tready;

    logic [7:0]  mo_tdata;
    logic        mo_tuser;
    logic        mo_tvalid;
    logic        mo_tlast;
    logic        mo_tready;
    logic [3:0]  mo_info;

    logic [23:0] d_tdata;
    logic [2:0]  d_tuser;
    logic [2:0]  d_tvalid;
    logic [2:0]  d_tlast;
    logic [2:0]  d_tready;
    logic [3:0]  d_info;

    axi_stream_packet_mux
    #(
        .NB_INPUTS  (3),
        .DATA_WIDTH (8),
        .INFO_WIDTH (4)
    )
    axi_stream_packet_mux_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  ({s2_tdata, s1_tdata, s0_tdata}),
        .s_axi_tuser  ({s2_tuser, s1_tuser, s0_tuser}),
        .s_axi_tvalid ({s2_tvalid, s1_tvalid, s0_tvalid}),
        .s_axi_tlast  ({s2_tlast, s1_tlast, s0_tlast}),
        .s_axi_tready ({s2_tready, s1_tready, s0_tready}),
        .s_info       ({4'd2, 4'd1, 4'd0}),
        .m_axi_tdata  (mo_tdata),
        .m_axi_tuser  (mo_tuser),
        .m_axi_tvalid (mo_tvalid),
        .m_axi_tlast  (mo_tlast),
        .m_axi_tready (mo_tready),
        .m_info       (mo_info)
    );

    axi_stream_packet_demux
    #(
        .NB_OUTPUTS (3),
        .DATA_WIDTH (8),
        .INFO_WIDTH (4)
    )
    axi_stream_packet_demux_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (mo_tdata),
        .s_axi_tuser  (mo_tuser),
        .s_axi_tvalid (mo_tvalid),
        .s_axi_tlast  (mo_tlast),
        .s_axi_tready (mo_tready),
        .s_sel        (mo_info[1:0]),
        .s_info       (mo_info),
        .m_axi_tdata  (d_tdata),
        .m_axi_tuser  (d_tuser),
        .m_axi_tvalid (d_tvalid),
        .m_axi_tlast  (d_tlast),
        .m_axi_tready (d_tready),
        .m_info       (d_info)
    );

    //----------------------------------------------------------------
    // Sink backpressure: deterministic in the rotation phase
    //----------------------------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            d_tready <= '0;
        end
        else if (phase == 1) begin
            d_tready <= 3'b111;
        end
        else begin
            for (int i = 0; i < 3; i++) begin
                d_tready[i] <= $urandom_range(0, 1) == 1;
            end
        end
    end

    //----------------------------------------------------------------
    // Expected beats per source: {last, user, data}
    //----------------------------------------------------------------
    logic [9:0] s0_exp [0:255];
    logic [9:0] s1_exp [0:255];
    logic [9:0] s2_exp [0:255];
    integer     s0_exp_count = 0, s1_exp_count = 0, s2_exp_count = 0;
    integer     s0_sink_idx = 0, s1_sink_idx = 0, s2_sink_idx = 0;

    //----------------------------------------------------------------
    // Drivers: one process per source. Beats are presented mid-cycle
    // with blocking assignments and tready sampled there: the ready
    // chain is combinational through mux and demux, and simulators
    // disagree on which side of a posedge a resumed process reads.
    //----------------------------------------------------------------
    task automatic s0_send_frame(input integer nbeats, input logic [7:0] base);
        logic [7:0] b;
        logic       last, user;
        for (int k = 0; k < nbeats; k++) begin
            b    = 8'(base + k);
            last = (k == nbeats-1);
            user = $urandom_range(0, 7) == 0;
            s0_exp[s0_exp_count] = {last, user, b};
            s0_exp_count = s0_exp_count + 1;
            @(negedge clock);
            s0_tvalid = 1'b1; s0_tdata = b; s0_tlast = last; s0_tuser = user;
            #1;
            while (s0_tready !== 1'b1) begin
                @(negedge clock);
                #1;
            end
            @(posedge clock);
        end
        s0_tvalid <= 1'b0; s0_tlast <= 1'b0; s0_tuser <= 1'b0;
    endtask

    task automatic s1_send_frame(input integer nbeats, input logic [7:0] base);
        logic [7:0] b;
        logic       last, user;
        for (int k = 0; k < nbeats; k++) begin
            b    = 8'(base + k);
            last = (k == nbeats-1);
            user = $urandom_range(0, 7) == 0;
            s1_exp[s1_exp_count] = {last, user, b};
            s1_exp_count = s1_exp_count + 1;
            @(negedge clock);
            s1_tvalid = 1'b1; s1_tdata = b; s1_tlast = last; s1_tuser = user;
            #1;
            while (s1_tready !== 1'b1) begin
                @(negedge clock);
                #1;
            end
            @(posedge clock);
        end
        s1_tvalid <= 1'b0; s1_tlast <= 1'b0; s1_tuser <= 1'b0;
    endtask

    task automatic s2_send_frame(input integer nbeats, input logic [7:0] base);
        logic [7:0] b;
        logic       last, user;
        for (int k = 0; k < nbeats; k++) begin
            b    = 8'(base + k);
            last = (k == nbeats-1);
            user = $urandom_range(0, 7) == 0;
            s2_exp[s2_exp_count] = {last, user, b};
            s2_exp_count = s2_exp_count + 1;
            @(negedge clock);
            s2_tvalid = 1'b1; s2_tdata = b; s2_tlast = last; s2_tuser = user;
            #1;
            while (s2_tready !== 1'b1) begin
                @(negedge clock);
                #1;
            end
            @(posedge clock);
        end
        s2_tvalid <= 1'b0; s2_tlast <= 1'b0; s2_tuser <= 1'b0;
    endtask

    initial begin
        s0_tvalid = 1'b0; s0_tdata = '0; s0_tlast = 1'b0; s0_tuser = 1'b0;
        wait (sreset === 1'b0);
        @(posedge clock);
        for (int f = 0; f < 6; f++) s0_send_frame(5, 8'h00 + 8'(16*f));
        wait (phase == 2);
        for (int f = 0; f < 10; f++) begin
            s0_send_frame($urandom_range(1, 8), 8'($urandom));
            repeat ($urandom_range(0, 3)) @(posedge clock);
        end
    end

    initial begin
        s1_tvalid = 1'b0; s1_tdata = '0; s1_tlast = 1'b0; s1_tuser = 1'b0;
        wait (sreset === 1'b0);
        @(posedge clock);
        for (int f = 0; f < 6; f++) s1_send_frame(5, 8'h40 + 8'(16*f));
        wait (phase == 2);
        for (int f = 0; f < 10; f++) begin
            s1_send_frame($urandom_range(1, 8), 8'($urandom));
            repeat ($urandom_range(0, 3)) @(posedge clock);
        end
    end

    initial begin
        s2_tvalid = 1'b0; s2_tdata = '0; s2_tlast = 1'b0; s2_tuser = 1'b0;
        wait (sreset === 1'b0);
        @(posedge clock);
        for (int f = 0; f < 6; f++) s2_send_frame(5, 8'h80 + 8'(16*f));
        wait (phase == 2);
        for (int f = 0; f < 10; f++) begin
            s2_send_frame($urandom_range(1, 8), 8'($urandom));
            repeat ($urandom_range(0, 3)) @(posedge clock);
        end
    end

    //----------------------------------------------------------------
    // Mux-output monitor: strict rotation while saturated, info word
    // stable within a frame
    //----------------------------------------------------------------
    integer mo_frames_done = 0;
    integer mo_in_frame = 0;
    integer mo_tag = 0;

    always @(posedge clock) begin
        if (sreset === 1'b0 && mo_tvalid === 1'b1 && mo_tready === 1'b1) begin
            if (mo_in_frame == 0) begin
                mo_tag = 32'(mo_info);
                if (mo_tag > 2) begin
                    errors = errors + 1;
                    $error("mux frame with tag %0d", mo_tag);
                end
                // Saturation phase: sources are aligned and equal, so
                // grants must rotate 0,1,2 strictly from the first frame
                if (mo_frames_done < 18 && mo_tag != mo_frames_done % 3) begin
                    errors = errors + 1;
                    $error("rotation broken: frame %0d from source %0d",
                           mo_frames_done, mo_tag);
                end
                mo_in_frame = 1;
            end
            else if (32'(mo_info) != mo_tag) begin
                errors = errors + 1;
                $error("info changed mid-frame: %0d -> %0d", mo_tag, mo_info);
            end
            if (mo_tlast === 1'b1) begin
                mo_in_frame = 0;
                mo_frames_done = mo_frames_done + 1;
            end
        end
    end

    //----------------------------------------------------------------
    // Sink monitors: each must receive exactly its source's stream
    //----------------------------------------------------------------
    always @(posedge clock) begin
        if (sreset === 1'b0 && d_tvalid[0] === 1'b1 && d_tready[0] === 1'b1) begin
            if (s0_sink_idx >= s0_exp_count) begin
                errors = errors + 1;
                $error("sink0: unexpected beat %02x", d_tdata[7:0]);
            end
            else if ({d_tlast[0], d_tuser[0], d_tdata[7:0]} !== s0_exp[s0_sink_idx]) begin
                errors = errors + 1;
                $error("sink0 beat %0d: got last=%b user=%b data=%02x, expected last=%b user=%b data=%02x",
                       s0_sink_idx, d_tlast[0], d_tuser[0], d_tdata[7:0],
                       s0_exp[s0_sink_idx][9], s0_exp[s0_sink_idx][8], s0_exp[s0_sink_idx][7:0]);
            end
            s0_sink_idx = s0_sink_idx + 1;
        end
    end

    always @(posedge clock) begin
        if (sreset === 1'b0 && d_tvalid[1] === 1'b1 && d_tready[1] === 1'b1) begin
            if (s1_sink_idx >= s1_exp_count) begin
                errors = errors + 1;
                $error("sink1: unexpected beat %02x", d_tdata[15:8]);
            end
            else if ({d_tlast[1], d_tuser[1], d_tdata[15:8]} !== s1_exp[s1_sink_idx]) begin
                errors = errors + 1;
                $error("sink1 beat %0d: got last=%b user=%b data=%02x, expected last=%b user=%b data=%02x",
                       s1_sink_idx, d_tlast[1], d_tuser[1], d_tdata[15:8],
                       s1_exp[s1_sink_idx][9], s1_exp[s1_sink_idx][8], s1_exp[s1_sink_idx][7:0]);
            end
            s1_sink_idx = s1_sink_idx + 1;
        end
    end

    always @(posedge clock) begin
        if (sreset === 1'b0 && d_tvalid[2] === 1'b1 && d_tready[2] === 1'b1) begin
            if (s2_sink_idx >= s2_exp_count) begin
                errors = errors + 1;
                $error("sink2: unexpected beat %02x", d_tdata[23:16]);
            end
            else if ({d_tlast[2], d_tuser[2], d_tdata[23:16]} !== s2_exp[s2_sink_idx]) begin
                errors = errors + 1;
                $error("sink2 beat %0d: got last=%b user=%b data=%02x, expected last=%b user=%b data=%02x",
                       s2_sink_idx, d_tlast[2], d_tuser[2], d_tdata[23:16],
                       s2_exp[s2_sink_idx][9], s2_exp[s2_sink_idx][8], s2_exp[s2_sink_idx][7:0]);
            end
            s2_sink_idx = s2_sink_idx + 1;
        end
    end

    //----------------------------------------------------------------
    // Sequence control and verdict
    //----------------------------------------------------------------
    initial begin
        wait (sreset === 1'b0);
        wait (mo_frames_done == 18);
        repeat (10) @(posedge clock);
        phase = 2;
        wait (mo_frames_done == 48);
        repeat (60) @(posedge clock);

        if (s0_sink_idx != s0_exp_count || s1_sink_idx != s1_exp_count ||
            s2_sink_idx != s2_exp_count) begin
            errors = errors + 1;
            $error("streams incomplete: %0d/%0d %0d/%0d %0d/%0d",
                   s0_sink_idx, s0_exp_count, s1_sink_idx, s1_exp_count,
                   s2_sink_idx, s2_exp_count);
        end

        if (errors == 0)
          $display("axi_stream_packet_mux_tb: ALL TESTS PASSED");
        else
          $display("axi_stream_packet_mux_tb: %0d ERROR(S)", errors);
        $finish;
    end

    // Watchdog: a stuck grant or lost beat parks a driver forever
    initial begin
        #400000;
        errors = errors + 1;
        $error("watchdog: %0d frames done, sinks %0d/%0d %0d/%0d %0d/%0d",
               mo_frames_done, s0_sink_idx, s0_exp_count,
               s1_sink_idx, s1_exp_count, s2_sink_idx, s2_exp_count);
        $display("axi_stream_packet_mux_tb: %0d ERROR(S)", errors);
        $finish;
    end

endmodule
