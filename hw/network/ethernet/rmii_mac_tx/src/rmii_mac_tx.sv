//-----------------------------------------------------------------------------
// Title         : RMII MAC Transmitter (Fast Ethernet)
//-----------------------------------------------------------------------------
// File          : rmii_mac_tx.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-23
// Last modified : 2026-08-23
//-----------------------------------------------------------------------------
// Description: This module implements a simple RMII MAC transmitter for Fast
// Ethernet, counterpart of rmii_mac_rx. It reads an Ethernet frame from an
// AXI stream (2-bit data, one dibit per beat, low bits first) and drives the
// PHY. The preamble and SFD are generated here, so the AXI stream carries
// only the frame itself (the FCS included, nothing here computes it). The
// inter-frame gap of 96 bit times is enforced by holding axi_tready low.
//
// The line cannot pause: once the payload starts, the source must provide
// one beat per clock until axi_tlast. If axi_tvalid drops mid-frame, the
// frame is truncated on the wire (the receiver will drop it on FCS) and the
// remaining beats are consumed and discarded up to axi_tlast. Asserting
// axi_tuser on a beat aborts the frame the same way: that beat is not
// transmitted, and the rest of the frame is discarded.
//-----------------------------------------------------------------------------
// Copyright (c) 2026 by Christophe Clienti. This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module rmii_mac_tx (
    input logic        clock,      // Clock signal, 50 MHz
    input logic        srst,       // Synchronous reset, active high

    input logic        axi_tvalid, // Indicates that the AXI stream data is valid
    input logic        axi_tlast,  // Indicates the last data in the frame
    input logic [1:0]  axi_tdata,  // Frame dibit, sent as TXD[1:0]
    input logic        axi_tuser,  // Aborts the frame when asserted with tvalid
    output logic       axi_tready, // Indicates that a dibit is consumed this cycle

    output logic [1:0] txd,        // TXD is the data sent to the PHY, 2 bits for RMII
    output logic       txen        // TXEN is high while a frame is being sent
);

    //-------------------------------------------
    // Constants
    //-------------------------------------------
    // 7 preamble bytes plus the SFD, 4 dibits per byte
    localparam int PREAMBLE_DIBITS = 32;
    // 96 bit times at 2 bits per clock
    localparam int IFG_CLOCKS = 48;

    //-------------------------------------------
    // State machine
    //-------------------------------------------
    enum logic [2:0] {
        IDLE, PREAMBLE, DATA, DRAIN, IFG
    } state, next_state;

    logic [5:0] count;

    always_ff @(posedge clock) begin
        if (srst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // The counter paces PREAMBLE and IFG; it restarts on every state change
    always_ff @(posedge clock) begin
        if (srst || (state != next_state)) begin
            count <= '0;
        end else begin
            count <= count + 6'd1;
        end
    end

    always_comb begin
        case (state)
            default: begin
                if (axi_tvalid) begin
                    next_state = PREAMBLE;
                end
                else begin
                    next_state = IDLE;
                end
            end

            PREAMBLE: begin
                if (count == 6'(PREAMBLE_DIBITS-1)) begin
                    next_state = DATA; // SFD sent, start the payload
                end
                else begin
                    next_state = PREAMBLE;
                end
            end

            DATA: begin
                if (!axi_tvalid) begin
                    next_state = DRAIN; // Underflow, the frame is truncated
                end
                else if (axi_tuser) begin
                    if (axi_tlast) begin
                        next_state = IFG; // Aborted on its last beat
                    end
                    else begin
                        next_state = DRAIN; // Aborted by the source
                    end
                end
                else if (axi_tlast) begin
                    next_state = IFG; // End of frame
                end
                else begin
                    next_state = DATA; // Continue sending data
                end
            end

            DRAIN: begin
                if (axi_tvalid && axi_tlast) begin
                    next_state = IFG; // Rest of the dead frame discarded
                end
                else begin
                    next_state = DRAIN;
                end
            end

            IFG: begin
                if (count == 6'(IFG_CLOCKS-1)) begin
                    next_state = IDLE; // Gap elapsed, a new frame may start
                end
                else begin
                    next_state = IFG;
                end
            end
        endcase
    end

    //-------------------------------------------
    // Outputs
    //-------------------------------------------
    logic [1:0] txd_next;
    logic       txen_next;

    always_comb begin
        case (state)
            PREAMBLE: begin
                // Every byte is 0x55 except the SFD 0xD5, sent low dibit
                // first, so the wire sees 31 times "01" then one "11"
                txd_next   = (count == 6'(PREAMBLE_DIBITS-1)) ? 2'b11 : 2'b01;
                txen_next  = 1'b1;
                axi_tready = 1'b0;
            end

            DATA: begin
                txd_next   = axi_tdata;
                txen_next  = axi_tvalid && !axi_tuser;
                axi_tready = 1'b1;
            end

            DRAIN: begin
                txd_next   = 2'b00;
                txen_next  = 1'b0;
                axi_tready = 1'b1;
            end

            default: begin // IDLE, IFG
                txd_next   = 2'b00;
                txen_next  = 1'b0;
                axi_tready = 1'b0;
            end
        endcase
    end

    // Registered PHY outputs
    always_ff @(posedge clock) begin
        if (srst) begin
            txd  <= 2'b00;
            txen <= 1'b0;
        end else begin
            txd  <= txd_next;
            txen <= txen_next;
        end
    end

endmodule
