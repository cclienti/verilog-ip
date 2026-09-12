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
// Title         : AXI Stream TCP Socket
//-----------------------------------------------------------------------------
// File          : axi_stream_tcp_socket_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-09-12
// Last modified : 2026-09-12
//-----------------------------------------------------------------------------
// Description: Drives a whole connection into the socket, with m_app
// wired straight back to s_app so the socket is an echo server. TCP
// segments are built by tcp_model_pkg and the emitted Ethernet frames
// are captured and parsed by the same model. It walks the passive
// open (SYN, SYN-ACK, ACK), one data segment echoed back, and the
// close (FIN, our FIN, ACK), checking the frames the socket sends at
// each step.
//
// Reports axi_stream_tcp_socket_tb: ALL TESTS PASSED or N ERROR(S).

`timescale 1 ns / 100 ps

module axi_stream_tcp_socket_tb;
    import tcp_model_pkg::*;

    localparam logic [47:0] LOCAL_MAC  = 48'h02_00_00_00_00_2a;
    localparam logic [31:0] LOCAL_IP   = 32'hc0a85a2a;   // 192.168.90.42
    localparam logic [15:0] LISTEN     = 16'd23;
    localparam logic [47:0] CLI_MAC    = 48'h3c_97_0e_12_34_56;
    localparam logic [31:0] CLI_IP     = 32'hc0a85a01;   // 192.168.90.1
    localparam logic [15:0] CLI_PORT   = 16'd51234;

    logic        clock, sreset;

    logic [7:0]  s_tdata;
    logic        s_tuser, s_tvalid, s_tlast, s_tready;
    logic [31:0] s_src_ip, s_dst_ip;
    logic [15:0] s_length;
    logic [47:0] s_src_mac;

    logic [7:0]  m_tdata;
    logic        m_tuser, m_tvalid, m_tlast, m_tready;

    logic [7:0]  mapp_tdata, sapp_tdata;
    logic        mapp_tuser, mapp_tvalid, mapp_tlast, mapp_tready;
    logic        sapp_tuser, sapp_tvalid, sapp_tlast, sapp_tready;

    logic        conn;
    logic [31:0] pip;
    logic [15:0] pport;

    integer errors = 0;
    integer checks = 0;

    // Captured output frames
    logic [7:0] fbuf [0:2047];
    integer     fn;
    logic [7:0] frames [0:15][0:255];
    integer     flen [0:15];
    integer     fcount;

    //----------------------------------------------------------------
    // DUT, with the echo loopback m_app -> s_app
    //----------------------------------------------------------------
    axi_stream_tcp_socket dut (
        .clock (clock), .sreset (sreset),
        .local_mac (LOCAL_MAC), .local_ip (LOCAL_IP), .listen_port (LISTEN),
        .s_axi_tdata (s_tdata), .s_axi_tuser (s_tuser), .s_axi_tvalid (s_tvalid),
        .s_axi_tlast (s_tlast), .s_axi_tready (s_tready),
        .s_src_ip (s_src_ip), .s_dst_ip (s_dst_ip), .s_length (s_length), .s_src_mac (s_src_mac),
        .m_axi_tdata (m_tdata), .m_axi_tuser (m_tuser), .m_axi_tvalid (m_tvalid),
        .m_axi_tlast (m_tlast), .m_axi_tready (m_tready),
        .m_app_tdata (mapp_tdata), .m_app_tuser (mapp_tuser), .m_app_tvalid (mapp_tvalid),
        .m_app_tlast (mapp_tlast), .m_app_tready (mapp_tready),
        .s_app_tdata (sapp_tdata), .s_app_tuser (sapp_tuser), .s_app_tvalid (sapp_tvalid),
        .s_app_tlast (sapp_tlast), .s_app_tready (sapp_tready),
        .connected (conn), .peer_ip (pip), .peer_port (pport)
    );

    // Echo wire
    assign sapp_tdata  = mapp_tdata;
    assign sapp_tuser  = mapp_tuser;
    assign sapp_tvalid = mapp_tvalid;
    assign sapp_tlast  = mapp_tlast;
    assign mapp_tready = sapp_tready;

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

    // Wait until fcount reaches n or a timeout, return the last frame as bytes
    task automatic wait_frame(input integer n, input string what);
        integer g;
        g = 0;
        while (fcount < n && g < 2000) begin @(posedge clock); g = g + 1; end
        if (fcount < n) begin errors = errors + 1; $error("%s: no frame (have %0d want %0d)", what, fcount, n); end
    endtask

    function automatic bytes_t frame_bytes(input integer idx);
        bytes_t b = new[flen[idx]];
        for (int i = 0; i < flen[idx]; i++) b[i] = frames[idx][i];
        return b;
    endfunction

    //----------------------------------------------------------------
    // Drive one segment (L4 unit) with its side-bands
    //----------------------------------------------------------------
    task automatic send_seg(input bytes_t seg);
        @(negedge clock);
        for (int i = 0; i < seg.size(); i++) begin
            @(negedge clock);
            s_tvalid = 1'b1; s_tdata = seg[i]; s_tlast = (i == seg.size()-1); s_tuser = 1'b0;
            s_src_ip = CLI_IP; s_dst_ip = LOCAL_IP; s_src_mac = CLI_MAC; s_length = 16'(seg.size());
            @(posedge clock);
            while (!s_tready) @(posedge clock);
        end
        @(negedge clock);
        s_tvalid = 1'b0; s_tlast = 1'b0;
    endtask

    function automatic tcp_hdr_t cli_hdr(input logic [7:0] fl, input logic [31:0] sq,
                                         input logic [31:0] ak, input logic [15:0] m);
        tcp_hdr_t h = '0;
        h.src_ip = CLI_IP; h.dst_ip = LOCAL_IP;
        h.src_port = CLI_PORT; h.dst_port = LISTEN;
        h.seq = sq; h.ack = ak; h.flags = fl; h.window = 16'd64240;
        h.urgent = 16'h0; h.mss = m;
        return h;
    endfunction

    //----------------------------------------------------------------
    // Test
    //----------------------------------------------------------------
    tcp_hdr_t h, pf;
    bytes_t   seg, fb;
    string    err;
    bit       ok;
    logic [31:0] cli_isn, our_isn;

    initial begin
        sreset = 1'b1;
        s_tvalid = 1'b0; s_tlast = 1'b0; s_tuser = 1'b0; s_tdata = 8'h0;
        s_src_ip = 32'h0; s_dst_ip = 32'h0; s_src_mac = 48'h0; s_length = 16'h0;
        fn = 0; fcount = 0;
        repeat (5) @(negedge clock);
        sreset = 1'b0;
        @(negedge clock);

        cli_isn = 32'h1A2B3C4D;

        //--- 1. SYN -> expect SYN-ACK ---
        h = cli_hdr(F_SYN, cli_isn, 32'h0, 16'd1460);
        send_seg(build_tcp(h, bytes_new(0)));
        wait_frame(1, "syn-ack");
        fb = frame_bytes(0);
        parse_frame(fb, pf, err, ok);
        check(ok, {"syn-ack parses: ", err});
        check(pf.flags == (F_SYN|F_ACK), $sformatf("syn-ack flags %02x", pf.flags));
        check(pf.ack == cli_isn + 1, $sformatf("syn-ack ack %08x vs %08x", pf.ack, cli_isn+1));
        check(pf.mss == 16'd1460, $sformatf("syn-ack mss %0d", pf.mss));
        check(pf.dst_ip == CLI_IP && pf.src_ip == LOCAL_IP, "syn-ack addressing");
        our_isn = pf.seq;

        //--- 2. ACK -> ESTABLISHED ---
        h = cli_hdr(F_ACK, cli_isn + 1, our_isn + 1, 16'h0);
        send_seg(build_tcp(h, bytes_new(0)));
        repeat (10) @(posedge clock);
        check(conn, "connected after the handshake ACK");

        //--- 3. data "hello" -> expect the echo back ---
        h = cli_hdr(F_PSH|F_ACK, cli_isn + 1, our_isn + 1, 16'h0);
        send_seg(build_tcp(h, bytes_from_hex("68656c6c6f")));  // "hello"
        wait_frame(2, "echo");
        fb = frame_bytes(fcount - 1);
        parse_frame(fb, pf, err, ok);
        check(ok, {"echo parses: ", err});
        check(pf.flags[3] && pf.flags[4], $sformatf("echo PSH|ACK flags %02x", pf.flags));
        check(pf.seq == our_isn + 1, $sformatf("echo seq %08x vs %08x", pf.seq, our_isn+1));
        check(pf.ack == cli_isn + 1 + 5, $sformatf("echo ack %08x vs %08x", pf.ack, cli_isn+1+5));
        check(bytes_eq(frame_payload(fb), bytes_from_hex("68656c6c6f")), "echo payload");

        //--- 4. ACK the echo ---
        h = cli_hdr(F_ACK, cli_isn + 1 + 5, our_isn + 1 + 5, 16'h0);
        send_seg(build_tcp(h, bytes_new(0)));
        repeat (10) @(posedge clock);

        //--- 5. FIN -> expect our FIN (after the app close loops back) ---
        h = cli_hdr(F_FIN|F_ACK, cli_isn + 1 + 5, our_isn + 1 + 5, 16'h0);
        send_seg(build_tcp(h, bytes_new(0)));
        wait_frame(fcount + 1, "our-fin");
        fb = frame_bytes(fcount - 1);
        parse_frame(fb, pf, err, ok);
        check(ok, {"our-fin parses: ", err});
        check(pf.flags[0], $sformatf("our-fin has FIN, flags %02x", pf.flags));

        //--- 6. ACK our FIN -> CLOSED, back to LISTEN ---
        h = cli_hdr(F_ACK, cli_isn + 2 + 5, pf.seq + 1, 16'h0);
        send_seg(build_tcp(h, bytes_new(0)));
        repeat (20) @(posedge clock);
        check(!conn, "closed after our FIN is acked");

        $display("axi_stream_tcp_socket_tb: %0d checks", checks);
        if (errors == 0) $display("axi_stream_tcp_socket_tb: ALL TESTS PASSED");
        else             $display("axi_stream_tcp_socket_tb: %0d ERROR(S)", errors);
        $finish;
    end

    initial begin
        #200000000;
        errors = errors + 1;
        $error("watchdog: %0d checks, fcount %0d, conn %0b", checks, fcount, conn);
        $display("axi_stream_tcp_socket_tb: %0d ERROR(S)", errors);
        $finish;
    end

endmodule
