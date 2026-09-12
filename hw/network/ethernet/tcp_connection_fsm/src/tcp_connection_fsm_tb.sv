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
// File          : tcp_connection_fsm_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-09-12
// Last modified : 2026-09-12
//-----------------------------------------------------------------------------
// Description: Exhaustive testbench of the connection machine. The
// machine is observed only through its seven output levels, the
// contract a drop-in replacement must honor, and every state has a
// unique decode, so the bench recovers the state from the outputs.
//
// For each of the six states and each of the 256 input vectors: reset,
// walk the machine to the state along its normal path (checking the
// decode at every step), apply the vector for exactly one cycle, then
// check the decode against a reference model of the README's transition
// table, priority included. The vector is dropped after one cycle, so a
// level input behaves as a pulse here and the follow-on hold with all
// inputs low is checked too. Last, reset from every state lands in
// CLOSED. The recovery of an unused encoding is not tested here: it
// would mean forcing the state register, which a tool-generated
// drop-in may encode differently or not have at all, and this bench is
// the contract both must pass. It stays a coding rule of the README.
//
// Reports tcp_connection_fsm_tb: ALL TESTS PASSED or N ERROR(S).

`timescale 1 ns / 100 ps

module tcp_connection_fsm_tb;
    //----------------------------------------------------------------
    // Reference model: states, decode and transition table
    //----------------------------------------------------------------
    // Plain integers rather than an enum: the model must not share a
    // type with the DUT, and Icarus wants casts on every enum move
    typedef int model_state_t;
    localparam int S_CLOSED      = 0;
    localparam int S_LISTEN      = 1;
    localparam int S_SYN_RCVD    = 2;
    localparam int S_ESTABLISHED = 3;
    localparam int S_CLOSE_WAIT  = 4;
    localparam int S_LAST_ACK    = 5;

    // Input vector bit order
    localparam int B_LISTEN      = 0;
    localparam int B_CLEAR_DONE  = 1;
    localparam int B_SYN_RX      = 2;
    localparam int B_CTL_ACKED   = 3;
    localparam int B_FIN_RX      = 4;
    localparam int B_RST_RX      = 5;
    localparam int B_GIVE_UP     = 6;
    localparam int B_CLOSE_READY = 7;

    // Output vector: {fin_pending, tx_open, rx_open, connected,
    //                 syn_ack_pending, listening, clear}
    function automatic logic [6:0] decode(input model_state_t s);
        case (s)
            S_LISTEN:      decode = 7'b0000010;
            S_SYN_RCVD:    decode = 7'b0000100;
            S_ESTABLISHED: decode = 7'b0111000;
            S_CLOSE_WAIT:  decode = 7'b0101000;
            S_LAST_ACK:    decode = 7'b1001000;
            default:       decode = 7'b0000001;  // S_CLOSED
        endcase
    endfunction

    function automatic string state_name(input model_state_t s);
        case (s)
            S_CLOSED:      state_name = "CLOSED";
            S_LISTEN:      state_name = "LISTEN";
            S_SYN_RCVD:    state_name = "SYN_RCVD";
            S_ESTABLISHED: state_name = "ESTABLISHED";
            S_CLOSE_WAIT:  state_name = "CLOSE_WAIT";
            default:       state_name = "LAST_ACK";
        endcase
    endfunction

    // The README's table: rst_rx and give_up first in every state past
    // LISTEN, then the single event the state waits for
    function automatic model_state_t model_next(input model_state_t s, input logic [7:0] v);
        if (s != S_CLOSED && s != S_LISTEN && (v[B_RST_RX] || v[B_GIVE_UP])) begin
            model_next = S_CLOSED;
        end
        else begin
            case (s)
                S_CLOSED:      model_next = (v[B_LISTEN] && v[B_CLEAR_DONE]) ? S_LISTEN : S_CLOSED;
                S_LISTEN:      model_next = v[B_SYN_RX]      ? S_SYN_RCVD    : S_LISTEN;
                S_SYN_RCVD:    model_next = v[B_CTL_ACKED]   ? S_ESTABLISHED : S_SYN_RCVD;
                S_ESTABLISHED: model_next = v[B_FIN_RX]      ? S_CLOSE_WAIT  : S_ESTABLISHED;
                S_CLOSE_WAIT:  model_next = v[B_CLOSE_READY] ? S_LAST_ACK    : S_CLOSE_WAIT;
                default:       model_next = v[B_CTL_ACKED]   ? S_CLOSED      : S_LAST_ACK;
            endcase
        end
    endfunction

    //----------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------
    logic       clock;
    logic       sreset;

    logic [7:0] in_vec;    // driven input vector, see the B_* bit order
    logic       listen;
    logic       clear_done;
    logic       close_ready;
    logic       syn_rx;
    logic       ctl_acked;
    logic       fin_rx;
    logic       rst_rx;
    logic       give_up;

    logic       clear;
    logic       listening;
    logic       syn_ack_pending;
    logic       connected;
    logic       rx_open;
    logic       tx_open;
    logic       fin_pending;
    logic [6:0] out_vec;   // observed output vector, decode() order

    integer     errors = 0;
    integer     checks = 0;

    assign listen      = in_vec[B_LISTEN];
    assign clear_done  = in_vec[B_CLEAR_DONE];
    assign syn_rx      = in_vec[B_SYN_RX];
    assign ctl_acked   = in_vec[B_CTL_ACKED];
    assign fin_rx      = in_vec[B_FIN_RX];
    assign rst_rx      = in_vec[B_RST_RX];
    assign give_up     = in_vec[B_GIVE_UP];
    assign close_ready = in_vec[B_CLOSE_READY];

    assign out_vec = {fin_pending, tx_open, rx_open, connected,
                      syn_ack_pending, listening, clear};

    //----------------------------------------------------------------
    // DUT
    //----------------------------------------------------------------
    tcp_connection_fsm tcp_connection_fsm_inst (
        .clock           (clock),
        .sreset          (sreset),
        .listen          (listen),
        .clear_done      (clear_done),
        .close_ready     (close_ready),
        .syn_rx          (syn_rx),
        .ctl_acked       (ctl_acked),
        .fin_rx          (fin_rx),
        .rst_rx          (rst_rx),
        .give_up         (give_up),
        .clear           (clear),
        .listening       (listening),
        .syn_ack_pending (syn_ack_pending),
        .connected       (connected),
        .rx_open         (rx_open),
        .tx_open         (tx_open),
        .fin_pending     (fin_pending)
    );

    //----------------------------------------------------------------
    // Clock
    //----------------------------------------------------------------
    initial clock = 0;
    always #10 clock = !clock;

    //----------------------------------------------------------------
    // Helpers
    //----------------------------------------------------------------
    // Outputs are read right after a rising edge, before that edge's
    // non-blocking updates land, so they reflect the state reached at
    // the previous edge
    task automatic expect_state(input model_state_t s, input string what);
        checks = checks + 1;
        if (out_vec !== decode(s)) begin
            errors = errors + 1;
            $error("%s: expected %s (%07b), got %07b", what, state_name(s), decode(s), out_vec);
        end
    endtask

    // Drive a vector for one cycle: it is presented after edge 1,
    // sampled by the machine at edge 2, and gone before edge 3
    task automatic pulse(input logic [7:0] v);
        @(posedge clock);
        in_vec <= v;
        @(posedge clock);
        in_vec <= 8'h00;
    endtask

    task automatic reset_dut();
        @(posedge clock);
        sreset <= 1'b1;
        in_vec <= 8'h00;
        @(posedge clock);
        @(posedge clock);
        sreset <= 1'b0;
        @(posedge clock);
        expect_state(S_CLOSED, "after reset");
    endtask

    // Walk from CLOSED to the target along the normal path, checking
    // every step
    task automatic goto_state(input model_state_t target);
        model_state_t path [0:5];
        logic [7:0]   step [0:5];
        integer       n;

        path[0] = S_LISTEN;      step[0] = (8'h1 << B_LISTEN) | (8'h1 << B_CLEAR_DONE);
        path[1] = S_SYN_RCVD;    step[1] = 8'h1 << B_SYN_RX;
        path[2] = S_ESTABLISHED; step[2] = 8'h1 << B_CTL_ACKED;
        path[3] = S_CLOSE_WAIT;  step[3] = 8'h1 << B_FIN_RX;
        path[4] = S_LAST_ACK;    step[4] = 8'h1 << B_CLOSE_READY;

        reset_dut();
        for (n = 0; n < 5; n = n + 1) begin
            if (target > n) begin
                pulse(step[n]);
                @(posedge clock);
                expect_state(path[n], $sformatf("walk to %s", state_name(path[n])));
            end
        end
    endtask

    //----------------------------------------------------------------
    // Test sequence
    //----------------------------------------------------------------
    model_state_t   s;
    model_state_t   s_next;
    integer         v;
    integer         st;

    initial begin
        sreset = 1'b1;
        in_vec = 8'h00;

        //------------------------------------------------------------
        // 1. Every state, every input vector, one cycle each
        //------------------------------------------------------------
        for (st = 0; st <= S_LAST_ACK; st = st + 1) begin
            s = st;
            for (v = 0; v < 256; v = v + 1) begin
                goto_state(s);
                pulse(v[7:0]);
                @(posedge clock);
                s_next = model_next(s, v[7:0]);
                expect_state(s_next, $sformatf("%s + vector %08b", state_name(s), v[7:0]));
                // One more cycle with everything low: the successor holds
                @(posedge clock);
                expect_state(s_next, $sformatf("%s + vector %08b, hold", state_name(s), v[7:0]));
            end
        end

        //------------------------------------------------------------
        // 2. Reset from every state lands in CLOSED
        //------------------------------------------------------------
        for (st = 0; st <= S_LAST_ACK; st = st + 1) begin
            s = st;
            goto_state(s);
            @(posedge clock);
            sreset <= 1'b1;
            @(posedge clock);
            sreset <= 1'b0;
            @(posedge clock);
            expect_state(S_CLOSED, $sformatf("reset from %s", state_name(s)));
        end

        //------------------------------------------------------------
        // Verdict
        //------------------------------------------------------------
        @(posedge clock);
        $display("tcp_connection_fsm_tb: %0d checks", checks);
        if (errors == 0)
            $display("tcp_connection_fsm_tb: ALL TESTS PASSED");
        else
            $display("tcp_connection_fsm_tb: %0d ERROR(S)", errors);
        $finish;
    end

    // Watchdog
    initial begin
        #10000000;
        errors = errors + 1;
        $error("watchdog: %0d checks done", checks);
        $display("tcp_connection_fsm_tb: %0d ERROR(S)", errors);
        $finish;
    end

endmodule
