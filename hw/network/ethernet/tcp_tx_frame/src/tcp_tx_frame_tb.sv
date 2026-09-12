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
// Title         : TCP Transmit Frame Builder
//-----------------------------------------------------------------------------
// File          : tcp_tx_frame_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-09-12
// Last modified : 2026-09-12
//-----------------------------------------------------------------------------
// Description: Drives the frame builder with every segment kind and
// hundreds of random field/payload combinations, captures the emitted
// bytes under random backpressure, and compares them against
// tcp_model_pkg.build_frame -- an independent stack -- byte for byte,
// then parses them back with parse_frame and checks every field.
//
// Backpressure is a ready registered off the clock and a posedge
// monitor that records a beat when tvalid and tready are both high:
// both are edge-aligned, so the capture is race-free across
// simulators (a ready driven combinationally right before the edge
// dropped the first beat under Verilator, not Icarus).
//
// Reports tcp_tx_frame_tb: ALL TESTS PASSED or N ERROR(S).

`timescale 1 ns / 100 ps

module tcp_tx_frame_tb;
    import tcp_model_pkg::*;

    //----------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------
    logic        clock;
    logic        sreset;

    logic        start;
    logic        with_mss;
    logic [15:0] pl_len;
    logic [47:0] dst_mac, src_mac;
    logic [15:0] ip_id;
    logic [31:0] src_ip, dst_ip;
    logic [15:0] src_port, dst_port;
    logic [31:0] seq, ack;
    logic [7:0]  flags;
    logic [15:0] window, mss;
    logic [15:0] pl_addr;
    logic [7:0]  pl_data;
    logic [7:0]  m_tdata;
    logic        m_tuser, m_tvalid, m_tlast, m_tready;
    logic        busy;

    integer errors = 0;
    integer checks = 0;

    // Payload memory the builder reads back through pl_addr/pl_data
    logic [7:0] pmem [0:2047];
    assign pl_data = pmem[pl_addr[10:0]];

    // Capture, shared with the monitor
    logic       cap_en;              // let the monitor and ready run
    logic [7:0] capbuf [0:2047];     // captured beats
    integer     capn;
    logic       cap_done;            // tlast seen

    //----------------------------------------------------------------
    // DUT
    //----------------------------------------------------------------
    tcp_tx_frame tcp_tx_frame_inst (
        .clock (clock), .sreset (sreset),
        .start (start), .with_mss (with_mss), .pl_len (pl_len),
        .dst_mac (dst_mac), .src_mac (src_mac), .ip_id (ip_id),
        .src_ip (src_ip), .dst_ip (dst_ip),
        .src_port (src_port), .dst_port (dst_port),
        .seq (seq), .ack (ack), .flags (flags), .window (window), .mss (mss),
        .pl_addr (pl_addr), .pl_data (pl_data),
        .m_axi_tdata (m_tdata), .m_axi_tuser (m_tuser), .m_axi_tvalid (m_tvalid),
        .m_axi_tlast (m_tlast), .m_axi_tready (m_tready), .busy (busy)
    );

    //----------------------------------------------------------------
    // Clock and reset
    //----------------------------------------------------------------
    initial clock = 0;
    always #10 clock = !clock;

    //----------------------------------------------------------------
    // Registered ready, and the capture monitor: both off the posedge
    //----------------------------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset || !cap_en) m_tready <= 1'b0;
        else                   m_tready <= ($urandom_range(0, 2) != 0);  // ~2/3
    end

    always @(posedge clock) begin
        if (!sreset && cap_en && m_tvalid && m_tready) begin
            capbuf[capn] = m_tdata;
            capn         = capn + 1;
            if (m_tlast) cap_done = 1'b1;
        end
    end

    task automatic check(input bit ok, input string what);
        checks = checks + 1;
        if (!ok) begin errors = errors + 1; $error("%s", what); end
    endtask

    //----------------------------------------------------------------
    // Drive one segment, capture the frame, compare with the model
    //----------------------------------------------------------------
    task automatic run_one(input string name, input bit wm, input int n,
                           input logic [7:0] fl);
        tcp_hdr_t h;
        bytes_t   payload;
        bytes_t   golden;
        bytes_t   cap;
        tcp_hdr_t p;
        string    err;
        bit       ok;
        integer   guard;

        h = '0;
        h.dst_mac  = 48'({$urandom(), $urandom()});
        h.src_mac  = 48'({$urandom(), $urandom()});
        h.ip_id    = 16'($urandom());
        h.df       = 1'b1;
        h.ttl      = 8'd64;
        h.src_ip   = $urandom();
        h.dst_ip   = $urandom();
        h.src_port = 16'($urandom());
        h.dst_port = 16'($urandom());
        h.seq      = $urandom();
        h.ack      = $urandom();
        h.flags    = fl;
        h.window   = 16'($urandom());
        h.urgent   = 16'h0000;
        h.mss      = wm ? 16'd1460 : 16'h0000;

        payload = new[n];
        for (int i = 0; i < n; i++) begin
            payload[i] = 8'($urandom());
            pmem[i]    = payload[i];
        end
        golden = build_frame(h, payload);

        // Arm the capture, then pulse start
        @(negedge clock);
        capn = 0; cap_done = 1'b0; cap_en = 1'b1;
        with_mss = wm;  pl_len = 16'(n);
        dst_mac = h.dst_mac;  src_mac = h.src_mac;  ip_id = h.ip_id;
        src_ip = h.src_ip;    dst_ip = h.dst_ip;
        src_port = h.src_port; dst_port = h.dst_port;
        seq = h.seq;  ack = h.ack;  flags = h.flags;  window = h.window;
        mss = h.mss;
        start = 1'b1;
        @(negedge clock);
        start = 1'b0;

        guard = 0;
        while (!cap_done && guard < 6000) begin
            @(posedge clock);
            guard = guard + 1;
        end
        @(negedge clock);
        cap_en = 1'b0;
        if (!cap_done) begin
            errors = errors + 1;
            $error("%s: no tlast within the guard", name);
        end

        cap = new[capn];
        for (int i = 0; i < capn; i++) cap[i] = capbuf[i];

        check(bytes_eq(cap, golden),
              $sformatf("%s: emitted frame differs\n  emit %s\n  gold %s", name, bytes_hex(cap), bytes_hex(golden)));
        p = '0;
        parse_frame(cap, p, err, ok);
        check(ok, {name, ": emitted frame parses: ", err});
        check(p.src_port == h.src_port && p.dst_port == h.dst_port
              && p.seq == h.seq && p.ack == h.ack && p.flags == h.flags
              && p.window == h.window && p.mss == h.mss
              && p.src_ip == h.src_ip && p.dst_ip == h.dst_ip
              && p.dst_mac == h.dst_mac && p.src_mac == h.src_mac,
              {name, ": parsed fields differ"});
        check(bytes_eq(frame_payload(cap), payload), {name, ": payload differs"});
    endtask

    //----------------------------------------------------------------
    // Test sequence
    //----------------------------------------------------------------
    integer     n;
    logic [7:0] fl;

    initial begin
        sreset = 1'b1;
        start = 1'b0; with_mss = 1'b0; pl_len = 16'd0;
        cap_en = 1'b0; capn = 0; cap_done = 1'b0;
        repeat (4) @(negedge clock);
        sreset = 1'b0;
        @(negedge clock);

        // One of each kind
        run_one("syn_ack",  1'b1, 0,    F_SYN | F_ACK);
        run_one("pure_ack", 1'b0, 0,    F_ACK);
        run_one("fin",      1'b0, 0,    F_FIN | F_ACK);
        run_one("rst",      1'b0, 0,    F_RST | F_ACK);
        run_one("data1",    1'b0, 1,    F_PSH | F_ACK);
        run_one("data5",    1'b0, 5,    F_PSH | F_ACK);   // odd length, tests the sum pad
        run_one("data_mss", 1'b0, 1460, F_PSH | F_ACK);   // a full segment

        // Random mix: mostly data of varied length, some control
        for (int i = 0; i < 300; i++) begin
            n  = ($urandom_range(0, 3) == 0) ? 0 : $urandom_range(1, 200);
            fl = 8'($urandom()) | F_ACK;
            run_one($sformatf("rand%0d", i), 1'b0, n, fl);
        end
        // Random SYN-ACKs, no payload, MSS option present
        for (int i = 0; i < 40; i++) begin
            run_one($sformatf("synack%0d", i), 1'b1, 0, F_SYN | F_ACK);
        end

        $display("tcp_tx_frame_tb: %0d checks", checks);
        if (errors == 0) $display("tcp_tx_frame_tb: ALL TESTS PASSED");
        else             $display("tcp_tx_frame_tb: %0d ERROR(S)", errors);
        $finish;
    end

    // Watchdog
    initial begin
        #50000000;
        errors = errors + 1;
        $error("watchdog: %0d checks done", checks);
        $display("tcp_tx_frame_tb: %0d ERROR(S)", errors);
        $finish;
    end

endmodule
