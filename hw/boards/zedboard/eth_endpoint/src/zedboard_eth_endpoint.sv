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
// Last modified : 2026-09-03
//-----------------------------------------------------------------------------
// Description: Board demonstrator of rmii_eth_endpoint on a Zedboard
// with an ethernet-pmod v2 (LAN8720A) plugged into Pmod JA -- the
// on-board Marvell PHY hangs off the PS GEM and is not reachable from
// the PL. That module carries no crystal and straps nINTSEL high, so
// it runs in REF_CLK In mode: the FPGA owns the 50 MHz reference,
// halves it from the board's 100 MHz oscillator and forwards it to
// the module's CLKIN pin. Identity is fixed here: ping 192.168.90.42
// answers once the link is up.
//
// Clock geometry, the one thing this wrapper exists for. The forwarded
// clock leaves through an ODDR tied high/low, so it is a copy of the
// fabric clock delayed only by the output path -- the clock insertion
// delay is common to it and to every pin register and cancels. The PHY
// therefore samples the transmit pins essentially when the fabric
// clock edge that launched them occurred, which is exactly where its
// 4 ns setup / 2 ns hold window may not be. The transmit pins are
// registered on the falling edge, half a period away from that sample;
// the receive pins stay on the rising edge, a full period after the
// edge that made the PHY launch them, which is where their eye is.
// Both pin register sets are pushed into the IOBs so the analysis does
// not pay for fabric routing.
//
// Note that this is the mirror image of the earlier wiring, where the
// PHY sourced the clock: there the fabric clock lagged the wire by the
// insertion delay, a plain rising-edge launch had margin on both sides
// (551adaf) and a falling-edge retime overshot into the next sample.
//
// The rest is what a board needs: the PHY reset pulse, a power-on and
// button reset, the identity constants, and activity LEDs -- heartbeat,
// receive, transmit, and the ARP learn pulse stretched visible. BTNC
// re-arms the whole sequence, PHY reset included.

