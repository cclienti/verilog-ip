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
// Title         : Zedboard Ethernet Endpoint Demonstrator
//-----------------------------------------------------------------------------
// File          : zedboard_eth_endpoint.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-29
// Last modified : 2026-08-29
//-----------------------------------------------------------------------------
// Description: Board demonstrator of rmii_eth_endpoint on a Zedboard
// with a LAN8720 RMII PHY module jumper-wired to Pmod JA -- the
// on-board Marvell PHY hangs off the PS GEM and is not reachable from
// the PL. Everything runs on the PHY module's 50 MHz reference clock,
// entering on the clock-capable JA10 pin. Identity is fixed here:
// ping 192.168.90.42 answers once the link is up.
//
// This wrapper only adds what a board needs: a power-on/button reset
// stretcher, the identity constants, activity LEDs -- heartbeat,
// receive, transmit, and the ARP learn pulse stretched visible -- and
// ODDR retiming of the transmit pins to the falling edge: the PHY
// samples TXD/TX_EN on the rising edge with a 4 ns / 2 ns window, and
// a fabric register released them 0.9 ns after that edge, inside the
// hold window; changing them at the falling edge leaves 10 ns on each
// side. BTNC re-arms the reset; the FPGA register init values cover
// power-on.

`timescale 1 ns / 100 ps

module zedboard_eth_endpoint (
    input logic        phy_refclk,  // 50 MHz RMII reference from the PHY module
    input logic        btn_reset,   // BTNC, active-high manual reset

    // RMII PHY pins on Pmod JA
    input logic [1:0]  phy_rxd,
    input logic        phy_crs_dv,
    output logic [1:0] phy_txd,
    output logic       phy_txen,

    // LD0..LD3: heartbeat, receive, transmit, ARP learned
    output logic [3:0] led
);

    localparam logic [47:0] LOCAL_MAC = 48'h02_12_34_56_78_9A;      // locally administered
    localparam logic [31:0] LOCAL_IP  = {8'd192, 8'd168, 8'd90, 8'd42};

    localparam int STRETCH_W = 22;  // activity stretch, ~84 ms at 50 MHz
    localparam int BEAT_W    = 26;  // heartbeat divider, ~0.75 Hz blink

    //-------------------------------------------
    // Reset: init values cover power-on, the
    // button refills the stretcher through its
    // own synchronizing shift register
    //-------------------------------------------
    logic [7:0] rst_shift = '1;   // button synchronizer and stretcher
    logic       sreset    = 1'b1; // synchronous reset, active high

    always_ff @(posedge phy_refclk) begin
        rst_shift <= {rst_shift[6:0], btn_reset};
        sreset    <= |rst_shift;
    end

    //-------------------------------------------
    // The endpoint
    //-------------------------------------------
    logic        learn_valid;  // valid ARP mapping seen
    logic [47:0] learn_mac;    // learned MAC, unused here
    logic [31:0] learn_ip;     // learned IP, unused here
    logic [1:0]  ep_txd;       // transmit dibit, fabric domain
    logic        ep_txen;      // transmit enable, fabric domain

    rmii_eth_endpoint
    #(
        .LOG2_FIFO_DEPTH (11),
        .LOG2_ICMP_DEPTH (11)
    )
    rmii_eth_endpoint_inst
    (
        .clock       (phy_refclk),
        .sreset      (sreset),
        .local_mac   (LOCAL_MAC),
        .local_ip    (LOCAL_IP),
        .phy_rxd     (phy_rxd),
        .phy_crs_dv  (phy_crs_dv),
        .phy_txd     (ep_txd),
        .phy_txen    (ep_txen),
        .learn_valid (learn_valid),
        .learn_mac   (learn_mac),
        .learn_ip    (learn_ip)
    );

    //-------------------------------------------
    // Transmit pins retimed to the falling edge
    //-------------------------------------------
    logic [1:0] ep_txd_q;   // previous cycle's dibit, the pin's high half
    logic       ep_txen_q;  // previous cycle's enable, the pin's high half

    always_ff @(posedge phy_refclk) begin
        ep_txd_q  <= ep_txd;
        ep_txen_q <= ep_txen;
    end

    // d1 keeps the previous value through the high half-period, d2
    // brings the new one at the falling edge: the pins are stable
    // 10 ns on either side of the PHY's rising-edge sample
    oddr_out oddr_txd0_inst
    (
        .clock (phy_refclk),
        .d1    (ep_txd_q[0]),
        .d2    (ep_txd[0]),
        .q     (phy_txd[0])
    );

    oddr_out oddr_txd1_inst
    (
        .clock (phy_refclk),
        .d1    (ep_txd_q[1]),
        .d2    (ep_txd[1]),
        .q     (phy_txd[1])
    );

    oddr_out oddr_txen_inst
    (
        .clock (phy_refclk),
        .d1    (ep_txen_q),
        .d2    (ep_txen),
        .q     (phy_txen)
    );

    //-------------------------------------------
    // LEDs: one heartbeat divider, one stretch
    // counter per one-shot activity source
    //-------------------------------------------
    logic [BEAT_W-1:0]    beat_cnt;       // free-running heartbeat divider
    logic [STRETCH_W-1:0] rx_stretch;     // receive activity hold
    logic [STRETCH_W-1:0] tx_stretch;     // transmit activity hold
    logic [STRETCH_W-1:0] learn_stretch;  // ARP learn hold

    always_ff @(posedge phy_refclk) begin
        if (sreset) begin
            beat_cnt      <= '0;
            rx_stretch    <= '0;
            tx_stretch    <= '0;
            learn_stretch <= '0;
        end
        else begin
            beat_cnt <= beat_cnt + 1'b1;

            if (phy_crs_dv) begin
                rx_stretch <= '1;
            end
            else if (rx_stretch != '0) begin
                rx_stretch <= rx_stretch - 1'b1;
            end

            if (ep_txen) begin
                tx_stretch <= '1;
            end
            else if (tx_stretch != '0) begin
                tx_stretch <= tx_stretch - 1'b1;
            end

            if (learn_valid) begin
                learn_stretch <= '1;
            end
            else if (learn_stretch != '0) begin
                learn_stretch <= learn_stretch - 1'b1;
            end
        end
    end

    assign led[0] = beat_cnt[BEAT_W-1];
    assign led[1] = rx_stretch != '0;
    assign led[2] = tx_stretch != '0;
    assign led[3] = learn_stretch != '0;

endmodule
