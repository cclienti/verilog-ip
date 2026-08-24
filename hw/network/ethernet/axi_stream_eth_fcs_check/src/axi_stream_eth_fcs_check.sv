//-----------------------------------------------------------------------------
// Title         : AXI Stream Ethernet FCS Checker
//-----------------------------------------------------------------------------
// File          : axi_stream_eth_fcs_check.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-23
// Last modified : 2026-08-23
//-----------------------------------------------------------------------------
// Description: This module verifies and strips the Ethernet FCS of a
// byte-wide AXI stream frame. The frame end is only known when tlast
// arrives, so the stream is delayed by four bytes: when the last input
// byte shows up, the delay line holds exactly the FCS, the output is
// asserting tlast on the last payload byte, and the received FCS is
// compared against the CRC-32 computed over the emitted bytes.
//
// m_axi_tuser raised with m_axi_tlast marks a frame to drop: the FCS
// did not match, or the source flagged the frame with s_axi_tuser on
// any beat. A frame of four bytes or fewer has no payload at all and
// is dropped silently, nothing is emitted.
//-----------------------------------------------------------------------------
// Copyright (c) 2026 by Christophe Clienti. This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module axi_stream_eth_fcs_check (
    input logic        clock,
    input logic        sreset,

    // AXI Stream input, the frame with its FCS
    input logic [7:0]  s_axi_tdata,
    input logic        s_axi_tuser,
    input logic        s_axi_tvalid,
    input logic        s_axi_tlast,
    output logic       s_axi_tready,

    // AXI Stream output, the frame without its FCS
    output logic [7:0] m_axi_tdata,
    output logic       m_axi_tuser,
    output logic       m_axi_tvalid,
    output logic       m_axi_tlast,
    input logic        m_axi_tready
);

    //-------------------------------------------
    // Four-byte delay line
    //-------------------------------------------
    logic [7:0]  pipe [0:3];  // pipe[0] newest, pipe[3] oldest
    logic [2:0]  fill;
    logic [31:0] crc;
    logic        frame_err;
    logic        filled;

    assign filled = (fill == 3'd4);

    // Until the delay line is full the input is swallowed without any
    // output beat; afterwards input and output move together
    assign s_axi_tready = filled ? m_axi_tready : 1'b1;
    assign m_axi_tvalid = s_axi_tvalid && filled;
    assign m_axi_tdata  = pipe[3];
    assign m_axi_tlast  = s_axi_tlast && filled;

    //-------------------------------------------
    // FCS comparison, valid on the tlast beat only
    //-------------------------------------------
    logic [31:0] crc_next;
    logic [31:0] fcs_val;
    logic        fcs_ok;

    // CRC over every emitted byte, the one leaving the pipe included
    crc32 crc32_inst (
        .crc_in  (crc),
        .data    (pipe[3]),
        .crc_out (crc_next)
    );

    assign fcs_val = ~crc_next;

    // On the tlast beat the received FCS is pipe[2] (oldest, first on
    // the wire) up to the incoming byte (last on the wire)
    assign fcs_ok = (pipe[2] == fcs_val[7:0]) &&
                    (pipe[1] == fcs_val[15:8]) &&
                    (pipe[0] == fcs_val[23:16]) &&
                    (s_axi_tdata == fcs_val[31:24]);

    assign m_axi_tuser = m_axi_tlast && (!fcs_ok || frame_err || s_axi_tuser);

    //-------------------------------------------
    // Delay line, fill level and running CRC
    //-------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            fill      <= '0;
            crc       <= 32'hFFFFFFFF;
            frame_err <= 1'b0;
        end
        else if (s_axi_tvalid && s_axi_tready) begin
            if (s_axi_tlast) begin
                fill      <= '0;
                crc       <= 32'hFFFFFFFF;
                frame_err <= 1'b0;
            end
            else begin
                pipe[0] <= s_axi_tdata;
                pipe[1] <= pipe[0];
                pipe[2] <= pipe[1];
                pipe[3] <= pipe[2];
                if (filled) begin
                    crc <= crc_next; // a payload byte left the pipe
                end
                else begin
                    fill <= fill + 3'd1;
                end
                if (s_axi_tuser) begin
                    frame_err <= 1'b1;
                end
            end
        end
    end

endmodule
