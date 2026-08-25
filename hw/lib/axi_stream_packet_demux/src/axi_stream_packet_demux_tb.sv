//-----------------------------------------------------------------------------
// Title         : AXI Stream Packet Demux Testbench
//-----------------------------------------------------------------------------
// File          : axi_stream_packet_demux_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-25
// Last modified : 2026-08-25
//-----------------------------------------------------------------------------
// Description :
// Directed testbench of the AXI Stream Packet Demux. Frames are routed
// to each of the three outputs and compared beat for beat, info word
// included, under random per-output backpressure. The discard code
// (s_sel >= NB_OUTPUTS) must make frames vanish without a beat on any
// output, a select that changes mid-frame must not resteer the frame
// (the first-beat sample rules), and single-beat frames exercise the
// live-select path. The round trip with the packet mux is covered in
// the mux testbench.
//-----------------------------------------------------------------------------
// Copyright (c) 2026 by Christophe Clienti. This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module axi_stream_packet_demux_tb;

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
    // DUT
    //----------------------------------------------------------------
    logic [7:0]  s_tdata;
    logic        s_tuser;
    logic        s_tvalid;
    logic        s_tlast;
    logic        s_tready;
    logic [1:0]  s_sel;
    logic [3:0]  s_info;

    logic [23:0] m_tdata;
    logic [2:0]  m_tuser;
    logic [2:0]  m_tvalid;
    logic [2:0]  m_tlast;
    logic [2:0]  m_tready;
    logic [3:0]  m_info;

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
        .s_axi_tdata  (s_tdata),
        .s_axi_tuser  (s_tuser),
        .s_axi_tvalid (s_tvalid),
        .s_axi_tlast  (s_tlast),
        .s_axi_tready (s_tready),
        .s_sel        (s_sel),
        .s_info       (s_info),
        .m_axi_tdata  (m_tdata),
        .m_axi_tuser  (m_tuser),
        .m_axi_tvalid (m_tvalid),
        .m_axi_tlast  (m_tlast),
        .m_axi_tready (m_tready),
        .m_info       (m_info)
    );

    //----------------------------------------------------------------
    // Random backpressure per output
    //----------------------------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            m_tready <= '0;
        end
        else begin
            for (int i = 0; i < 3; i++) begin
                m_tready[i] <= $urandom_range(0, 1) == 1;
            end
        end
    end

    //----------------------------------------------------------------
    // Expected beats per output: {info, last, user, data}
    //----------------------------------------------------------------
    logic [13:0] exp0 [0:255];
    logic [13:0] exp1 [0:255];
    logic [13:0] exp2 [0:255];
    integer      exp_count [0:2];
    integer      mon_idx [0:2];

    task automatic push_exp(input integer o, input logic [3:0] info,
                            input logic last, input logic user, input logic [7:0] data);
        case (o)
            0: exp0[exp_count[0]] = {info, last, user, data};
            1: exp1[exp_count[1]] = {info, last, user, data};
            default: exp2[exp_count[2]] = {info, last, user, data};
        endcase
        exp_count[o] = exp_count[o] + 1;
    endtask

    //----------------------------------------------------------------
    // Driver. sel_rest lets a test flip the select mid-frame: the
    // frame must stay on sel_first, where the expectations go.
    //----------------------------------------------------------------
    task automatic send_frame(input logic [1:0] sel_first, input logic [1:0] sel_rest,
                              input integer nbeats, input logic [7:0] base,
                              input logic [3:0] info);
        logic [7:0] b;
        logic       last, user;
        for (int k = 0; k < nbeats; k++) begin
            b    = 8'(base + k);
            last = (k == nbeats-1);
            user = $urandom_range(0, 7) == 0;
            if (32'(sel_first) < 3) begin
                push_exp(32'(sel_first), info, last, user, b);
            end
            // Mid-cycle blocking drive: s_axi_tready is combinational
            // on s_sel and the per-output readies, so the settled
            // negedge value is the only simulator-portable sample point
            @(negedge clock);
            s_tvalid = 1'b1;
            s_tdata  = b;
            s_tlast  = last;
            s_tuser  = user;
            s_sel    = (k == 0) ? sel_first : sel_rest;
            s_info   = info;
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
    initial begin
        s_tvalid = 1'b0; s_tdata = '0; s_tlast = 1'b0; s_tuser = 1'b0;
        s_sel = '0; s_info = '0;

        wait (sreset === 1'b0);
        @(posedge clock);

        // Each output, assorted lengths, single-beat frames included
        send_frame(2'd0, 2'd0, 5, 8'h10, 4'h5);
        send_frame(2'd1, 2'd1, 1, 8'h20, 4'h6);
        send_frame(2'd2, 2'd2, 8, 8'h30, 4'h7);
        send_frame(2'd0, 2'd0, 1, 8'h40, 4'h8);

        // Discarded frames: consumed, never seen again
        send_frame(2'd3, 2'd3, 6, 8'h50, 4'h9);
        send_frame(2'd3, 2'd3, 1, 8'h60, 4'hA);

        // The select flips mid-frame: the frame must stay on its
        // first-beat route, and the next frame routes freshly
        send_frame(2'd1, 2'd2, 6, 8'h70, 4'hB);
        send_frame(2'd2, 2'd0, 4, 8'h80, 4'hC);
        // A discard must also hold when the select flips into range
        send_frame(2'd3, 2'd0, 5, 8'h90, 4'hD);

        // Random traffic across every route including discards
        for (int f = 0; f < 40; f++) begin
            send_frame(2'($urandom), 2'($urandom), $urandom_range(1, 6),
                       8'($urandom), 4'($urandom));
            repeat ($urandom_range(0, 2)) @(posedge clock);
        end
        repeat (60) @(posedge clock);

        if (mon_idx[0] != exp_count[0] || mon_idx[1] != exp_count[1] ||
            mon_idx[2] != exp_count[2]) begin
            errors = errors + 1;
            $error("streams incomplete: %0d/%0d %0d/%0d %0d/%0d",
                   mon_idx[0], exp_count[0], mon_idx[1], exp_count[1],
                   mon_idx[2], exp_count[2]);
        end

        if (errors == 0)
          $display("axi_stream_packet_demux_tb: ALL TESTS PASSED");
        else
          $display("axi_stream_packet_demux_tb: %0d ERROR(S)", errors);
        $finish;
    end

    // Watchdog: a broken discard path stalls the driver forever
    initial begin
        #400000;
        errors = errors + 1;
        $error("watchdog: %0d/%0d %0d/%0d %0d/%0d",
               mon_idx[0], exp_count[0], mon_idx[1], exp_count[1],
               mon_idx[2], exp_count[2]);
        $display("axi_stream_packet_demux_tb: %0d ERROR(S)", errors);
        $finish;
    end

    //----------------------------------------------------------------
    // Output monitors
    //----------------------------------------------------------------
    initial begin
        exp_count[0] = 0; exp_count[1] = 0; exp_count[2] = 0;
        mon_idx[0] = 0; mon_idx[1] = 0; mon_idx[2] = 0;
    end

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

    always @(posedge clock) begin
        if (sreset === 1'b0 && m_tvalid[2] === 1'b1 && m_tready[2] === 1'b1) begin
            if (mon_idx[2] >= exp_count[2]) begin
                errors = errors + 1;
                $error("out2: unexpected beat %02x", m_tdata[23:16]);
            end
            else if ({m_info, m_tlast[2], m_tuser[2], m_tdata[23:16]} !== exp2[mon_idx[2]]) begin
                errors = errors + 1;
                $error("out2 beat %0d mismatch", mon_idx[2]);
            end
            mon_idx[2] = mon_idx[2] + 1;
        end
    end

endmodule
