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
// Title         : TCP Receive Segment Parser
//-----------------------------------------------------------------------------
// File          : tcp_rx_parser_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-09-12
// Last modified : 2026-09-12
//-----------------------------------------------------------------------------
// Description: Drives segments built by tcp_model_pkg into the parser
// under random payload backpressure, and checks the decoded fields,
// the pass/fail verdict and the streamed payload against the model's
// parse_tcp and tcp_payload -- an independent decoder. Good segments
// of every kind and length, hand-built option lists (NOP, MSS, window
// scale, EOL) and single-byte damages that must flip the verdict and
// raise the payload doom are all covered.
//
// Reports tcp_rx_parser_tb: ALL TESTS PASSED or N ERROR(S).

`timescale 1 ns / 100 ps

module tcp_rx_parser_tb;
    import tcp_model_pkg::*;

    logic        clock;
    logic        sreset;

    logic [7:0]  s_tdata;
    logic        s_tuser, s_tvalid, s_tlast, s_tready;
    logic [31:0] s_src_ip, s_dst_ip;
    logic [15:0] s_length;

    logic [7:0]  pl_tdata;
    logic        pl_tvalid, pl_tlast, pl_tuser, pl_tready;

    logic [15:0] src_port, dst_port, window, urgent, mss, payload_len;
    logic [31:0] seq_num, ack_num;
    logic [7:0]  flags;
    logic        hdr_valid, seg_done, seg_ok;

    integer errors = 0;
    integer checks = 0;

    // Capture, shared with monitors
    logic       cap_en;
    logic [7:0] plbuf [0:2047];
    integer     pln;
    logic       pl_doom;             // tuser seen on the last payload beat
    logic       done_seen;
    logic       ok_seen;

    //----------------------------------------------------------------
    // DUT
    //----------------------------------------------------------------
    tcp_rx_parser tcp_rx_parser_inst (
        .clock (clock), .sreset (sreset),
        .s_axi_tdata (s_tdata), .s_axi_tuser (s_tuser), .s_axi_tvalid (s_tvalid),
        .s_axi_tlast (s_tlast), .s_axi_tready (s_tready),
        .s_src_ip (s_src_ip), .s_dst_ip (s_dst_ip), .s_length (s_length),
        .m_pl_tdata (pl_tdata), .m_pl_tvalid (pl_tvalid), .m_pl_tlast (pl_tlast),
        .m_pl_tuser (pl_tuser), .m_pl_tready (pl_tready),
        .src_port (src_port), .dst_port (dst_port), .seq_num (seq_num), .ack_num (ack_num),
        .flags (flags), .window (window), .urgent (urgent), .mss (mss), .payload_len (payload_len),
        .hdr_valid (hdr_valid), .seg_done (seg_done), .seg_ok (seg_ok)
    );

    initial clock = 0;
    always #10 clock = !clock;

    // Registered payload ready and the capture monitor, both off the edge
    always_ff @(posedge clock) begin
        if (sreset || !cap_en) pl_tready <= 1'b0;
        else                   pl_tready <= ($urandom_range(0, 2) != 0);
    end

    always @(posedge clock) begin
        if (!sreset && cap_en) begin
            if (pl_tvalid && pl_tready) begin
                plbuf[pln] = pl_tdata;
                pln        = pln + 1;
                if (pl_tlast) pl_doom = pl_tuser;
            end
            if (seg_done) begin
                done_seen = 1'b1;
                ok_seen   = seg_ok;
            end
        end
    end

    task automatic check(input bit ok, input string what);
        checks = checks + 1;
        if (!ok) begin errors = errors + 1; $error("%s", what); end
    endtask

    //----------------------------------------------------------------
    // Drive one segment's bytes, ready-gated, side-bands on the first
    //----------------------------------------------------------------
    task automatic drive(input bytes_t seg, input logic [31:0] sip, input logic [31:0] dip,
                         input int corrupt_at, input logic [7:0] corrupt_xor);
        @(negedge clock);
        cap_en = 1'b1; pln = 0; pl_doom = 1'b0; done_seen = 1'b0; ok_seen = 1'b0;
        for (int i = 0; i < seg.size(); i++) begin
            @(negedge clock);
            s_tvalid = 1'b1;
            s_tdata  = (i == corrupt_at) ? (seg[i] ^ corrupt_xor) : seg[i];
            s_tlast  = (i == seg.size() - 1);
            s_tuser  = 1'b0;
            s_src_ip = sip; s_dst_ip = dip; s_length = 16'(seg.size());
            // Hold until the beat is taken
            @(posedge clock);
            while (!s_tready) @(posedge clock);
        end
        @(negedge clock);
        s_tvalid = 1'b0; s_tlast = 1'b0;
        // Let the final beat's seg_done register in the monitor
        @(posedge clock);
        @(negedge clock);
        cap_en = 1'b0;
    endtask

    //----------------------------------------------------------------
    // A good segment: fields, verdict and payload must match the model
    //----------------------------------------------------------------
    task automatic run_good(input string name, input tcp_hdr_t h, input bytes_t payload);
        bytes_t   seg = build_tcp(h, payload);
        bytes_t   cap;
        tcp_hdr_t mp;
        string    err;
        bit       mok;

        drive(seg, h.src_ip, h.dst_ip, -1, 8'h00);
        mp = '0;
        parse_tcp(h.src_ip, h.dst_ip, seg, mp, err, mok);

        check(done_seen, {name, ": seg_done fired"});
        check(ok_seen == mok, $sformatf("%s: seg_ok %0d vs model %0d (%s)", name, ok_seen, mok, err));
        check(src_port == mp.src_port && dst_port == mp.dst_port
              && seq_num == mp.seq && ack_num == mp.ack && flags == mp.flags
              && window == mp.window && mss == mp.mss,
              $sformatf("%s: fields differ (mss %0d vs %0d)", name, mss, mp.mss));
        check(payload_len == 16'(payload.size()), $sformatf("%s: payload_len %0d vs %0d", name, payload_len, payload.size()));
        cap = new[pln];
        for (int i = 0; i < pln; i++) cap[i] = plbuf[i];
        check(bytes_eq(cap, payload), {name, ": payload differs"});
        check(!pl_doom, {name, ": payload wrongly doomed"});
    endtask

    //----------------------------------------------------------------
    // A damaged segment: the verdict must be false and, if it has a
    // payload, the last payload beat must carry the doom
    //----------------------------------------------------------------
    task automatic run_bad(input string name, input tcp_hdr_t h, input bytes_t payload,
                           input int at, input logic [7:0] xr);
        bytes_t seg = build_tcp(h, payload);
        drive(seg, h.src_ip, h.dst_ip, at, xr);
        check(done_seen, {name, ": seg_done fired"});
        check(!ok_seen, {name, ": seg_ok should be false"});
        if (payload.size() > 0)
            check(pl_doom, {name, ": last payload beat should be doomed"});
    endtask

    function automatic tcp_hdr_t mkh(input logic [7:0] fl, input logic [15:0] m);
        tcp_hdr_t h = '0;
        h.src_ip   = 32'hc0a85a01;
        h.dst_ip   = 32'hc0a85a2a;
        h.src_port = 16'd51234;
        h.dst_port = 16'd23;
        h.seq      = 32'h1A2B3C4D;
        h.ack      = 32'h00001001;
        h.flags    = fl;
        h.window   = 16'd64240;
        h.urgent   = 16'h0000;
        h.mss      = m;
        return h;
    endfunction

    //----------------------------------------------------------------
    // Test sequence
    //----------------------------------------------------------------
    tcp_hdr_t h;
    bytes_t   seg;
    bytes_t   cap;
    tcp_hdr_t mp;
    string    err;
    bit       mok;
    logic [15:0] csum_tmp;
    bytes_t   s2;
    integer   rn;
    bytes_t   rpl;

    initial begin
        sreset = 1'b1;
        s_tvalid = 1'b0; s_tlast = 1'b0; s_tuser = 1'b0;
        s_tdata = 8'h00; s_src_ip = 32'h0; s_dst_ip = 32'h0; s_length = 16'h0;
        cap_en = 1'b0; pln = 0; pl_doom = 1'b0; done_seen = 1'b0; ok_seen = 1'b0;
        repeat (4) @(negedge clock);
        sreset = 1'b0;

        // Good, of each kind
        run_good("syn",      mkh(F_SYN,        16'd1460), bytes_new(0));
        run_good("pure_ack", mkh(F_ACK,        16'h0),    bytes_new(0));
        run_good("fin",      mkh(F_FIN|F_ACK,  16'h0),    bytes_new(0));
        run_good("data1",    mkh(F_PSH|F_ACK,  16'h0),    bytes_from_hex("aa"));
        run_good("data5",    mkh(F_PSH|F_ACK,  16'h0),    bytes_from_hex("0102030405"));
        run_good("data_mss", mkh(F_PSH|F_ACK,  16'h0),    bytes_pattern(1460, 8'h40));

        // Hand-built option list: NOP NOP MSS(1460) WS(3,3,7) EOL, then payload
        h = mkh(F_SYN|F_ACK, 16'h0);
        seg = build_tcp(h, bytes_new(0));
        seg = bytes_cat(seg, bytes_from_hex("0101020405b4030307000000"));
        seg[12] = 8'h80;                         // data offset 8, 12 option bytes
        seg[16] = 8'h00; seg[17] = 8'h00;
        csum_tmp = tcp_checksum(h.src_ip, h.dst_ip, seg); seg[16] = csum_tmp[15:8]; seg[17] = csum_tmp[7:0];
        drive(seg, h.src_ip, h.dst_ip, -1, 8'h00);
        parse_tcp(h.src_ip, h.dst_ip, seg, mp, err, mok);
        check(done_seen && ok_seen == mok, "opt list: verdict matches model");
        check(mss == 16'd1460, $sformatf("opt list: MSS behind two NOPs got %0d", mss));

        // A data offset below 5: the header does not fit, so the
        // segment is dropped whatever its checksum
        h = mkh(F_PSH|F_ACK, 16'h0);
        seg = build_tcp(h, bytes_from_hex("aabbccdd"));  // 24-byte segment
        seg[12] = 8'h40;                                  // data offset 4 (16 bytes)
        seg[16] = 8'h00; seg[17] = 8'h00;
        csum_tmp = tcp_checksum(h.src_ip, h.dst_ip, seg); seg[16] = csum_tmp[15:8]; seg[17] = csum_tmp[7:0];
        drive(seg, h.src_ip, h.dst_ip, -1, 8'h00);
        parse_tcp(h.src_ip, h.dst_ip, seg, mp, err, mok);
        check(!mok, "doff 4: model rejects it");
        check(done_seen && !ok_seen, "doff 4: parser rejects it");

        // Damaged: each must fail and doom the payload
        run_bad("bad_ipck_na",  mkh(F_PSH|F_ACK, 16'h0), bytes_from_hex("11223344"), 4,  8'h01); // seq byte, breaks checksum
        run_bad("bad_payload",  mkh(F_PSH|F_ACK, 16'h0), bytes_from_hex("11223344"), 22, 8'h01); // a payload byte
        run_bad("bad_checksum", mkh(F_PSH|F_ACK, 16'h0), bytes_from_hex("11223344"), 16, 8'hff); // the checksum field

        // tuser on a beat must fail the segment
        begin
            s2 = build_tcp(mkh(F_PSH|F_ACK, 16'h0), bytes_from_hex("11223344"));
            @(negedge clock);
            cap_en = 1'b1; pln = 0; pl_doom = 1'b0; done_seen = 1'b0; ok_seen = 1'b0;
            for (int i = 0; i < s2.size(); i++) begin
                @(negedge clock);
                s_tvalid = 1'b1; s_tdata = s2[i]; s_tlast = (i == s2.size()-1);
                s_tuser  = (i == 2);   // a tuser mid-segment
                s_src_ip = 32'hc0a85a01; s_dst_ip = 32'hc0a85a2a; s_length = 16'(s2.size());
                @(posedge clock);
                while (!s_tready) @(posedge clock);
            end
            @(negedge clock); s_tvalid = 1'b0; s_tuser = 1'b0;
            @(posedge clock); @(negedge clock); cap_en = 1'b0;
            check(done_seen && !ok_seen, "tuser mid-segment fails the segment");
        end

        // Random good data segments of varied length
        for (int i = 0; i < 200; i++) begin
            rn = ($urandom_range(0,4)==0) ? 0 : $urandom_range(1, 120);
            rpl = new[rn];
            for (int k = 0; k < rn; k++) rpl[k] = 8'($urandom());
            h = mkh(8'($urandom()) | F_ACK, ($urandom_range(0,3)==0) ? 16'd1460 : 16'h0);
            h.seq = $urandom(); h.ack = $urandom(); h.window = 16'($urandom());
            run_good($sformatf("rand%0d", i), h, rpl);
        end

        $display("tcp_rx_parser_tb: %0d checks", checks);
        if (errors == 0) $display("tcp_rx_parser_tb: ALL TESTS PASSED");
        else             $display("tcp_rx_parser_tb: %0d ERROR(S)", errors);
        $finish;
    end

    initial begin
        #50000000;
        errors = errors + 1;
        $error("watchdog: %0d checks", checks);
        $display("tcp_rx_parser_tb: %0d ERROR(S)", errors);
        $finish;
    end

endmodule
