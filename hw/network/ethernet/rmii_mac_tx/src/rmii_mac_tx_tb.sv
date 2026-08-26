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
// Title         : RMII MAC Transmitter (Fast Ethernet)
//-----------------------------------------------------------------------------
// File          : rmii_mac_tx_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-23
// Last modified : 2026-08-23
//-----------------------------------------------------------------------------
// Description :
// Testbench of the RMII MAC Transmitter module. Every dibit expected on the
// wire is recorded when a beat is driven, and a monitor compares the TXD
// stream against that record, so the preamble, the SFD, the payload order
// and the frame lengths are all checked. A second monitor checks the
// inter-frame gap on every TXEN rising edge. An rmii_mac_rx instance loops
// the wire back to an AXI stream as an interoperability check: the receiver
// must recover exactly the transmitted payload dibits, tlast included.

`timescale 1 ns / 100 ps

module rmii_mac_tx_tb;
    //----------------------------------------------------------------
    // Constants
    //----------------------------------------------------------------
    localparam int PREAMBLE_DIBITS = 32;  // 7 preamble bytes plus the SFD
    localparam int IFG_CLOCKS      = 48;  // 96 bit times, 2 bits per clock
    localparam int MAX_DIBITS      = 2048;

    //----------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------
    logic       clock;
    logic       srst;

    logic       axi_tvalid;
    logic       axi_tlast;
    logic [1:0] axi_tdata;
    logic       axi_tuser;
    logic       axi_tready;

    logic [1:0] txd;
    logic       txen;

    logic       rx_axi_tvalid;
    logic       rx_axi_tlast;
    logic [1:0] rx_axi_tdata;
    logic       rx_axi_tuser;

    integer     errors = 0;

    //----------------------------------------------------------------
    // DUT
    //----------------------------------------------------------------
    rmii_mac_tx rmii_mac_tx_inst (
        .clock      (clock),
        .srst       (srst),
        .axi_tvalid (axi_tvalid),
        .axi_tlast  (axi_tlast),
        .axi_tdata  (axi_tdata),
        .axi_tuser  (axi_tuser),
        .axi_tready (axi_tready),
        .txd        (txd),
        .txen       (txen)
    );

    //----------------------------------------------------------------
    // Loopback receiver, always ready
    //----------------------------------------------------------------
    rmii_mac_rx rmii_mac_rx_inst (
        .clock      (clock),
        .srst       (srst),
        .rxd        (txd),
        .rxen       (txen),
        .axi_tvalid (rx_axi_tvalid),
        .axi_tlast  (rx_axi_tlast),
        .axi_tdata  (rx_axi_tdata),
        .axi_tuser  (rx_axi_tuser),
        .axi_tready (1'b1)
    );

    //----------------------------------------------------------------
    // Clock and reset generation
    //----------------------------------------------------------------
    initial begin
        clock     = 0;
        srst      = 1;
        #40 srst  = 0;
    end

    always
        #10 clock = !clock;

    //----------------------------------------------------------------
    // Expected streams, recorded by the driver as it sends
    //----------------------------------------------------------------
    logic [1:0] exp_wire [0:MAX_DIBITS-1];  // every dibit due on TXD
    integer     exp_wire_count = 0;

    logic [2:0] exp_loop [0:MAX_DIBITS-1];  // {tlast, dibit} due from the receiver
    integer     exp_loop_count = 0;

    task automatic push_wire(input logic [1:0] dibit);
        exp_wire[exp_wire_count] = dibit;
        exp_wire_count = exp_wire_count + 1;
    endtask

    task automatic push_loop(input logic last, input logic [1:0] dibit);
        exp_loop[exp_loop_count] = {last, dibit};
        exp_loop_count = exp_loop_count + 1;
    endtask

    task automatic push_preamble;
        for (int i = 0; i < PREAMBLE_DIBITS-1; i++) begin
            push_wire(2'b01);
        end
        push_wire(2'b11); // last dibit of the SFD
    endtask

    //----------------------------------------------------------------
    // Driver
    //----------------------------------------------------------------
    logic [7:0] frame_bytes [0:63];

    // Present one beat and hold it until the DUT consumes it
    task automatic send_beat(input logic [1:0] data, input logic last, input logic user);
        axi_tvalid <= 1'b1;
        axi_tdata  <= data;
        axi_tlast  <= last;
        axi_tuser  <= user;
        @(posedge clock);
        while (axi_tready !== 1'b1) @(posedge clock);
    endtask

    task automatic idle_beats(input integer cycles);
        axi_tvalid <= 1'b0;
        axi_tlast  <= 1'b0;
        axi_tuser  <= 1'b0;
        repeat (cycles) @(posedge clock);
    endtask

    // Send frame_bytes[0:nbytes-1] as a clean frame, low dibit first
    task automatic send_frame(input integer nbytes);
        logic [1:0] dibit;
        logic       last;
        push_preamble();
        for (int i = 0; i < nbytes; i++) begin
            for (int j = 0; j < 4; j++) begin
                dibit = frame_bytes[i][2*j +: 2];
                last  = (i == nbytes-1) && (j == 3);
                push_wire(dibit);
                push_loop(last, dibit);
                send_beat(dibit, last, 1'b0);
            end
        end
        axi_tvalid <= 1'b0;
        axi_tlast  <= 1'b0;
    endtask

    // Preamble expectations plus count clean dibits valued 2'(k + offset),
    // the last one closing the recovered frame. Every degraded-frame test
    // starts this way, so the expectation recording lives in one place
    // and only the degraded tail stays in each caller.
    task automatic send_clean_prefix(input integer count, input integer offset);
        logic [1:0] dibit;
        push_preamble();
        for (int k = 0; k < count; k++) begin
            dibit = 2'(k + offset);
            push_wire(dibit);
            push_loop(k == count-1, dibit);
            send_beat(dibit, 1'b0, 1'b0);
        end
    endtask

    // Source underflow: 5 dibits sent, a stall, then the rest of the
    // frame, which the DUT must consume and discard
    task automatic send_underflow_frame;
        send_clean_prefix(5, 1);
        idle_beats(4); // the wire frame ends at the stall
        for (int k = 5; k < 12; k++) begin
            send_beat(2'(k), k == 11, 1'b0); // discarded, must not reach TXD
        end
        axi_tvalid <= 1'b0;
        axi_tlast  <= 1'b0;
    endtask

    // Source abort: tuser mid-frame kills the frame from that beat on
    task automatic send_abort_frame;
        send_clean_prefix(4, 0);
        send_beat(2'b11, 1'b0, 1'b1); // aborted beat, not transmitted
        for (int k = 0; k < 6; k++) begin
            send_beat(2'b10, k == 5, 1'b0); // discarded, must not reach TXD
        end
        axi_tvalid <= 1'b0;
        axi_tlast  <= 1'b0;
    endtask

    // Source abort on the very last beat of the frame
    task automatic send_abort_last_frame;
        send_clean_prefix(6, 2);
        send_beat(2'b01, 1'b1, 1'b1); // aborted beat, ends the frame
        axi_tvalid <= 1'b0;
        axi_tlast  <= 1'b0;
    endtask

    // Frame dead on arrival: tuser already on the first beat. No
    // expectation is recorded, TXEN must never rise.
    task automatic send_dead_frame(input integer nbeats);
        for (int k = 0; k < nbeats; k++) begin
            send_beat(2'(k), k == nbeats-1, k == 0);
        end
        axi_tvalid <= 1'b0;
        axi_tlast  <= 1'b0;
        axi_tuser  <= 1'b0;
    endtask

    //----------------------------------------------------------------
    // Monitor indexes, consumed by the checkers below and compared to
    // the expected counts at the end of the test sequence
    //----------------------------------------------------------------
    integer wire_idx = 0;
    integer loop_idx = 0;

    //----------------------------------------------------------------
    // Test sequence
    //----------------------------------------------------------------
    initial begin
        axi_tvalid = 1'b0;
        axi_tlast  = 1'b0;
        axi_tdata  = 2'b00;
        axi_tuser  = 1'b0;

        wait (srst === 1'b0);
        @(posedge clock);

        // Three clean frames back to back: tvalid is held through the
        // IFG, so the gap on the wire is what the DUT enforces alone
        for (int i = 0; i < 16; i++) frame_bytes[i] = 8'(17*i + 8'h31);
        send_frame(16);
        for (int i = 0; i < 8; i++) frame_bytes[i] = 8'(8'hC3 - 9*i);
        send_frame(8);
        for (int i = 0; i < 8; i++) frame_bytes[i] = 8'(5*i + 8'h80);
        send_frame(8);
        idle_beats(2*IFG_CLOCKS);

        send_underflow_frame();
        idle_beats(2*IFG_CLOCKS);

        send_abort_frame();
        idle_beats(2*IFG_CLOCKS);

        send_abort_last_frame();
        idle_beats(2*IFG_CLOCKS);

        // Frames dead on their very first beat, single and multi beat:
        // drained without even a preamble on the wire
        send_dead_frame(1);
        idle_beats(2*IFG_CLOCKS);
        send_dead_frame(8);
        idle_beats(2*IFG_CLOCKS);

        // Recovery after the degraded frames
        for (int i = 0; i < 4; i++) frame_bytes[i] = 8'(8'h0F << i);
        send_frame(4);
        idle_beats(4*IFG_CLOCKS);

        if (wire_idx != exp_wire_count) begin
            errors = errors + 1;
            $error("TXD stream incomplete: %0d dibits seen, %0d expected",
                   wire_idx, exp_wire_count);
        end
        if (loop_idx != exp_loop_count) begin
            errors = errors + 1;
            $error("loopback stream incomplete: %0d beats seen, %0d expected",
                   loop_idx, exp_loop_count);
        end

        if (errors == 0)
          $display("rmii_mac_tx_tb: ALL TESTS PASSED");
        else
          $display("rmii_mac_tx_tb: %0d ERROR(S)", errors);
        $finish;
    end

    //----------------------------------------------------------------
    // Check the wire: every dibit under TXEN, in order
    //----------------------------------------------------------------
    always @(posedge clock) begin
        if (srst === 1'b0 && txen === 1'b1) begin
            if (wire_idx >= exp_wire_count) begin
                errors = errors + 1;
                $error("unexpected dibit %b on TXD at index %0d", txd, wire_idx);
            end
            else if (txd !== exp_wire[wire_idx]) begin
                errors = errors + 1;
                $error("TXD dibit %0d: got %b, expected %b",
                       wire_idx, txd, exp_wire[wire_idx]);
            end
            wire_idx = wire_idx + 1;
        end
    end

    //----------------------------------------------------------------
    // Check the inter-frame gap on every TXEN rising edge. This also
    // catches a TXEN glitch inside a frame, seen as a short gap.
    //----------------------------------------------------------------
    integer cycle_count = 0;
    integer txen_fall_cycle = -1000;
    logic   txen_prev = 1'b0;

    always @(posedge clock) begin
        cycle_count = cycle_count + 1;
        if (txen === 1'b1 && txen_prev === 1'b0) begin
            if (cycle_count - txen_fall_cycle < IFG_CLOCKS) begin
                errors = errors + 1;
                $error("inter-frame gap too short: %0d cycles instead of %0d",
                       cycle_count - txen_fall_cycle, IFG_CLOCKS);
            end
        end
        if (txen === 1'b0 && txen_prev === 1'b1) begin
            txen_fall_cycle = cycle_count;
        end
        txen_prev = txen;
    end

    //----------------------------------------------------------------
    // Check the loopback receiver: transmitted payload dibits only,
    // in order, tlast on the final dibit of each frame, never tuser
    //----------------------------------------------------------------
    always @(posedge clock) begin
        if (srst === 1'b0 && rx_axi_tvalid === 1'b1) begin
            if (loop_idx >= exp_loop_count) begin
                errors = errors + 1;
                $error("unexpected beat %b from the loopback receiver", rx_axi_tdata);
            end
            else begin
                if (rx_axi_tdata !== exp_loop[loop_idx][1:0]) begin
                    errors = errors + 1;
                    $error("loopback dibit %0d: got %b, expected %b",
                           loop_idx, rx_axi_tdata, exp_loop[loop_idx][1:0]);
                end
                if (rx_axi_tlast !== exp_loop[loop_idx][2]) begin
                    errors = errors + 1;
                    $error("loopback tlast %0d: got %b, expected %b",
                           loop_idx, rx_axi_tlast, exp_loop[loop_idx][2]);
                end
                if (rx_axi_tuser !== 1'b0) begin
                    errors = errors + 1;
                    $error("loopback tuser raised at beat %0d", loop_idx);
                end
            end
            loop_idx = loop_idx + 1;
        end
    end

endmodule
