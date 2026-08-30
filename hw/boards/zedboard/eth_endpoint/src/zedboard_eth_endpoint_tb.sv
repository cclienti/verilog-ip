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
// Title         : Zedboard Ethernet Endpoint Demonstrator Testbench
//-----------------------------------------------------------------------------
// File          : zedboard_eth_endpoint_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-29
// Last modified : 2026-08-29
//-----------------------------------------------------------------------------
// Description :
// Smoke test of the board wrapper: the endpoint chain is verified in
// depth by rmii_eth_endpoint_tb, so this bench checks what the wrapper
// adds. Reset must release on its own after power-on and re-arm from
// the button; an ARP request for the board's fixed IP must come back
// as a byte-exact reply, FCS included, before and after a button
// press; the activity and learn LEDs must light and the transmitter
// must stay silent until spoken to.

`timescale 1 ns / 100 ps

module zedboard_eth_endpoint_tb;

    localparam logic [47:0] LOCAL_MAC = 48'h02_12_34_56_78_9A;
    localparam logic [31:0] LOCAL_IP  = {8'd192, 8'd168, 8'd90, 8'd42};
    localparam logic [47:0] REQ_MAC   = 48'h02_AB_CD_EF_01_23;
    localparam logic [31:0] REQ_IP    = {8'd192, 8'd168, 8'd90, 8'd99};
    localparam logic [47:0] BCAST_MAC = 48'hFF_FF_FF_FF_FF_FF;

    integer errors = 0;

    //----------------------------------------------------------------
    // Clock: the PHY module's 50 MHz reference, running from time 0;
    // no reset is driven -- power-on comes from the init values
    //----------------------------------------------------------------
    logic clock;

    initial clock = 0;

    always
        #10 clock = !clock;

    //----------------------------------------------------------------
    // Device under test
    //----------------------------------------------------------------
    logic       btn;
    logic [1:0] rxd;
    logic       rxen;
    logic [1:0] txd;
    logic       txen;
    logic [3:0] led;

    zedboard_eth_endpoint zedboard_eth_endpoint_inst
    (
        .phy_refclk (clock),
        .btn_reset  (btn),
        .phy_rxd    (rxd),
        .phy_crs_dv (rxen),
        .phy_txd    (txd),
        .phy_txen   (txen),
        .led        (led)
    );

    //----------------------------------------------------------------
    // The ARP exchange, built byte-exact with a real FCS
    //----------------------------------------------------------------
    logic [7:0] fr [0:127];   // frame under construction
    integer     fr_len;       // bytes built so far
    logic [7:0] exp_b [0:127]; // the expected reply, FCS included
    integer     exp_len;      // expected reply length

    function automatic logic [31:0] crc_step(input logic [31:0] crc, input logic [7:0] b);
        logic [31:0] c;
        c = crc ^ 32'(b);
        for (int i = 0; i < 8; i++) begin
            c = c[0] ? {1'b0, c[31:1]} ^ 32'hEDB8_8320 : {1'b0, c[31:1]};
        end
        return c;
    endfunction

    task automatic append_fcs;
        logic [31:0] crc;
        crc = 32'hFFFF_FFFF;
        for (int i = 0; i < fr_len; i++) begin
            crc = crc_step(crc, fr[i]);
        end
        crc = ~crc;
        for (int i = 0; i < 4; i++) begin
            fr[fr_len] = crc[8*i +: 8];
            fr_len = fr_len + 1;
        end
    endtask

    task automatic build_arp_frame(input logic [47:0] dst, input logic [47:0] src,
                                   input logic [7:0] oper, input logic [47:0] sha,
                                   input logic [31:0] spa, input logic [47:0] tha,
                                   input logic [31:0] tpa);
        fr_len = 0;
        for (int i = 5; i >= 0; i--) begin fr[fr_len] = dst[8*i +: 8]; fr_len++; end
        for (int i = 5; i >= 0; i--) begin fr[fr_len] = src[8*i +: 8]; fr_len++; end
        fr[fr_len] = 8'h08; fr_len++; fr[fr_len] = 8'h06; fr_len++;
        fr[fr_len] = 8'h00; fr_len++; fr[fr_len] = 8'h01; fr_len++;
        fr[fr_len] = 8'h08; fr_len++; fr[fr_len] = 8'h00; fr_len++;
        fr[fr_len] = 8'h06; fr_len++; fr[fr_len] = 8'h04; fr_len++;
        fr[fr_len] = 8'h00; fr_len++; fr[fr_len] = oper;  fr_len++;
        for (int i = 5; i >= 0; i--) begin fr[fr_len] = sha[8*i +: 8]; fr_len++; end
        for (int i = 3; i >= 0; i--) begin fr[fr_len] = spa[8*i +: 8]; fr_len++; end
        for (int i = 5; i >= 0; i--) begin fr[fr_len] = tha[8*i +: 8]; fr_len++; end
        for (int i = 3; i >= 0; i--) begin fr[fr_len] = tpa[8*i +: 8]; fr_len++; end
        while (fr_len < 60) begin
            fr[fr_len] = 8'h00;
            fr_len = fr_len + 1;
        end
        append_fcs;
    endtask

    // Drive fr onto the wire: preamble, SFD, one dibit per clock
    task automatic send_wire;
        logic [7:0] b;
        @(negedge clock);
        rxen = 1'b1;
        for (int p = 0; p < 8; p++) begin
            b = (p == 7) ? 8'hD5 : 8'h55;
            for (int d = 0; d < 4; d++) begin
                rxd = b[2*d +: 2];
                @(negedge clock);
            end
        end
        for (int i = 0; i < fr_len; i++) begin
            for (int d = 0; d < 4; d++) begin
                rxd = fr[i][2*d +: 2];
                @(negedge clock);
            end
        end
        rxen = 1'b0;
        rxd  = 2'b00;
        repeat (48) @(negedge clock);
    endtask

    //----------------------------------------------------------------
    // Transmit monitor: capture one frame, compare byte-exact
    //----------------------------------------------------------------
    logic [1:0] mon_d [0:1023];  // captured dibits
    integer     mon_nd;          // dibits captured
    integer     mon_frames;      // frames checked
    logic       mon_active;      // txen seen high

    task automatic check_frame;
        integer     nb;
        logic [7:0] b;
        if (mon_nd < 32 || (mon_nd - 32) % 4 != 0) begin
            errors = errors + 1;
            $error("burst of %0d dibits is not a preamble plus whole bytes", mon_nd);
            return;
        end
        for (int i = 0; i < 32; i++) begin
            if (mon_d[i] !== (i == 31 ? 2'b11 : 2'b01)) begin
                errors = errors + 1;
                $error("preamble dibit %0d is %b", i, mon_d[i]);
                return;
            end
        end
        nb = (mon_nd - 32) / 4;
        if (nb != exp_len) begin
            errors = errors + 1;
            $error("reply is %0d bytes, expected %0d", nb, exp_len);
        end
        for (int i = 0; i < nb && i < exp_len; i++) begin
            b = {mon_d[32 + 4*i + 3], mon_d[32 + 4*i + 2],
                 mon_d[32 + 4*i + 1], mon_d[32 + 4*i + 0]};
            if (b !== exp_b[i]) begin
                errors = errors + 1;
                $error("reply byte %0d is %02x, expected %02x", i, b, exp_b[i]);
            end
        end
        mon_frames = mon_frames + 1;
    endtask

    always @(posedge clock) begin
        if (txen === 1'b1) begin
            mon_d[mon_nd] = txd;
            mon_nd = mon_nd + 1;
            mon_active = 1'b1;
        end
        else if (mon_active) begin
            check_frame;
            mon_nd     = 0;
            mon_active = 1'b0;
        end
    end

    task automatic wait_reply(input integer target);
        integer waited;
        waited = 0;
        while (mon_frames < target && waited < 10000) begin
            @(posedge clock);
            waited = waited + 1;
        end
        if (mon_frames < target) begin
            errors = errors + 1;
            $error("reply %0d never came", target);
        end
    endtask

    //----------------------------------------------------------------
    // Test sequence
    //----------------------------------------------------------------
    initial begin
        btn  = 1'b0;
        rxd  = 2'b00;
        rxen = 1'b0;
        mon_nd = 0; mon_frames = 0; mon_active = 1'b0;

        // The expected reply, identical for both exchanges
        build_arp_frame(REQ_MAC, LOCAL_MAC, 8'h02,
                        LOCAL_MAC, LOCAL_IP, REQ_MAC, REQ_IP);
        for (int i = 0; i < fr_len; i++) begin
            exp_b[i] = fr[i];
        end
        exp_len = fr_len;

        // Power-on: the init-value reset must release on its own and
        // the transmitter must stay silent meanwhile
        repeat (100) @(posedge clock);
        if (zedboard_eth_endpoint_inst.sreset !== 1'b0) begin
            errors = errors + 1;
            $error("reset did not release from its init values");
        end
        if (mon_frames != 0 || txen !== 1'b0) begin
            errors = errors + 1;
            $error("transmit activity before any request");
        end

        // First exchange
        build_arp_frame(BCAST_MAC, REQ_MAC, 8'h01,
                        REQ_MAC, REQ_IP, 48'h00_00_00_00_00_00, LOCAL_IP);
        send_wire;
        wait_reply(1);
        if (led[3] !== 1'b1) begin
            errors = errors + 1;
            $error("learn LED not lit after a valid ARP request");
        end
        if (led[1] !== 1'b1 || led[2] !== 1'b1) begin
            errors = errors + 1;
            $error("activity LEDs rx=%b tx=%b after the exchange", led[1], led[2]);
        end

        // Button press: reset must re-arm, then the board must answer
        // again once released
        @(negedge clock);
        btn = 1'b1;
        repeat (5) @(posedge clock);
        if (zedboard_eth_endpoint_inst.sreset !== 1'b1) begin
            errors = errors + 1;
            $error("reset did not re-arm from the button");
        end
        @(negedge clock);
        btn = 1'b0;
        repeat (20) @(posedge clock);
        if (zedboard_eth_endpoint_inst.sreset !== 1'b0) begin
            errors = errors + 1;
            $error("reset did not release after the button");
        end

        build_arp_frame(BCAST_MAC, REQ_MAC, 8'h01,
                        REQ_MAC, REQ_IP, 48'h00_00_00_00_00_00, LOCAL_IP);
        send_wire;
        wait_reply(2);

        if (errors == 0)
          $display("zedboard_eth_endpoint_tb: ALL TESTS PASSED");
        else
          $display("zedboard_eth_endpoint_tb: %0d ERROR(S)", errors);
        $finish;
    end

    // Watchdog: a lost reply stalls a bounded wait, not the bench
    initial begin
        #400000;
        errors = errors + 1;
        $error("watchdog: %0d replies seen", mon_frames);
        $display("zedboard_eth_endpoint_tb: %0d ERROR(S)", errors);
        $finish;
    end

endmodule