`timescale 1 ns / 100 ps

module zedboard_eth_endpoint (
    input logic        clk100,      // 100 MHz PL oscillator, Y9
    input logic        btn_reset,   // BTNC, active-high manual reset

    // ethernet-pmod v2 on Pmod JA
    output logic       phy_clkin,   // 50 MHz RMII reference to the PHY
    output logic       phy_rstn,    // PHY reset, active low
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

    // Reset timer: the LAN8720A wants nRST low for at least 100 us,
    // with its reference clock already running. The counter saturates,
    // so the two release points are plain equalities on the way up.
    localparam int RST_W          = 15;         // timer width, saturates at ~655 us
    localparam int PHY_RST_CYCLES = 1 << 14;    // 16384 cycles, 328 us of nRST low
    localparam int MAC_RST_CYCLES = PHY_RST_CYCLES + (1 << 13);  // + 164 us to settle

    //-------------------------------------------
    // 50 MHz RMII reference: the board's 100 MHz
    // oscillator halved onto a global buffer.
    // The reference is this design's only clock,
    // so the divider is the whole clocking story
    // -- ppm accuracy is the oscillator's either
    // way, which an MMCM could not improve.
    //-------------------------------------------
    logic clk_div = 1'b0;  // 100 MHz halved, before the global buffer
    logic refclk;          // 50 MHz RMII reference, the design's only clock

    always_ff @(posedge clk100) begin
        clk_div <= !clk_div;
    end

    // refclk_bufg and phy_clkin_oddr are named in the xdc, which hangs
    // the generated clocks on refclk_bufg/O and phy_clkin_oddr/C --
    // rename here and the constraints go silently missing
`ifdef SYNTHESIS
    BUFG refclk_bufg
    (
        .I (clk_div),
        .O (refclk)
    );

    // Clock forwarding: D1 high, D2 low reproduces refclk on the pin
    // through the output path, matching what the pin registers see
    ODDR
    #(
        .DDR_CLK_EDGE ("SAME_EDGE"),
        .INIT         (1'b0),
        .SRTYPE       ("SYNC")
    )
    phy_clkin_oddr
    (
        .Q  (phy_clkin),
        .C  (refclk),
        .CE (1'b1),
        .D1 (1'b1),
        .D2 (1'b0),
        .R  (1'b0),
        .S  (1'b0)
    );
`else
    assign refclk    = clk_div;
    assign phy_clkin = refclk;
`endif

    //-------------------------------------------
    // Reset sequence: the counter's init value
    // covers power-on and the button refills it
    // through its own synchronizing shift
    // register. nRST releases first, the MAC once
    // the PHY has had time to come out
    //-------------------------------------------
    logic [7:0]       btn_shift = '1;    // button synchronizer and stretcher
    logic [RST_W-1:0] rst_cnt   = '0;    // reset timer, saturating at its max
    logic             phy_rstn_q = 1'b0; // PHY reset, released first
    logic             sreset     = 1'b1; // MAC synchronous reset, active high

    always_ff @(posedge refclk) begin
        btn_shift <= {btn_shift[6:0], btn_reset};

        if (|btn_shift) begin
            rst_cnt    <= '0;
            phy_rstn_q <= 1'b0;
            sreset     <= 1'b1;
        end
        else begin
            if (rst_cnt != '1) begin
                rst_cnt <= rst_cnt + 1'b1;
            end
            if (rst_cnt == RST_W'(PHY_RST_CYCLES)) begin
                phy_rstn_q <= 1'b1;
            end
            if (rst_cnt == RST_W'(MAC_RST_CYCLES)) begin
                sreset <= 1'b0;
            end
        end
    end

    assign phy_rstn = phy_rstn_q;

    //-------------------------------------------
    // Pin registers, in the IOBs. Receive on the
    // rising edge, transmit on the falling one --
    // see the header: the PHY's sampling edge sits
    // on the fabric edge, so the transmit pins
    // must not move there
    //-------------------------------------------
    (* IOB = "TRUE" *) logic [1:0] rxd_q    = '0;    // registered receive dibit
    (* IOB = "TRUE" *) logic       crs_dv_q = 1'b0;  // registered carrier sense
    (* IOB = "TRUE" *) logic [1:0] txd_q    = '0;    // transmit dibit, fall launched
    (* IOB = "TRUE" *) logic       txen_q   = 1'b0;  // transmit enable, fall launched

    logic [1:0] ep_txd;   // endpoint transmit dibit, rising-edge domain
    logic       ep_txen;  // endpoint transmit enable, rising-edge domain

    always_ff @(posedge refclk) begin
        rxd_q    <= phy_rxd;
        crs_dv_q <= phy_crs_dv;
    end

    always_ff @(negedge refclk) begin
        txd_q  <= ep_txd;
        txen_q <= ep_txen;
    end

    assign phy_txd  = txd_q;
    assign phy_txen = txen_q;

    //-------------------------------------------
    // The endpoint
    //-------------------------------------------
    logic        learn_valid;  // valid ARP mapping seen
    logic [47:0] learn_mac;    // learned MAC, unused here
    logic [31:0] learn_ip;     // learned IP, unused here

    rmii_eth_endpoint
    #(
        .LOG2_FIFO_DEPTH (11),
        .LOG2_ICMP_DEPTH (11)
    )
    rmii_eth_endpoint_inst
    (
        .clock       (refclk),
        .sreset      (sreset),
        .local_mac   (LOCAL_MAC),
        .local_ip    (LOCAL_IP),
        .phy_rxd     (rxd_q),
        .phy_crs_dv  (crs_dv_q),
        .phy_txd     (ep_txd),
        .phy_txen    (ep_txen),
        .learn_valid (learn_valid),
        .learn_mac   (learn_mac),
        .learn_ip    (learn_ip)
    );

    //-------------------------------------------
    // LEDs: one heartbeat divider, one stretch
    // counter per one-shot activity source
    //-------------------------------------------
    logic [BEAT_W-1:0]    beat_cnt;       // free-running heartbeat divider
    logic [STRETCH_W-1:0] rx_stretch;     // receive activity hold
    logic [STRETCH_W-1:0] tx_stretch;     // transmit activity hold
    logic [STRETCH_W-1:0] learn_stretch;  // ARP learn hold

    always_ff @(posedge refclk) begin
        if (sreset) begin
            beat_cnt      <= '0;
            rx_stretch    <= '0;
            tx_stretch    <= '0;
            learn_stretch <= '0;
        end
        else begin
            beat_cnt <= beat_cnt + 1'b1;

            if (crs_dv_q) begin
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
