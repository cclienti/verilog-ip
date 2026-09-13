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
// Title         : RMII Ethernet TCP Endpoint
//-----------------------------------------------------------------------------
// File          : rmii_eth_tcp_endpoint_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-09-13
// Last modified : 2026-09-13
//-----------------------------------------------------------------------------
// Description: Wire-level test of the TCP endpoint. Frames are built by
// tcp_model_pkg, given a real preamble/SFD and FCS, and driven onto the
// RMII receive pins dibit by dibit; the transmit pins are captured,
// the preamble and FCS stripped, and the frame parsed back by the
// model. It proves the TCP integration through the whole chain: the
// handshake, a data segment echoed byte-exact, and the close, with
// TCP routed to the socket on the second IPv4 demux output and its
// replies merged by the three-input transmit mux.
//
// Reports rmii_eth_tcp_endpoint_tb: ALL TESTS PASSED or N ERROR(S).

`timescale 1 ns / 100 ps

module rmii_eth_tcp_endpoint_tb;
    import tcp_model_pkg::*;

    localparam logic [47:0] LOCAL_MAC = 48'h02_00_00_00_00_2a;
    localparam logic [31:0] LOCAL_IP  = 32'hc0a85a2a;
    localparam logic [15:0] LISTEN    = 16'd23;
    localparam logic [47:0] CLI_MAC   = 48'h3c_97_0e_12_34_56;
    localparam logic [31:0] CLI_IP    = 32'hc0a85a01;
    localparam logic [15:0] CLI_PORT  = 16'd51234;

    logic       clock, sreset;
    logic [1:0] rxd;
    logic       rxen;
    logic [1:0] txd;
    logic       txen;
    logic       learn_valid;
    logic [47:0] learn_mac;
    logic [31:0] learn_ip;
    logic        tcp_connected;
    logic [31:0] tcp_peer_ip;
    logic [15:0] tcp_peer_port;

    // Application streams, looped for the echo
    logic [7:0]  mapp_tdata, sapp_tdata;
    logic        mapp_tuser, mapp_tvalid, mapp_tlast, mapp_tready;
    logic        sapp_tuser, sapp_tvalid, sapp_tlast, sapp_tready;

    integer errors = 0;
    integer checks = 0;

    //----------------------------------------------------------------
    // DUT: small TCP timers so nothing waits long in simulation
    //----------------------------------------------------------------
    rmii_eth_tcp_endpoint #(
        .TCP_RTO_CLOCKS (400), .TCP_MAX_RETRIES (4), .TCP_IDLE_CLOCKS (64'd0)
    ) dut (
        .clock (clock), .sreset (sreset),
        .local_mac (LOCAL_MAC), .local_ip (LOCAL_IP), .listen_port (LISTEN),
        .tcp_connected (tcp_connected), .tcp_peer_ip (tcp_peer_ip), .tcp_peer_port (tcp_peer_port),
        .m_app_tdata (mapp_tdata), .m_app_tuser (mapp_tuser), .m_app_tvalid (mapp_tvalid),
        .m_app_tlast (mapp_tlast), .m_app_tready (mapp_tready),
        .s_app_tdata (sapp_tdata), .s_app_tuser (sapp_tuser), .s_app_tvalid (sapp_tvalid),
        .s_app_tlast (sapp_tlast), .s_app_tready (sapp_tready),
        .phy_rxd (rxd), .phy_crs_dv (rxen), .phy_txd (txd), .phy_txen (txen),
        .learn_valid (learn_valid), .learn_mac (learn_mac), .learn_ip (learn_ip)
    );

    // Echo loopback: m_app straight back to s_app
    assign sapp_tdata  = mapp_tdata;
    assign sapp_tuser  = mapp_tuser;
    assign sapp_tvalid = mapp_tvalid;
    assign sapp_tlast  = mapp_tlast;
    assign mapp_tready = sapp_tready;

    initial clock = 0;
    always #10 clock = !clock;

    task automatic check(input bit ok, input string what);
        checks = checks + 1;
        if (!ok) begin errors = errors + 1; $error("%s", what); end
    endtask

    // Reflected CRC-32, the Ethernet FCS
    function automatic logic [31:0] crc_step(input logic [31:0] crc, input logic [7:0] b);
        logic [31:0] c = crc ^ 32'(b);
        for (int i = 0; i < 8; i++) c = c[0] ? {1'b0, c[31:1]} ^ 32'hEDB8_8320 : {1'b0, c[31:1]};
        return c;
    endfunction

    //----------------------------------------------------------------
    // Drive a frame (no FCS) onto the receive pins: preamble, SFD,
    // frame bytes, a computed FCS, and the inter-frame gap
    //----------------------------------------------------------------
    task automatic send_wire(input bytes_t f);
        logic [7:0]  b;
        logic [31:0] crc;
        int          n = f.size();
        // Pad to the 60-byte minimum before the FCS, like a real NIC
        if (n < 60) n = 60;
        crc = 32'hFFFF_FFFF;
        for (int i = 0; i < n; i++) crc = crc_step(crc, (i < f.size()) ? f[i] : 8'h00);
        crc = ~crc;

        @(negedge clock);
        rxen = 1'b1;
        for (int p = 0; p < 8; p++) begin
            b = (p == 7) ? 8'hD5 : 8'h55;
            for (int d = 0; d < 4; d++) begin rxd = b[2*d +: 2]; @(negedge clock); end
        end
        for (int i = 0; i < n; i++) begin
            b = (i < f.size()) ? f[i] : 8'h00;
            for (int d = 0; d < 4; d++) begin rxd = b[2*d +: 2]; @(negedge clock); end
        end
        for (int i = 0; i < 4; i++) begin
            b = crc[8*i +: 8];
            for (int d = 0; d < 4; d++) begin rxd = b[2*d +: 2]; @(negedge clock); end
        end
        rxen = 1'b0; rxd = 2'b00;
        repeat (48) @(negedge clock);
    endtask

    //----------------------------------------------------------------
    // Transmit capture: collect dibits while txen is high, then on the
    // gap reassemble one frame (strip 32 preamble dibits and the 4 FCS
    // bytes) into the captured-frame store
    //----------------------------------------------------------------
    logic [1:0] cd [0:8191];
    integer     cnd;
    logic [7:0] cframes [0:15][0:511];
    integer     cflen [0:15];
    integer     cfcount;
    integer     cgap;
    integer     c_nb;
    logic [7:0] c_bb;

    always @(posedge clock) begin
        if (sreset) begin cnd = 0; cgap = 100; end
        else begin
            if (txen) begin cd[cnd] = txd; cnd = cnd + 1; cgap = 0; end
            else begin
                cgap = cgap + 1;
                if (cgap == 4 && cnd > 32 + 16) begin
                    // Reassemble: dibits 0..31 are preamble/SFD
                    c_nb = (cnd - 32) / 4;
                    for (int i = 0; i < c_nb; i++) begin
                        c_bb = 8'h0;
                        for (int d = 0; d < 4; d++) c_bb[2*d +: 2] = cd[32 + 4*i + d];
                        cframes[cfcount][i] = c_bb;
                    end
                    cflen[cfcount] = c_nb - 4;   // drop the FCS
                    cfcount = cfcount + 1;
                    cnd = 0;
                end
                else if (cgap == 4 && cnd > 0) begin
                    cnd = 0;   // runt, discard
                end
            end
        end
    end

    task automatic wait_tx(input integer n, input string what);
        integer g = 0;
        while (cfcount < n && g < 6000) begin @(posedge clock); g = g + 1; end
        if (cfcount < n) begin errors = errors + 1; $error("%s: no frame (have %0d want %0d)", what, cfcount, n); end
    endtask

    function automatic bytes_t cap_frame(input integer idx);
        bytes_t b;
        if (idx < 0 || idx >= cfcount || cflen[idx] <= 0) return bytes_new(0);
        b = new[cflen[idx]];
        for (int i = 0; i < cflen[idx]; i++) b[i] = cframes[idx][i];
        return b;
    endfunction

    function automatic tcp_hdr_t cli_hdr(input logic [7:0] fl, input logic [31:0] sq,
                                         input logic [31:0] ak, input logic [15:0] m);
        tcp_hdr_t h = '0;
        h.dst_mac = LOCAL_MAC; h.src_mac = CLI_MAC;
        h.ip_id = 16'h4e21; h.df = 1'b1; h.ttl = 8'd64;
        h.src_ip = CLI_IP; h.dst_ip = LOCAL_IP;
        h.src_port = CLI_PORT; h.dst_port = LISTEN;
        h.seq = sq; h.ack = ak; h.flags = fl; h.window = 16'd64240;
        h.urgent = 16'h0; h.mss = m;
        return h;
    endfunction

    tcp_hdr_t h, pf;
    bytes_t   fb;
    string    err;
    bit       ok;
    logic [31:0] cli_isn, our_isn;

    initial begin
        sreset = 1'b1; rxd = 2'b00; rxen = 1'b0;
        cnd = 0; cfcount = 0; cgap = 100;
        repeat (8) @(negedge clock);
        sreset = 1'b0;
        repeat (4) @(negedge clock);

        cli_isn = 32'h1A2B3C4D;

        //--- 1. SYN -> SYN-ACK through the whole chain ---
        h = cli_hdr(F_SYN, cli_isn, 32'h0, 16'd1460);
        send_wire(build_frame(h, bytes_new(0)));
        wait_tx(1, "syn-ack");
        fb = cap_frame(0); parse_frame(fb, pf, err, ok);
        check(ok, {"syn-ack parses: ", err});
        check(pf.flags == (F_SYN|F_ACK) && pf.ack == cli_isn + 1 && pf.mss == 16'd1460,
              $sformatf("syn-ack fields flags %02x ack %08x mss %0d", pf.flags, pf.ack, pf.mss));
        check(pf.dst_mac == CLI_MAC && pf.dst_ip == CLI_IP, "syn-ack addressing");
        our_isn = pf.seq;

        //--- 2. ACK -> established ---
        h = cli_hdr(F_ACK, cli_isn + 1, our_isn + 1, 16'h0);
        send_wire(build_frame(h, bytes_new(0)));
        repeat (40) @(posedge clock);
        check(tcp_connected, "connected through the chain");
        check(tcp_peer_ip == CLI_IP && tcp_peer_port == CLI_PORT, "peer reported");

        //--- 3. data -> echo, byte exact ---
        h = cli_hdr(F_PSH|F_ACK, cli_isn + 1, our_isn + 1, 16'h0);
        send_wire(build_frame(h, bytes_from_hex("68656c6c6f")));  // "hello"
        wait_tx(2, "echo");
        fb = cap_frame(cfcount - 1); parse_frame(fb, pf, err, ok);
        check(ok, {"echo parses: ", err});
        check(pf.flags[3] && pf.flags[4] && pf.seq == our_isn + 1
              && pf.ack == cli_isn + 1 + 5, "echo header");
        check(bytes_eq(frame_payload(fb), bytes_from_hex("68656c6c6f")), "echo payload");

        //--- 4. close: FIN -> our FIN ---
        h = cli_hdr(F_ACK, cli_isn + 1 + 5, our_isn + 1 + 5, 16'h0);
        send_wire(build_frame(h, bytes_new(0)));
        repeat (20) @(posedge clock);
        h = cli_hdr(F_FIN|F_ACK, cli_isn + 1 + 5, our_isn + 1 + 5, 16'h0);
        send_wire(build_frame(h, bytes_new(0)));
        wait_tx(cfcount + 1, "our-fin");
        fb = cap_frame(cfcount - 1); parse_frame(fb, pf, err, ok);
        check(ok && pf.flags[0], $sformatf("our-fin flags %02x", pf.flags));

        $display("rmii_eth_tcp_endpoint_tb: %0d checks", checks);
        if (errors == 0) $display("rmii_eth_tcp_endpoint_tb: ALL TESTS PASSED");
        else             $display("rmii_eth_tcp_endpoint_tb: %0d ERROR(S)", errors);
        $finish;
    end

    initial begin
        #500000000;
        errors = errors + 1;
        $error("watchdog: %0d checks, cfcount %0d, conn %0b", checks, cfcount, tcp_connected);
        $display("rmii_eth_tcp_endpoint_tb: %0d ERROR(S)", errors);
        $finish;
    end

endmodule
