//-----------------------------------------------------------------------------
// Title         : AXI Stream Ethernet FCS Generator Testbench
//-----------------------------------------------------------------------------
// File          : axi_stream_eth_fcs_gen_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-23
// Last modified : 2026-08-23
//-----------------------------------------------------------------------------
// Description :
// Testbench of the AXI Stream Ethernet FCS Generator. Every output beat is
// compared against a recorded expectation: payload passed through, zero
// padding up to 60 bytes, and the FCS values, which were computed offline
// with zlib.crc32 so the CRC implementation is checked against an
// independent reference, not against itself. The output side applies
// random backpressure throughout. Aborted frames (tuser) must pass
// through untouched, without padding or FCS.
//-----------------------------------------------------------------------------
// Copyright (c) 2026 by Christophe Clienti. This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module axi_stream_eth_fcs_gen_tb;
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

    logic [7:0] s_axi_tdata;
    logic       s_axi_tuser;
    logic       s_axi_tvalid;
    logic       s_axi_tlast;
    logic       s_axi_tready;

    logic [7:0] m_axi_tdata;
    logic       m_axi_tuser;
    logic       m_axi_tvalid;
    logic       m_axi_tlast;
    logic       m_axi_tready;

    integer     errors = 0;

    //----------------------------------------------------------------
    // DUT
    //----------------------------------------------------------------
    axi_stream_eth_fcs_gen
    #(
        .MIN_FRAME_BYTES (MIN_FRAME_BYTES)
    )
    axi_stream_eth_fcs_gen_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (s_axi_tdata),
        .s_axi_tuser  (s_axi_tuser),
        .s_axi_tvalid (s_axi_tvalid),
        .s_axi_tlast  (s_axi_tlast),
        .s_axi_tready (s_axi_tready),
        .m_axi_tdata  (m_axi_tdata),
        .m_axi_tuser  (m_axi_tuser),
        .m_axi_tvalid (m_axi_tvalid),
        .m_axi_tlast  (m_axi_tlast),
        .m_axi_tready (m_axi_tready)
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
    // Random backpressure on the output side
    //----------------------------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            m_axi_tready <= 1'b1;
        end
        else begin
            m_axi_tready <= $urandom_range(0, 1) == 1 ? 1'b1 : 1'b0;
        end
    end

    //----------------------------------------------------------------
    // Expected output beats, recorded by the driver: {last, user, data}
    //----------------------------------------------------------------
    logic [9:0] exp_beats [0:MAX_BEATS-1];
    integer     exp_count = 0;
    integer     mon_idx = 0;

    task automatic push_exp(input logic last, input logic user, input logic [7:0] data);
        exp_beats[exp_count] = {last, user, data};
        exp_count = exp_count + 1;
    endtask

    //----------------------------------------------------------------
    // Driver
    //----------------------------------------------------------------
    logic [7:0] frame_bytes [0:127];
    logic [7:0] fcs_bytes [0:3];

    task automatic send_beat(input logic [7:0] data, input logic last, input logic user);
        s_axi_tvalid <= 1'b1;
        s_axi_tdata  <= data;
        s_axi_tlast  <= last;
        s_axi_tuser  <= user;
        @(posedge clock);
        while (s_axi_tready !== 1'b1) @(posedge clock);
    endtask

    task automatic idle_beats(input integer cycles);
        s_axi_tvalid <= 1'b0;
        s_axi_tlast  <= 1'b0;
        s_axi_tuser  <= 1'b0;
        repeat (cycles) @(posedge clock);
    endtask

    // Send frame_bytes[0:nbytes-1] and expect it back with zero padding
    // up to MIN_FRAME_BYTES and fcs_bytes appended
    task automatic send_frame(input integer nbytes);
        for (int i = 0; i < nbytes; i++) begin
            push_exp(1'b0, 1'b0, frame_bytes[i]);
        end
        for (int i = nbytes; i < MIN_FRAME_BYTES; i++) begin
            push_exp(1'b0, 1'b0, 8'h00);
        end
        for (int i = 0; i < 4; i++) begin
            push_exp(i == 3, 1'b0, fcs_bytes[i]);
        end
        for (int i = 0; i < nbytes; i++) begin
            send_beat(frame_bytes[i], i == nbytes-1, 1'b0);
        end
        s_axi_tvalid <= 1'b0;
        s_axi_tlast  <= 1'b0;
    endtask

    //----------------------------------------------------------------
    // Test sequence. FCS references computed with python3:
    //   zlib.crc32(payload + padding) little-endian
    //----------------------------------------------------------------
    initial begin
        s_axi_tvalid = 1'b0;
        s_axi_tdata  = 8'h00;
        s_axi_tlast  = 1'b0;
        s_axi_tuser  = 1'b0;

        wait (sreset === 1'b0);
        @(posedge clock);

        // Exactly MIN_FRAME_BYTES: no padding
        for (int i = 0; i < 60; i++) frame_bytes[i] = 8'(i);
        fcs_bytes[0] = 8'hEE; fcs_bytes[1] = 8'h7F; fcs_bytes[2] = 8'hEC; fcs_bytes[3] = 8'hB0;
        send_frame(60);

        // Short frame, 50 padding bytes, sent back to back
        for (int i = 0; i < 10; i++) frame_bytes[i] = 8'(8'hD0 - 15*i);
        fcs_bytes[0] = 8'hEF; fcs_bytes[1] = 8'hBB; fcs_bytes[2] = 8'h87; fcs_bytes[3] = 8'h73;
        send_frame(10);

        // One byte over the minimum: no padding
        for (int i = 0; i < 61; i++) frame_bytes[i] = 8'(3*i + 7);
        fcs_bytes[0] = 8'hD9; fcs_bytes[1] = 8'hBE; fcs_bytes[2] = 8'hC0; fcs_bytes[3] = 8'h58;
        send_frame(61);
        idle_beats(10);

        // Aborted frame: tuser mid-frame, everything passes through
        // unchanged and no padding or FCS may follow
        push_exp(1'b0, 1'b0, 8'h21);
        push_exp(1'b0, 1'b1, 8'h42);
        push_exp(1'b0, 1'b0, 8'h63);
        push_exp(1'b1, 1'b0, 8'h84);
        send_beat(8'h21, 1'b0, 1'b0);
        send_beat(8'h42, 1'b0, 1'b1);
        send_beat(8'h63, 1'b0, 1'b0);
        send_beat(8'h84, 1'b1, 1'b0);
        idle_beats(5);

        // Single-beat dead frame: tuser and tlast together
        push_exp(1'b1, 1'b1, 8'hE7);
        send_beat(8'hE7, 1'b1, 1'b1);
        idle_beats(5);

        // Minimal frame after the aborts: the generator must have reset
        // its counter and CRC
        frame_bytes[0] = 8'hA5;
        fcs_bytes[0] = 8'h97; fcs_bytes[1] = 8'h10; fcs_bytes[2] = 8'h34; fcs_bytes[3] = 8'hBC;
        send_frame(1);
        idle_beats(200);

        if (mon_idx != exp_count) begin
            errors = errors + 1;
            $error("output stream incomplete: %0d beats seen, %0d expected",
                   mon_idx, exp_count);
        end

        if (errors == 0)
          $display("axi_stream_eth_fcs_gen_tb: ALL TESTS PASSED");
        else
          $display("axi_stream_eth_fcs_gen_tb: %0d ERROR(S)", errors);
        $finish;
    end

    //----------------------------------------------------------------
    // Check outputs
    //----------------------------------------------------------------
    always @(posedge clock) begin
        if (sreset === 1'b0 && m_axi_tvalid === 1'b1 && m_axi_tready === 1'b1) begin
            if (mon_idx >= exp_count) begin
                errors = errors + 1;
                $error("unexpected beat %02x at index %0d", m_axi_tdata, mon_idx);
            end
            else if ({m_axi_tlast, m_axi_tuser, m_axi_tdata} !== exp_beats[mon_idx]) begin
                errors = errors + 1;
                $error("beat %0d: got last=%b user=%b data=%02x, expected last=%b user=%b data=%02x",
                       mon_idx, m_axi_tlast, m_axi_tuser, m_axi_tdata,
                       exp_beats[mon_idx][9], exp_beats[mon_idx][8], exp_beats[mon_idx][7:0]);
            end
            mon_idx = mon_idx + 1;
        end
    end

endmodule
