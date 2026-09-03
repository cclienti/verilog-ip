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
// Last modified : 2026-09-03
//-----------------------------------------------------------------------------
// Description :
// Smoke test of the board wrapper: the endpoint chain is verified in
// depth by rmii_eth_endpoint_tb, so this bench checks what the wrapper
// adds. The only clock driven here is the board's 100 MHz oscillator
// -- everything on the PHY side of the bench is timed by phy_clkin,
// the reference the wrapper generates and forwards, which is what the
// module would use. So the bench also stands in for the PHY's timing:
// it launches receive dibits a clock-to-out after the forwarded rising
// edge, samples the transmit pins on that same edge, and fails if they
// move inside the LAN8720A's 4 ns setup / 2 ns hold window -- which is
// what a transmit launch put back on the rising edge would do.
//
// Checked besides: the forwarded clock is a 50 MHz square wave, nRST
// is asserted from power-on for at least the 100 us the datasheet asks
// and releases before the MAC's reset, no frame is transmitted before
// then, an ARP request for the board's fixed IP comes back byte-exact
// with its FCS, the activity and learn LEDs light, and a button press
// re-arms the whole sequence, PHY reset included.

`timescale 1 ns / 100 ps

module zedboard_eth_endpoint_tb;

    localparam logic [47:0] LOCAL_MAC = 48'h02_12_34_56_78_9A;
    localparam logic [31:0] LOCAL_IP  = {8'd192, 8'd168, 8'd90, 8'd42};
    localparam logic [47:0] REQ_MAC   = 48'h02_AB_CD_EF_01_23;
    localparam logic [31:0] REQ_IP    = {8'd192, 8'd168, 8'd90, 8'd99};
    localparam logic [47:0] BCAST_MAC = 48'hFF_FF_FF_FF_FF_FF;

    // The PHY's side of the RMII contract, from the LAN8720A datasheet
    localparam realtime PHY_TCO     = 6.0;      // CLKIN edge to rxd/crs_dv valid
    localparam realtime PHY_TSU     = 4.0;      // txd/txen setup before the edge
    localparam realtime PHY_THD     = 2.0;      // txd/txen hold after the edge
    localparam realtime PHY_RST_MIN = 100000.0; // nRST low, 100 us
    localparam realtime REFCLK_HALF = 10.0;     // half a 50 MHz period

    integer errors = 0;

    //----------------------------------------------------------------
    // The only driven clock: the board's 100 MHz oscillator, running
    // from time 0. No reset is driven -- power-on comes from the
    // wrapper's init values
    //----------------------------------------------------------------
    logic clk100;

    initial clk100 = 0;

    always
        #5 clk100 = !clk100;

    //----------------------------------------------------------------
    // Device under test
    //----------------------------------------------------------------
    logic       btn;
    logic       clkin;   // 50 MHz reference the wrapper forwards
    logic       rstn;    // PHY reset, active low
    logic [1:0] rxd;
    logic       rxen;
    logic [1:0] txd;
    logic       txen;
    logic [3:0] led;

    zedboard_eth_endpoint zedboard_eth_endpoint_inst
    (
        .clk100     (clk100),
        .btn_reset  (btn),
        .phy_clkin  (clkin),
        .phy_rstn   (rstn),
        .phy_rxd    (rxd),
        .phy_crs_dv (rxen),
        .phy_txd    (txd),
        .phy_txen   (txen),
        .led        (led)
    );

    //----------------------------------------------------------------
    // Forwarded clock: a 50 MHz square wave, both half-periods
    //----------------------------------------------------------------
    realtime clkin_rise;  // last rising edge of the forwarded clock
    realtime clkin_fall;  // last falling edge of the forwarded clock

    initial begin
        clkin_rise = 0.0;
        clkin_fall = 0.0;
    end

    always @(posedge clkin) begin
        if (clkin_fall != 0.0 && $realtime - clkin_fall != REFCLK_HALF) begin
            errors = errors + 1;
            $error("forwarded clock low for %0.1f ns, expected %0.1f ns",
                   $realtime - clkin_fall, REFCLK_HALF);
        end
        clkin_rise = $realtime;
    end

    always @(negedge clkin) begin
        if (clkin_rise != 0.0 && $realtime - clkin_rise != REFCLK_HALF) begin
            errors = errors + 1;
            $error("forwarded clock high for %0.1f ns, expected %0.1f ns",
                   $realtime - clkin_rise, REFCLK_HALF);
        end
        clkin_fall = $realtime;
    end

    //----------------------------------------------------------------
    // The PHY samples txd/txen on the forwarded rising edge: nothing
    // may move in [-PHY_TSU, +PHY_THD] around it
    //----------------------------------------------------------------
    realtime tx_change;  // last transition of the transmit pins

    initial tx_change = 0.0;

    always @(txd or txen) begin
        if (clkin_rise != 0.0 && $realtime - clkin_rise < PHY_THD) begin
            errors = errors + 1;
            $error("transmit pins moved %0.1f ns after the sampling edge, hold is %0.1f ns",
                   $realtime - clkin_rise, PHY_THD);
        end
        tx_change = $realtime;
    end

    always @(posedge clkin) begin
        if (tx_change != 0.0 && $realtime - tx_change < PHY_TSU) begin
            errors = errors + 1;
            $error("transmit pins moved %0.1f ns before the sampling edge, setup is %0.1f ns",
                   $realtime - tx_change, PHY_TSU);
        end
    end

    //----------------------------------------------------------------
    // PHY reset: low from power-on for at least PHY_RST_MIN, released
    // before the MAC leaves reset
    //----------------------------------------------------------------
    realtime rstn_fall;    // start of the current nRST pulse, 0 at power-on
    integer  rstn_pulses;  // completed nRST low pulses

    initial begin
        rstn_fall   = 0.0;
        rstn_pulses = 0;
    end

    always @(negedge rstn) begin
        rstn_fall = $realtime;
    end

    always @(posedge rstn) begin
        if ($realtime - rstn_fall < PHY_RST_MIN) begin
            errors = errors + 1;
            $error("nRST held low %0.1f ns, the datasheet asks %0.1f ns",
                   $realtime - rstn_fall, PHY_RST_MIN);
        end
        if (zedboard_eth_endpoint_inst.sreset !== 1'b1) begin
            errors = errors + 1;
            $error("the MAC left reset before nRST was released");
        end
        rstn_pulses = rstn_pulses + 1;
    end

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

    // One dibit onto the wire, launched like the PHY does it: a
    // clock-to-out after the rising edge of the clock it was given
    task automatic drive_dibit(input logic crs, input logic [1:0] d);
        @(posedge clkin);
        #PHY_TCO;
        rxen = crs;
        rxd  = d;
    endtask

    // Drive fr onto the wire: preamble, SFD, one dibit per clock
    task automatic send_wire;
        logic [7:0] b;
        for (int p = 0; p < 8; p++) begin
            b = (p == 7) ? 8'hD5 : 8'h55;
            for (int d = 0; d < 4; d++) begin
                drive_dibit(1'b1, b[2*d +: 2]);
            end
        end
        for (int i = 0; i < fr_len; i++) begin
            for (int d = 0; d < 4; d++) begin
                drive_dibit(1'b1, fr[i][2*d +: 2]);
            end
        end
        drive_dibit(1'b0, 2'b00);
        repeat (48) @(posedge clkin);
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

    always @(posedge clkin) begin
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
            @(posedge clkin);
            waited = waited + 1;
        end
        if (mon_frames < target) begin
            errors = errors + 1;
            $error("reply %0d never came", target);
        end
    endtask

    // The reset sequence runs on a counter the wrapper sizes for the
    // datasheet, not for the bench: wait it out rather than count it
    task automatic wait_reset_release(input integer pulses);
        integer waited;
        waited = 0;
        while ((rstn_pulses < pulses || zedboard_eth_endpoint_inst.sreset !== 1'b0)
               && waited < 200000) begin
            @(posedge clkin);
            waited = waited + 1;
        end
        if (rstn_pulses < pulses) begin
            errors = errors + 1;
            $error("nRST release %0d never came", pulses);
        end
        if (zedboard_eth_endpoint_inst.sreset !== 1'b0) begin
            errors = errors + 1;
            $error("the MAC never left reset");
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

        // Power-on: the PHY must be held in reset out of the init
        // values, not released by an X or a stale counter
        @(posedge clkin);
        if (rstn !== 1'b0) begin
            errors = errors + 1;
            $error("nRST is %b at power-on, expected 0", rstn);
        end
        if (zedboard_eth_endpoint_inst.sreset !== 1'b1) begin
            errors = errors + 1;
            $error("the MAC is not in reset at power-on");
        end

        // The reset sequence must complete on its own, transmitter
        // silent throughout
        wait_reset_release(1);
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

        // Button press: the whole sequence must re-arm, PHY reset
        // included, then run again once the button is released
        @(negedge clkin);
        btn = 1'b1;
        repeat (10) @(posedge clkin);
        if (zedboard_eth_endpoint_inst.sreset !== 1'b1) begin
            errors = errors + 1;
            $error("reset did not re-arm from the button");
        end
        if (rstn !== 1'b0) begin
            errors = errors + 1;
            $error("nRST did not re-arm from the button");
        end
        @(negedge clkin);
        btn = 1'b0;

        wait_reset_release(2);

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

    // Watchdog: two full reset sequences plus two exchanges fit in
    // well under a millisecond and a half
    initial begin
        #1500000;
        errors = errors + 1;
        $error("watchdog: %0d nRST pulses, %0d replies seen", rstn_pulses, mon_frames);
        $display("zedboard_eth_endpoint_tb: %0d ERROR(S)", errors);
        $finish;
    end

endmodule
