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
// Title         : TCP Connection FSM
//-----------------------------------------------------------------------------
// File          : tcp_connection_fsm.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-09-12
// Last modified : 2026-09-12
//-----------------------------------------------------------------------------
// Description: The connection state machine of the TCP socket, the
// passive-server half of the RFC 793 diagram: CLOSED, LISTEN, SYN_RCVD,
// ESTABLISHED, CLOSE_WAIT, LAST_ACK. It holds no sequence number, no
// timer and no buffer; it sees the network only as events the socket's
// receive walker has already qualified against the connection record,
// plus three levels the socket computes, and its outputs are levels
// decoded from the state.
//
// Events are resolved in a fixed order: rst_rx first, then give_up, then
// the one event the current state waits for; a pulse a state does not
// wait for is ignored. CLOSED holds until the socket reports the
// clean-up done and listen is high. There is no arc from SYN_RCVD to
// CLOSE_WAIT: the walker accepts a FIN only under rx_open, so fin_rx
// cannot occur there.
//
// This block is a benchmark for an FSM synthesis flow, so it is written
// for extraction: one enumerated state, one registered process, one
// next-state process, one outputs process, Moore outputs only, every
// state named in the case and a default that recovers to CLOSED, no
// counter or arithmetic in any condition.

`timescale 1 ns / 100 ps

module tcp_connection_fsm (
    input logic  clock,
    input logic  sreset,

    // Levels the socket computes
    input logic  listen,       // leave CLOSED for LISTEN once the clean-up is done
    input logic  clear_done,   // the clean-up asked for by clear is finished
    input logic  close_ready,  // our FIN may go: token in, ring empty, all acknowledged

    // One-cycle events, from the receive walker or the timer side
    input logic  syn_rx,       // acceptable SYN for the listening port
    input logic  ctl_acked,    // the outstanding control segment is acknowledged
    input logic  fin_rx,       // in-order FIN from the connected peer
    input logic  rst_rx,       // acceptable RST from the connected peer
    input logic  give_up,      // the socket gives the connection up

    // Moore levels, decoded from the state
    output logic clear,            // CLOSED: send the reset owed, drop, flush, clear
    output logic listening,        // LISTEN: a SYN may be accepted
    output logic syn_ack_pending,  // SYN_RCVD: a SYN-ACK is owed
    output logic connected,        // ESTABLISHED to LAST_ACK: the record is valid
    output logic rx_open,          // ESTABLISHED: in-order data is stored
    output logic tx_open,          // ESTABLISHED, CLOSE_WAIT: application bytes are sent
    output logic fin_pending       // LAST_ACK: a FIN is owed
);

    //-------------------------------------------
    // State
    //-------------------------------------------
    enum logic [2:0] {
        CLOSED, LISTEN, SYN_RCVD, ESTABLISHED, CLOSE_WAIT, LAST_ACK
    } state, next_state;  // registered state and its combinational successor

    always_ff @(posedge clock) begin
        if (sreset) begin
            state <= CLOSED;
        end
        else begin
            state <= next_state;
        end
    end

    //-------------------------------------------
    // Next state: rst_rx, then give_up, then the
    // event the state waits for
    //-------------------------------------------
    always_comb begin
        case (state)
            CLOSED: begin
                if (listen && clear_done) begin
                    next_state = LISTEN;
                end
                else begin
                    next_state = CLOSED;
                end
            end

            LISTEN: begin
                if (syn_rx) begin
                    next_state = SYN_RCVD;
                end
                else begin
                    next_state = LISTEN;
                end
            end

            SYN_RCVD: begin
                if (rst_rx) begin
                    next_state = CLOSED;
                end
                else if (give_up) begin
                    next_state = CLOSED;
                end
                else if (ctl_acked) begin
                    next_state = ESTABLISHED;
                end
                else begin
                    next_state = SYN_RCVD;
                end
            end

            ESTABLISHED: begin
                if (rst_rx) begin
                    next_state = CLOSED;
                end
                else if (give_up) begin
                    next_state = CLOSED;
                end
                else if (fin_rx) begin
                    next_state = CLOSE_WAIT;
                end
                else begin
                    next_state = ESTABLISHED;
                end
            end

            CLOSE_WAIT: begin
                if (rst_rx) begin
                    next_state = CLOSED;
                end
                else if (give_up) begin
                    next_state = CLOSED;
                end
                else if (close_ready) begin
                    next_state = LAST_ACK;
                end
                else begin
                    next_state = CLOSE_WAIT;
                end
            end

            LAST_ACK: begin
                if (rst_rx) begin
                    next_state = CLOSED;
                end
                else if (give_up) begin
                    next_state = CLOSED;
                end
                else if (ctl_acked) begin
                    next_state = CLOSED;
                end
                else begin
                    next_state = LAST_ACK;
                end
            end

            default: begin
                next_state = CLOSED;  // unused encodings recover
            end
        endcase
    end

    //-------------------------------------------
    // Outputs: Moore, one decode per state
    //-------------------------------------------
    always_comb begin
        case (state)
            LISTEN: begin
                clear           = 1'b0;
                listening       = 1'b1;
                syn_ack_pending = 1'b0;
                connected       = 1'b0;
                rx_open         = 1'b0;
                tx_open         = 1'b0;
                fin_pending     = 1'b0;
            end

            SYN_RCVD: begin
                clear           = 1'b0;
                listening       = 1'b0;
                syn_ack_pending = 1'b1;
                connected       = 1'b0;
                rx_open         = 1'b0;
                tx_open         = 1'b0;
                fin_pending     = 1'b0;
            end

            ESTABLISHED: begin
                clear           = 1'b0;
                listening       = 1'b0;
                syn_ack_pending = 1'b0;
                connected       = 1'b1;
                rx_open         = 1'b1;
                tx_open         = 1'b1;
                fin_pending     = 1'b0;
            end

            CLOSE_WAIT: begin
                clear           = 1'b0;
                listening       = 1'b0;
                syn_ack_pending = 1'b0;
                connected       = 1'b1;
                rx_open         = 1'b0;
                tx_open         = 1'b1;
                fin_pending     = 1'b0;
            end

            LAST_ACK: begin
                clear           = 1'b0;
                listening       = 1'b0;
                syn_ack_pending = 1'b0;
                connected       = 1'b1;
                rx_open         = 1'b0;
                tx_open         = 1'b0;
                fin_pending     = 1'b1;
            end

            default: begin  // CLOSED, and the unused encodings on their way there
                clear           = 1'b1;
                listening       = 1'b0;
                syn_ack_pending = 1'b0;
                connected       = 1'b0;
                rx_open         = 1'b0;
                tx_open         = 1'b0;
                fin_pending     = 1'b0;
            end
        endcase
    end

endmodule
