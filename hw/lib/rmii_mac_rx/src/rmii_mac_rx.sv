//-----------------------------------------------------------------------------
// Title         : RMII MAC Receiver (Fast Ethernet)
//-----------------------------------------------------------------------------
// File          : rmii_mac_rx.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2025-07-28
// Last modified : 2025-07-28
//-----------------------------------------------------------------------------
// Description: This module implements a simple RMII MAC receiver for Fast
// Ethernet. It receives data from the PHY and outputs Ethernet frame as a AXI
// stream data. The preamble and SFD are not sent to the AXI stream, only the
// payload is.
//-----------------------------------------------------------------------------
// Copyright (c) 2025 by Christophe Clienti. This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module rmii_mac_rx (
    input logic        clock,      // Clock signal, 50 MHz
    input logic        srst,       // Synchronous reset, active high

    input logic [1:0]  rxd,        // RXD is the data received from the PHY, 2 bits for RMII
    input logic        rxen,       // RXEN is high when the PHY is sending data

    output logic       axi_tvalid, // Indicates that the AXI stream data is valid
    output logic       axi_tlast,  // Indicates the last data in the frame
    output logic [1:0] axi_tdata,  // Data to be sent on the AXI stream
    output logic       axi_tuser,  // Indicates an error in the frame
    input logic        axi_tready  // Indicates that the AXI stream is ready to accept data
);

    //-------------------------------------------
    // Input synchronization
    //-------------------------------------------
    localparam int SYNC_DEPTH = 5;

    logic [1:0]    rxd_d [0:SYNC_DEPTH-1];
    logic          rxen_d [0:SYNC_DEPTH-1];

    always @(posedge clock) begin
        if (srst) begin
            for(int i = 0; i < SYNC_DEPTH; i++) begin
                rxd_d[i]  <= 2'b00;
                rxen_d[i] <= 1'b0;
            end
        end
        else begin
            for(int i = 1; i <= SYNC_DEPTH; i++) begin
                rxd_d[i]  <= rxd_d[i-1];
                rxen_d[i] <= rxen_d[i-1];
            end
            rxd_d[0]  <= rxd;
            rxen_d[0] <= rxen;
        end
    end

    //-------------------------------------------
    // Detect start/end of frame
    //-------------------------------------------
    logic rxen_falling;
    logic rxen_rising;
    assign rxen_falling = rxen_d[1] && !rxen_d[0];
    assign rxen_rising = !rxen_d[1] && rxen_d[0];

    //--------------------------------------------
    // SFD detection logic
    // --------------------------------------------
    logic sfd_detected;
    // Should be 0xD5 but we want also to detect 0xD6 to handle the
    // case where the PHY sends a 0xD6 instead of 0xD5.
    always_ff @(posedge clock or posedge srst) begin
        if (srst) begin
            sfd_detected <= 1'b0;
        end else begin
            // Check for SFD: 0xD5 (11010101) or 0xD6 (11010110)
            sfd_detected <= (rxd_d[1][1] & rxd_d[1][0]) &
                            (rxd_d[2][1] ^ rxd_d[2][0]) &
                            (rxd_d[3][1] ^ rxd_d[3][0]) &
                            (rxd_d[4][1] ^ rxd_d[4][0]);
        end
    end

    //-------------------------------------------
    // State machine for AXI stream control
    //-------------------------------------------
    enum logic [2:0] {
        IDLE, START, DATA, LAST, ERROR, DROP
    } state, next_state;

    always_ff @(posedge clock or posedge srst) begin
        if (srst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        case (state)
            default: begin
                if (rxen_rising) begin
                    next_state = START;
                end
                else begin
                    next_state = IDLE;
                end
            end

            START: begin
                if (rxen_falling) begin
                    next_state = DROP; // Error if RXEN falls before SFD
                end
                else begin
                    if (sfd_detected) begin
                        if (!axi_tready) begin
                            next_state = DROP;
                        end
                        else begin
                            next_state = DATA; // Start receiving data
                        end
                    end
                    else begin
                        next_state = START; // Wait for SFD
                    end
                end
            end

            DATA: begin
                if (!axi_tready) begin
                    next_state = ERROR; // AXI stream not ready
                end
                else begin
                    if (rxen_falling) begin
                        next_state = LAST; // End of frame
                    end
                    else begin
                        next_state = DATA; // Continue receiving data
                    end
                end
            end

            LAST: begin
                if (!axi_tready) begin
                    next_state = ERROR; // AXI stream not ready
                end
                else begin
                    next_state = IDLE; // Continue receiving data
                end
            end

            ERROR: begin
                if (!axi_tready) begin
                    next_state = ERROR; // AXI stream not ready
                end
                else begin
                    next_state = IDLE; // Reset to IDLE after error
                end
            end

            DROP: begin
                next_state = IDLE; // Drop frame and reset to IDLE
            end
        endcase
    end

    always_comb begin
        case (state)
            default: begin
                axi_tvalid = 1'b0;
                axi_tlast = 1'b0;
                axi_tuser = 1'b0;
            end

            START: begin
                axi_tvalid = 1'b0;
                axi_tlast = 1'b0;
                axi_tuser = 1'b0;
            end

            DATA: begin
                axi_tvalid = 1'b1;
                axi_tlast = 1'b0;
                axi_tuser = 1'b0;
            end

            LAST: begin
                axi_tvalid = 1'b1;
                axi_tlast = 1'b1;
                axi_tuser = 1'b0;
            end

            ERROR: begin
                axi_tvalid = 1'b1;
                axi_tlast = 1'b1;
                axi_tuser = 1'b1;
            end

            DROP: begin
                axi_tvalid = 1'b0;
                axi_tlast = 1'b0;
                axi_tuser = 1'b0;
            end
        endcase
    end

    //-------------------------------------------
    // Manage TData
    //-------------------------------------------
    assign axi_tdata = rxd_d[SYNC_DEPTH-3];

endmodule
