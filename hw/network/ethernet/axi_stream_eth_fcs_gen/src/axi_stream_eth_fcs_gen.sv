//-----------------------------------------------------------------------------
// Title         : AXI Stream Ethernet FCS Generator
//-----------------------------------------------------------------------------
// File          : axi_stream_eth_fcs_gen.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-23
// Last modified : 2026-08-23
//-----------------------------------------------------------------------------
// Description: This module appends the Ethernet FCS to a byte-wide AXI
// stream frame. The input frame starts at the destination MAC (preamble
// and SFD belong to the MAC transmitter), which is exactly the CRC-32
// coverage. Frames shorter than MIN_FRAME_BYTES are zero-padded first, so
// with the default of 60 the output meets the 64-byte minimum once the 4
// FCS bytes are counted. The FCS is sent least significant byte first, as
// the wire expects.
//
// A beat with s_axi_tuser set aborts the frame: from that beat on the
// input is passed through unchanged, tuser and tlast included, and neither
// padding nor a valid FCS is appended — so a downstream MAC drains it and
// the far end can never accept the remains as a valid frame.
//-----------------------------------------------------------------------------
// Copyright (c) 2026 by Christophe Clienti. This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module axi_stream_eth_fcs_gen #(
    parameter int MIN_FRAME_BYTES = 60  // frame length before FCS, 0 disables padding
)(
    input logic        clock,
    input logic        sreset,

    // AXI Stream input, one frame byte per beat
    input logic [7:0]  s_axi_tdata,
    input logic        s_axi_tuser,
    input logic        s_axi_tvalid,
    input logic        s_axi_tlast,
    output logic       s_axi_tready,

    // AXI Stream output, the frame with padding and FCS appended
    output logic [7:0] m_axi_tdata,
    output logic       m_axi_tuser,
    output logic       m_axi_tvalid,
    output logic       m_axi_tlast,
    input logic        m_axi_tready
);

    //-------------------------------------------
    // CRC-32 (IEEE 802.3), byte step, reflected
    //-------------------------------------------
    function automatic logic [31:0] crc32_step(input logic [31:0] crc,
                                               input logic [7:0]  data);
        logic [31:0] c;
        c = crc;
        for (int i = 0; i < 8; i++) begin
            if (c[0] ^ data[i]) begin
                c = (c >> 1) ^ 32'hEDB88320;
            end
            else begin
                c = c >> 1;
            end
        end
        return c;
    endfunction

    //-------------------------------------------
    // State machine
    //-------------------------------------------
    enum logic [1:0] {
        PAYLOAD, PAD, FCS
    } state, next_state;

    logic [15:0] count;   // frame bytes sent, saturates at MIN_FRAME_BYTES
    logic [1:0]  fcs_idx;
    logic [31:0] crc;
    logic        aborted;

    always_ff @(posedge clock) begin
        if (sreset) begin
            state <= PAYLOAD;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        case (state)
            default: begin // PAYLOAD
                next_state = PAYLOAD;
                if (s_axi_tvalid && m_axi_tready) begin
                    if (s_axi_tuser || aborted) begin
                        next_state = PAYLOAD; // dead frame passes through
                    end
                    else if (s_axi_tlast) begin
                        if ({16'd0, count} + 32'd1 < 32'(MIN_FRAME_BYTES)) begin
                            next_state = PAD;
                        end
                        else begin
                            next_state = FCS;
                        end
                    end
                end
            end

            PAD: begin
                if (m_axi_tready && ({16'd0, count} + 32'd1 == 32'(MIN_FRAME_BYTES))) begin
                    next_state = FCS;
                end
                else begin
                    next_state = PAD;
                end
            end

            FCS: begin
                if (m_axi_tready && fcs_idx == 2'd3) begin
                    next_state = PAYLOAD;
                end
                else begin
                    next_state = FCS;
                end
            end
        endcase
    end

    //-------------------------------------------
    // Frame byte counter, CRC and FCS index
    //-------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            count   <= '0;
            crc     <= 32'hFFFFFFFF;
            fcs_idx <= 2'd0;
            aborted <= 1'b0;
        end
        else begin
            case (state)
                default: begin // PAYLOAD
                    if (s_axi_tvalid && s_axi_tready) begin
                        if (s_axi_tuser || aborted) begin
                            if (s_axi_tlast) begin
                                count   <= '0;
                                crc     <= 32'hFFFFFFFF;
                                aborted <= 1'b0;
                            end
                            else begin
                                aborted <= 1'b1;
                            end
                        end
                        else begin
                            crc <= crc32_step(crc, s_axi_tdata);
                            if (count < 16'(MIN_FRAME_BYTES)) begin
                                count <= count + 16'd1;
                            end
                        end
                    end
                end

                PAD: begin
                    if (m_axi_tready) begin
                        crc   <= crc32_step(crc, 8'h00);
                        count <= count + 16'd1;
                    end
                end

                FCS: begin
                    if (m_axi_tready) begin
                        if (fcs_idx == 2'd3) begin
                            count   <= '0;
                            crc     <= 32'hFFFFFFFF;
                            fcs_idx <= 2'd0;
                        end
                        else begin
                            fcs_idx <= fcs_idx + 2'd1;
                        end
                    end
                end
            endcase
        end
    end

    //-------------------------------------------
    // Outputs
    //-------------------------------------------
    logic [31:0] fcs_val;
    logic [7:0]  fcs_byte;

    // The FCS is the complemented CRC, sent low byte first
    assign fcs_val  = ~crc;
    assign fcs_byte = fcs_val[8*fcs_idx +: 8];

    always_comb begin
        case (state)
            PAD: begin
                m_axi_tdata  = 8'h00;
                m_axi_tuser  = 1'b0;
                m_axi_tvalid = 1'b1;
                m_axi_tlast  = 1'b0;
                s_axi_tready = 1'b0;
            end

            FCS: begin
                m_axi_tdata  = fcs_byte;
                m_axi_tuser  = 1'b0;
                m_axi_tvalid = 1'b1;
                m_axi_tlast  = (fcs_idx == 2'd3);
                s_axi_tready = 1'b0;
            end

            default: begin // PAYLOAD
                m_axi_tdata  = s_axi_tdata;
                m_axi_tuser  = s_axi_tuser;
                m_axi_tvalid = s_axi_tvalid;
                // An aborted frame keeps its own tlast, a live one gets
                // it on the last FCS byte instead
                m_axi_tlast  = s_axi_tlast && (s_axi_tuser || aborted);
                s_axi_tready = m_axi_tready;
            end
        endcase
    end

endmodule
