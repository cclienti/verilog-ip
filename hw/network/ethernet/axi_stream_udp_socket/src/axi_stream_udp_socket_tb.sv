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
// Title         : AXI Stream UDP Socket
//-----------------------------------------------------------------------------
// File          : axi_stream_udp_socket_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-09-15
// Last modified : 2026-09-15
//-----------------------------------------------------------------------------
// Description: m_app wired straight back to s_app, address fields
// included, so the socket is a UDP echo server. Datagrams are built
// by udp_model_pkg and the emitted Ethernet frames are captured and
// parsed by the same model. A small receive/transmit buffer (64
// bytes, 4 datagrams) makes the "does not fit" and "no frame slot"
// paths reachable with short datagrams and few of them.
//
// Reports axi_stream_udp_socket_tb: ALL TESTS PASSED or N ERROR(S).

`timescale 1 ns / 100 ps

module axi_stream_udp_socket_tb;
    import udp_model_pkg::*;

    localparam logic [47:0] LOCAL_MAC = 48'h02_00_00_00_00_2a;
    localparam logic [31:0] LOCAL_IP  = 32'hc0a85a2a;   // 192.168.90.42
    localparam logic [15:0] LISTEN    = 16'd7;          // the echo port
    localparam logic [47:0] CLI_MAC   = 48'h3c_97_0e_12_34_56;
    localparam logic [31:0] CLI_IP    = 32'hc0a85a01;   // 192.168.90.1
    localparam logic [15:0] CLI_PORT  = 16'd51234;
    localparam logic [31:0] BROADCAST = 32'hFFFFFFFF;

    logic        clock, sreset;

    logic [7:0]  s_tdata;
    logic        s_tuser, s_tvalid, s_tlast, s_tready;
    logic [31:0] s_src_ip, s_dst_ip;
    logic [15:0] s_length;
    logic [47:0] s_src_mac;

    logic [7:0]  m_tdata;
    logic        m_tuser, m_tvalid, m_tlast, m_tready;

    logic [7:0]  mapp_tdata, sapp_tdata;
    logic        mapp_tvalid, mapp_tlast, mapp_tready;
    logic        sapp_tvalid, sapp_tlast, sapp_tready;
    logic [47:0] mapp_peer_mac; logic [31:0] mapp_peer_ip; logic [15:0] mapp_peer_port;

    logic hold_app;   // testbench override: stall the echo wire's consumer

    integer errors = 0;
    integer checks = 0;

    // Captured output frames
    logic [7:0] fbuf [0:2047];
    integer     fn;
    logic [7:0] frames [0:95][0:511];
    integer     flen [0:95];
    integer     fcount;

    //----------------------------------------------------------------
    // DUT, with the echo loopback m_app -> s_app, address fields
    // included, hold_app able to stall it for the frame-slot test
    //----------------------------------------------------------------
    axi_stream_udp_socket #(
        .LOG2_RX_DEPTH (6), .LOG2_RX_FRAMES (2),
        .LOG2_TX_DEPTH (6), .LOG2_TX_FRAMES (2)
    ) dut (
        .clock (clock), .sreset (sreset),
        .local_mac (LOCAL_MAC), .local_ip (LOCAL_IP), .listen_port (LISTEN),
        .s_axi_tdata (s_tdata), .s_axi_tuser (s_tuser), .s_axi_tvalid (s_tvalid),
        .s_axi_tlast (s_tlast), .s_axi_tready (s_tready),
        .s_src_ip (s_src_ip), .s_dst_ip (s_dst_ip), .s_length (s_length), .s_src_mac (s_src_mac),
        .m_axi_tdata (m_tdata), .m_axi_tuser (m_tuser), .m_axi_tvalid (m_tvalid),
        .m_axi_tlast (m_tlast), .m_axi_tready (m_tready),
        .m_app_tdata (mapp_tdata), .m_app_tvalid (mapp_tvalid), .m_app_tlast (mapp_tlast),
        .m_app_tready (mapp_tready),
        .m_app_peer_mac (mapp_peer_mac), .m_app_peer_ip (mapp_peer_ip), .m_app_peer_port (mapp_peer_port),
        .s_app_tdata (sapp_tdata), .s_app_tvalid (sapp_tvalid), .s_app_tlast (sapp_tlast),
        .s_app_tready (sapp_tready),
        .s_app_dst_mac (mapp_peer_mac), .s_app_dst_ip (mapp_peer_ip), .s_app_dst_port (mapp_peer_port)
    );

    // Echo wire: data, tlast and the address fields, unchanged
    assign sapp_tdata  = mapp_tdata;
    // hold_app suppresses the echo in both directions: a real stalled
    // application neither reads m_app nor writes s_app, and gating only
    // mapp_tready while leaving sapp_tvalid wired to mapp_tvalid would
    // re-offer the same un-advanced RX byte to the transmit buffer every
    // cycle, since the two streams' handshakes are otherwise independent.
    assign sapp_tvalid = hold_app ? 1'b0 : mapp_tvalid;
    assign sapp_tlast  = mapp_tlast;
    assign mapp_tready = hold_app ? 1'b0 : sapp_tready;

    initial clock = 0;
    always #10 clock = !clock;

    assign m_tready = 1'b1;   // always accept the socket's output

    task automatic check(input bit ok, input string what);
        checks = checks + 1;
        if (!ok) begin errors = errors + 1; $error("%s", what); end
    endtask

    //----------------------------------------------------------------
    // Output-frame monitor: collect each emitted Ethernet frame
    //----------------------------------------------------------------
    always @(posedge clock) begin
        if (!sreset && m_tvalid && m_tready) begin
            fbuf[fn] = m_tdata; fn = fn + 1;
            if (m_tlast) begin
                for (int i = 0; i < fn; i++) frames[fcount][i] = fbuf[i];
                flen[fcount] = fn;
                fcount = fcount + 1;
                fn = 0;
            end
        end
    end

    task automatic wait_frame(input integer n, input string what);
        integer g;
        g = 0;
        while (fcount < n && g < 2000) begin @(posedge clock); g = g + 1; end
        if (fcount < n) begin errors = errors + 1; $error("%s: no frame (have %0d want %0d)", what, fcount, n); end
    endtask

    // No frame arrives within a bounded wait, given the current fcount
    task automatic expect_no_frame(input string what);
        integer g;
        integer start_count;
        start_count = fcount;
        for (g = 0; g < 300; g = g + 1) @(posedge clock);
        check(fcount == start_count, {what, ": unexpected frame arrived"});
    endtask

    function automatic bytes_t frame_bytes(input integer idx);
        bytes_t b = new[flen[idx]];
        for (int i = 0; i < flen[idx]; i++) b[i] = frames[idx][i];
        return b;
    endfunction

    //----------------------------------------------------------------
    // Drive one L4 unit (a UDP datagram) with its side-bands
    //----------------------------------------------------------------
    task automatic send_dgram(input bytes_t seg, input logic [31:0] src_ip, input logic [31:0] dst_ip);
        @(negedge clock);
        for (int i = 0; i < seg.size(); i++) begin
            @(negedge clock);
            s_tvalid = 1'b1; s_tdata = seg[i]; s_tlast = (i == seg.size()-1); s_tuser = 1'b0;
            s_src_ip = src_ip; s_dst_ip = dst_ip; s_src_mac = CLI_MAC; s_length = 16'(seg.size());
            @(posedge clock);
            while (!s_tready) @(posedge clock);
        end
        @(negedge clock);
        s_tvalid = 1'b0; s_tlast = 1'b0;
    endtask

    // Like send_dgram, but the beat at index tuser_at also carries tuser
    task automatic send_dgram_tuser(input bytes_t seg, input logic [31:0] src_ip, input logic [31:0] dst_ip,
                                    input integer tuser_at);
        @(negedge clock);
        for (int i = 0; i < seg.size(); i++) begin
            @(negedge clock);
            s_tvalid = 1'b1; s_tdata = seg[i]; s_tlast = (i == seg.size()-1);
            s_tuser  = (i == tuser_at);
            s_src_ip = src_ip; s_dst_ip = dst_ip; s_src_mac = CLI_MAC; s_length = 16'(seg.size());
            @(posedge clock);
            while (!s_tready) @(posedge clock);
        end
        @(negedge clock);
        s_tvalid = 1'b0; s_tlast = 1'b0; s_tuser = 1'b0;
    endtask

    function automatic udp_hdr_t cli_hdr(input logic [15:0] dport, input bit no_csum);
        udp_hdr_t h = '0;
        h.src_ip = CLI_IP; h.dst_ip = LOCAL_IP;
        h.src_port = CLI_PORT; h.dst_port = dport;
        h.no_checksum = no_csum;
        return h;
    endfunction

    // Check a captured reply: a valid frame from LOCAL to CLIENT,
    // echoing payload back on LISTEN -> CLI_PORT
    task automatic check_reply(input integer idx, input bytes_t payload, input string what);
        udp_hdr_t p;
        string    err;
        bit       ok;
        bytes_t   f;
        f = frame_bytes(idx);
        parse_frame(f, p, err, ok);
        check(ok, {what, ": reply parses: ", err});
        check(p.dst_mac == CLI_MAC && p.dst_ip == CLI_IP, {what, ": reply addressed to the client"});
        check(p.src_ip == LOCAL_IP && p.src_port == LISTEN && p.dst_port == CLI_PORT,
              {what, ": reply header fields"});
        check(bytes_eq(frame_payload(f), payload), {what, ": reply payload"});
    endtask

    // Wait for exactly one more frame than currently captured, and
    // check it: eliminates hand-tracked frame-count arithmetic
    task automatic expect_reply(input bytes_t payload, input string what);
        integer idx;
        idx = fcount;
        wait_frame(fcount + 1, what);
        check_reply(idx, payload, what);
    endtask

    //----------------------------------------------------------------
    // Test
    //----------------------------------------------------------------
    udp_hdr_t h;
    bytes_t   seg, pl, f;
    string    err;
    bit       ok;
    int       n;
    integer   n_before;

    initial begin
        sreset   = 1'b1;
        hold_app = 1'b0;
        s_tvalid = 1'b0; s_tlast = 1'b0; s_tuser = 1'b0; s_tdata = 8'h00;
        s_src_ip = CLI_IP; s_dst_ip = LOCAL_IP; s_src_mac = CLI_MAC; s_length = 16'd0;
        fn = 0; fcount = 0;
        repeat (5) @(posedge clock);
        sreset = 1'b0;
        repeat (5) @(posedge clock);

        //------------------------------------------------------------
        // 1. Basic echo
        //------------------------------------------------------------
        h   = cli_hdr(LISTEN, 1'b0);
        pl  = bytes_from_hex("68656c6c6f");     // "hello"
        seg = build_udp(h, pl);
        send_dgram(seg, CLI_IP, LOCAL_IP);
        expect_reply(pl, "basic echo");

        //------------------------------------------------------------
        // 2. Wrong port: dropped, no reply
        //------------------------------------------------------------
        h   = cli_hdr(16'd9999, 1'b0);
        seg = build_udp(h, bytes_from_hex("2b2b2b"));
        send_dgram(seg, CLI_IP, LOCAL_IP);
        expect_no_frame("wrong port");

        //------------------------------------------------------------
        // 3. Broadcast destination: dropped, no reply
        //------------------------------------------------------------
        h        = cli_hdr(LISTEN, 1'b0);
        h.dst_ip = BROADCAST;
        seg      = build_udp(h, bytes_from_hex("2c2c2c"));
        send_dgram(seg, CLI_IP, BROADCAST);
        expect_no_frame("broadcast destination");

        //------------------------------------------------------------
        // 4. Bad checksum: doomed, no reply
        //------------------------------------------------------------
        h   = cli_hdr(LISTEN, 1'b0);
        seg = build_udp(h, bytes_from_hex("2d2d2d"));
        seg[8] = seg[8] ^ 8'h01;   // flip a payload bit
        send_dgram(seg, CLI_IP, LOCAL_IP);
        expect_no_frame("bad checksum");
        // the socket recovers cleanly for the next datagram
        h   = cli_hdr(LISTEN, 1'b0);
        pl  = bytes_from_hex("2e2e2e");
        seg = build_udp(h, pl);
        send_dgram(seg, CLI_IP, LOCAL_IP);
        expect_reply(pl, "after bad checksum");

        //------------------------------------------------------------
        // 5. Checksum field zero (RFC 768 "no checksum"): accepted
        //    even though the bytes no longer sum to a valid checksum
        //------------------------------------------------------------
        h   = cli_hdr(LISTEN, 1'b1);
        pl  = bytes_from_hex("2f2f2f");
        seg = build_udp(h, pl);
        seg[8] = seg[8] ^ 8'h01;   // would fail a real checksum, if checked
        send_dgram(seg, CLI_IP, LOCAL_IP);
        expect_reply(bytes_from_hex("2e2f2f"), "no-checksum datagram (damaged byte)");

        //------------------------------------------------------------
        // 6. tuser mid-datagram: doomed, no reply
        //------------------------------------------------------------
        h   = cli_hdr(LISTEN, 1'b0);
        seg = build_udp(h, bytes_from_hex("30303030"));
        send_dgram_tuser(seg, CLI_IP, LOCAL_IP, 5);
        expect_no_frame("tuser mid-datagram");

        //------------------------------------------------------------
        // 7. UDP length field disagrees with s_length: structurally
        //    bad, DROP, no reply, and the socket recovers afterward
        //------------------------------------------------------------
        h   = cli_hdr(LISTEN, 1'b0);
        seg = build_udp(h, bytes_from_hex("313131"));
        seg[5] = seg[5] ^ 8'h01;   // corrupt the length field's low byte
        send_dgram(seg, CLI_IP, LOCAL_IP);
        expect_no_frame("length field mismatch");
        h   = cli_hdr(LISTEN, 1'b0);
        pl  = bytes_from_hex("323232");
        seg = build_udp(h, pl);
        send_dgram(seg, CLI_IP, LOCAL_IP);
        expect_reply(pl, "after length mismatch");

        //------------------------------------------------------------
        // 8. Shorter than a UDP header: absorbed in IDLE, no reply,
        //    and the socket recovers afterward
        //------------------------------------------------------------
        send_dgram(bytes_pattern(3, 8'hAA), CLI_IP, LOCAL_IP);
        expect_no_frame("too short for a header");
        h   = cli_hdr(LISTEN, 1'b0);
        pl  = bytes_from_hex("333333");
        seg = build_udp(h, pl);
        send_dgram(seg, CLI_IP, LOCAL_IP);
        expect_reply(pl, "after too-short datagram");

        //------------------------------------------------------------
        // 9. Payload too large for the 64-byte receive buffer:
        //    doomed from its first byte, no reply, recovers after
        //------------------------------------------------------------
        h   = cli_hdr(LISTEN, 1'b0);
        seg = build_udp(h, bytes_pattern(100, 8'h40));
        send_dgram(seg, CLI_IP, LOCAL_IP);
        expect_no_frame("oversized payload");
        h   = cli_hdr(LISTEN, 1'b0);
        pl  = bytes_from_hex("34343434");
        seg = build_udp(h, pl);
        send_dgram(seg, CLI_IP, LOCAL_IP);
        expect_reply(pl, "after oversized payload");

        //------------------------------------------------------------
        // 10. No free frame slot: with the app held off, four
        //     datagrams fill the four-frame receive buffer; a fifth
        //     is dropped; releasing the app drains exactly four
        //------------------------------------------------------------
        n_before = fcount;
        hold_app = 1'b1;
        for (n = 0; n < 4; n = n + 1) begin
            h   = cli_hdr(LISTEN, 1'b0);
            seg = build_udp(h, bytes_pattern(2, 8'h50 + 8'(n)));
            send_dgram(seg, CLI_IP, LOCAL_IP);
        end
        h   = cli_hdr(LISTEN, 1'b0);
        seg = build_udp(h, bytes_from_hex("6060"));
        send_dgram(seg, CLI_IP, LOCAL_IP);   // the fifth: no frame slot free
        repeat (20) @(posedge clock);
        hold_app = 1'b0;
        wait_frame(n_before + 4, "four queued replies drain");
        repeat (50) @(posedge clock);   // give a wrongly-undropped fifth time to arrive
        check(fcount == n_before + 4, "exactly four replies drained, the fifth was dropped");

        //------------------------------------------------------------
        // 11. RFC 768's edge case in hardware: a reply whose computed
        //     checksum is exactly zero must be sent as all ones.
        //     Found by search against this bench's own addresses:
        //     payload 02 34 echoed from LOCAL_IP:LISTEN to
        //     CLI_IP:CLI_PORT sums to zero before the substitution.
        //------------------------------------------------------------
        h   = cli_hdr(LISTEN, 1'b0);
        pl  = bytes_from_hex("0234");
        seg = build_udp(h, pl);
        send_dgram(seg, CLI_IP, LOCAL_IP);
        n_before = fcount;
        expect_reply(pl, "computed-zero checksum");
        f = frame_bytes(n_before);
        check({f[40], f[41]} == 16'hFFFF,
              $sformatf("computed-zero checksum sent as FFFF: got %04x", {f[40], f[41]}));

        //------------------------------------------------------------
        // 12. Random round trips: well-formed datagrams of varying
        //     length, checksum enabled and disabled both
        //------------------------------------------------------------
        for (int i = 0; i < 60; i++) begin
            n  = $urandom_range(1, 40);
            h  = cli_hdr(LISTEN, 1'($urandom_range(0, 3) == 0));
            pl = new[n];
            for (int k = 0; k < n; k++) pl[k] = 8'($urandom());
            seg = build_udp(h, pl);
            send_dgram(seg, CLI_IP, LOCAL_IP);
            expect_reply(pl, $sformatf("random %0d", i));
        end

        //------------------------------------------------------------
        // Verdict
        //------------------------------------------------------------
        $display("axi_stream_udp_socket_tb: %0d checks", checks);
        if (errors == 0)
            $display("axi_stream_udp_socket_tb: ALL TESTS PASSED");
        else
            $display("axi_stream_udp_socket_tb: %0d ERROR(S)", errors);
        $finish;
    end

endmodule
