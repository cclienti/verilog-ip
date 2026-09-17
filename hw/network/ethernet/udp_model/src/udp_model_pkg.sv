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
// Title         : UDP Model Package
//-----------------------------------------------------------------------------
// File          : udp_model_pkg.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-09-14
// Last modified : 2026-09-14
//-----------------------------------------------------------------------------
// Description: Bench-side model of UDP over IPv4 over Ethernet, byte
// exact, for the testbenches of the UDP socket and of the endpoint
// around it. Pure functions on dynamic byte arrays: build a datagram,
// an IPv4 packet or a whole Ethernet frame from a header record and a
// payload, both checksums included; parse and validate one back.
//
// Self-contained on purpose, sharing no compiled dependency with
// tcp_model_pkg even though the two duplicate a handful of generic
// helpers (the byte-string utilities, the ones'-complement arithmetic,
// the IPv4 header checksum, the Ethernet/IPv4 builders and parser):
// a bench for a UDP-only endpoint should not need to compile TCP's
// model to get IPv4 support, and the duplication is a few dozen lines
// against the wrong-dependency risk of coupling two protocol models
// that otherwise share nothing.
//
// Everything here is written from the RFCs (768, 791, 1071) and shares
// no expression with the RTL: the checksums are taken over the bytes
// of the finished header, not over the fields the RTL sums. The
// self-check bench anchors the builders to vectors produced by an
// independent Python implementation. Not synthesizable, and not meant
// to be.

`timescale 1 ns / 100 ps

package udp_model_pkg;

    //-------------------------------------------
    // Types and constants
    //-------------------------------------------
    typedef logic [7:0] bytes_t[];  // a byte string, dynamic

    localparam int ETH_HDR_LEN = 14;
    localparam int IP_HDR_LEN  = 20;
    localparam int UDP_HDR_LEN = 8;

    localparam logic [15:0] ETHERTYPE_IPV4 = 16'h0800;
    localparam logic [7:0]  IP_PROTO_UDP   = 8'd17;

    // Every header field of a datagram and of the two headers around
    // it. Packed, so it crosses function boundaries in every
    // simulator. no_checksum is a build-side request ("send checksum
    // field 0, RFC 768's 'no checksum'"); parse_udp reports back
    // through it whether the datagram it read had one.
    typedef struct packed {
        logic [47:0] dst_mac;
        logic [47:0] src_mac;
        logic [15:0] ip_id;
        logic        df;        // IP don't-fragment flag
        logic [7:0]  ttl;
        logic [31:0] src_ip;
        logic [31:0] dst_ip;
        logic [15:0] src_port;
        logic [15:0] dst_port;
        logic        no_checksum;
    } udp_hdr_t;

    //-------------------------------------------
    // Byte string helpers
    //-------------------------------------------
    function automatic bytes_t bytes_new(input int n);
        bytes_t r = new[n];
        for (int i = 0; i < n; i++) r[i] = 8'h00;
        return r;
    endfunction

    function automatic bytes_t bytes_cat(input bytes_t a, input bytes_t b);
        bytes_t r = new[a.size() + b.size()];
        for (int i = 0; i < a.size(); i++) r[i] = a[i];
        for (int i = 0; i < b.size(); i++) r[a.size() + i] = b[i];
        return r;
    endfunction

    // a[start +: len], clipped to the array
    function automatic bytes_t bytes_slice(input bytes_t a, input int start, input int len);
        int n = (start >= a.size()) ? 0 : ((start + len > a.size()) ? a.size() - start : len);
        bytes_t r = new[n < 0 ? 0 : n];
        for (int i = 0; i < r.size(); i++) r[i] = a[start + i];
        return r;
    endfunction

    function automatic bit bytes_eq(input bytes_t a, input bytes_t b);
        if (a.size() != b.size()) return 1'b0;
        for (int i = 0; i < a.size(); i++) if (a[i] !== b[i]) return 1'b0;
        return 1'b1;
    endfunction

    function automatic string bytes_hex(input bytes_t a);
        string s = "";
        for (int i = 0; i < a.size(); i++) s = {s, $sformatf("%02x", a[i])};
        return s;
    endfunction

    // Two hex digits per byte, no separators; anything else is an error
    // the caller sees as an empty result. No early return inside the
    // loop and no bytes_new call in the body: Icarus corrupts a dynamic
    // array returned from within nested control, so validity is a flag
    // and the size is fixed once, up front. Character codes, not
    // "0".."f" literals, which Icarus compares the wrong way.
    function automatic bytes_t bytes_from_hex(input string s);
        bytes_t r;
        bit     bad = 1'b0;
        int     n = (s.len() % 2 != 0) ? 0 : s.len() / 2;
        r = new[n];
        for (int i = 0; i < n; i++) begin
            int v = 0;
            for (int k = 0; k < 2; k++) begin
                int c = int'(s[2*i + k]);
                int d = (c >= 48 && c <= 57)  ? c - 48 :
                        (c >= 97 && c <= 102) ? c - 87 :
                        (c >= 65 && c <= 70)  ? c - 55 : -1;
                if (d < 0) bad = 1'b1;
                else       v = v * 16 + d;
            end
            r[i] = 8'(v);
        end
        if (bad) r = new[0];
        return r;
    endfunction

    // A payload of n bytes, base + i, for benches
    function automatic bytes_t bytes_pattern(input int n, input logic [7:0] base);
        bytes_t r = new[n];
        for (int i = 0; i < n; i++) r[i] = 8'(base + i);
        return r;
    endfunction

    //-------------------------------------------
    // Ones'-complement arithmetic, RFC 1071
    //-------------------------------------------
    // Sum of the 16-bit big-endian words of a[start +: len] added to
    // init, an odd trailing byte padded with zero on its right
    function automatic logic [31:0] ones_sum(input bytes_t a, input int start, input int len,
                                             input logic [31:0] init);
        logic [31:0] s = init;
        for (int i = 0; i < len; i += 2) begin
            logic [7:0] hi = a[start + i];
            logic [7:0] lo = (i + 1 < len) ? a[start + i + 1] : 8'h00;
            s = s + {16'h0000, hi, lo};
        end
        return s;
    endfunction

    // Fold the carries and complement: the value to put in a checksum
    // field computed with that field at zero
    function automatic logic [15:0] csum_fold(input logic [31:0] sum);
        logic [31:0] s = sum;
        while (s[31:16] != 16'h0000) s = {16'h0000, s[15:0]} + {16'h0000, s[31:16]};
        return ~s[15:0];
    endfunction

    // A header whose checksum field is in place verifies iff its
    // folded sum is all ones
    function automatic bit csum_verifies(input logic [31:0] sum);
        return csum_fold(sum) == 16'h0000;
    endfunction

    // IPv4 header checksum over the 20 bytes at off, the field as found
    function automatic logic [15:0] ip_checksum(input bytes_t a, input int off);
        return csum_fold(ones_sum(a, off, IP_HDR_LEN, 32'h0));
    endfunction

    // UDP checksum over the pseudo-header and the whole datagram, the
    // field as found
    function automatic logic [15:0] udp_checksum(input logic [31:0] src_ip, input logic [31:0] dst_ip,
                                                 input bytes_t dgram);
        logic [31:0] s;
        s = {16'h0000, src_ip[31:16]} + {16'h0000, src_ip[15:0]}
          + {16'h0000, dst_ip[31:16]} + {16'h0000, dst_ip[15:0]}
          + {24'h000000, IP_PROTO_UDP} + 32'(dgram.size());
        return csum_fold(ones_sum(dgram, 0, dgram.size(), s));
    endfunction

    //-------------------------------------------
    // Builders
    //-------------------------------------------
    // The L4 unit: UDP header, payload, checksum in place, unless
    // h.no_checksum asks for RFC 768's "no checksum" (field left at
    // zero). A computed checksum of zero is sent as all ones, the
    // one case that value cannot mean "verified" on the wire. What
    // the IPv4 parser delivers to the socket.
    function automatic bytes_t build_udp(input udp_hdr_t h, input bytes_t payload);
        bytes_t      dgram = bytes_new(UDP_HDR_LEN + payload.size());
        logic [15:0] len   = 16'(UDP_HDR_LEN + payload.size());
        logic [15:0] csum;
        dgram[0] = h.src_port[15:8];
        dgram[1] = h.src_port[7:0];
        dgram[2] = h.dst_port[15:8];
        dgram[3] = h.dst_port[7:0];
        dgram[4] = len[15:8];
        dgram[5] = len[7:0];
        dgram[6] = 8'h00;
        dgram[7] = 8'h00;
        for (int i = 0; i < payload.size(); i++) dgram[UDP_HDR_LEN + i] = payload[i];
        if (!h.no_checksum) begin
            csum = udp_checksum(h.src_ip, h.dst_ip, dgram);
            if (csum == 16'h0000) csum = 16'hFFFF;
            dgram[6] = csum[15:8];
            dgram[7] = csum[7:0];
        end
        return dgram;
    endfunction

    // IPv4 header in front of an L4 unit, checksum in place
    function automatic bytes_t build_ipv4(input udp_hdr_t h, input bytes_t l4);
        bytes_t      pkt = bytes_new(IP_HDR_LEN + l4.size());
        logic [15:0] total = 16'(IP_HDR_LEN + l4.size());
        logic [15:0] csum;
        pkt[0] = 8'h45;
        pkt[1] = 8'h00;
        pkt[2] = total[15:8];
        pkt[3] = total[7:0];
        pkt[4] = h.ip_id[15:8];
        pkt[5] = h.ip_id[7:0];
        pkt[6] = {1'b0, h.df, 1'b0, 5'd0};
        pkt[7] = 8'h00;
        pkt[8] = h.ttl;
        pkt[9] = IP_PROTO_UDP;
        pkt[10] = 8'h00;
        pkt[11] = 8'h00;
        pkt[12] = h.src_ip[31:24];
        pkt[13] = h.src_ip[23:16];
        pkt[14] = h.src_ip[15:8];
        pkt[15] = h.src_ip[7:0];
        pkt[16] = h.dst_ip[31:24];
        pkt[17] = h.dst_ip[23:16];
        pkt[18] = h.dst_ip[15:8];
        pkt[19] = h.dst_ip[7:0];
        csum = ip_checksum(pkt, 0);
        pkt[10] = csum[15:8];
        pkt[11] = csum[7:0];
        for (int i = 0; i < l4.size(); i++) pkt[IP_HDR_LEN + i] = l4[i];
        return pkt;
    endfunction

    // Ethernet header in front of an IPv4 packet, no FCS: what the
    // socket emits and what the FCS generator takes
    function automatic bytes_t build_eth(input udp_hdr_t h, input bytes_t ip);
        bytes_t f = bytes_new(ETH_HDR_LEN + ip.size());
        f[0] = h.dst_mac[47:40];
        f[1] = h.dst_mac[39:32];
        f[2] = h.dst_mac[31:24];
        f[3] = h.dst_mac[23:16];
        f[4] = h.dst_mac[15:8];
        f[5] = h.dst_mac[7:0];
        f[6] = h.src_mac[47:40];
        f[7] = h.src_mac[39:32];
        f[8] = h.src_mac[31:24];
        f[9] = h.src_mac[23:16];
        f[10] = h.src_mac[15:8];
        f[11] = h.src_mac[7:0];
        f[12] = ETHERTYPE_IPV4[15:8];
        f[13] = ETHERTYPE_IPV4[7:0];
        for (int i = 0; i < ip.size(); i++) f[ETH_HDR_LEN + i] = ip[i];
        return f;
    endfunction

    function automatic bytes_t build_frame(input udp_hdr_t h, input bytes_t payload);
        return build_eth(h, build_ipv4(h, build_udp(h, payload)));
    endfunction

    //-------------------------------------------
    // Parsers: fill the record, verify, set ok on a valid input and
    // an explanation in err otherwise. Tasks rather than functions:
    // Icarus takes only input ports on a function.
    //-------------------------------------------
    // An L4 unit with the pseudo-header addresses supplied beside it,
    // the socket's own input; only the UDP fields of h are written.
    // The length field must equal the unit's own size exactly: the
    // IPv4 layer has already cut it there, so a real stack's length
    // field is always redundant with it, and this is the same
    // validation the socket's RTL applies.
    task automatic parse_udp(input logic [31:0] src_ip, input logic [31:0] dst_ip,
                             input bytes_t dgram, inout udp_hdr_t h, output string err, output bit ok);
        logic [15:0] len;
        logic [15:0] csum_field;
        err = "";
        ok  = 1'b0;
        if (dgram.size() < UDP_HDR_LEN) begin err = "shorter than a UDP header"; return; end
        len = {dgram[4], dgram[5]};
        if (int'(len) != dgram.size()) begin err = "length field"; return; end
        csum_field = {dgram[6], dgram[7]};
        if (csum_field != 16'h0000) begin
            if (!csum_verifies(
                    {16'h0000, src_ip[31:16]} + {16'h0000, src_ip[15:0]}
                  + {16'h0000, dst_ip[31:16]} + {16'h0000, dst_ip[15:0]}
                  + {24'h000000, IP_PROTO_UDP} + 32'(dgram.size())
                  + ones_sum(dgram, 0, dgram.size(), 32'h0))) begin
                err = "UDP checksum"; return;
            end
        end
        begin
            logic [15:0] l_src_port = {dgram[0], dgram[1]};
            logic [15:0] l_dst_port = {dgram[2], dgram[3]};
            h.src_ip      = src_ip;
            h.dst_ip      = dst_ip;
            h.src_port    = l_src_port;
            h.dst_port    = l_dst_port;
            h.no_checksum = (csum_field == 16'h0000);
        end
        ok = 1'b1;
    endtask

    // The L4 payload of a datagram that parse_udp accepted
    function automatic bytes_t udp_payload(input bytes_t dgram);
        return bytes_slice(dgram, UDP_HDR_LEN, dgram.size() - UDP_HDR_LEN);
    endfunction

    // A whole Ethernet frame without FCS, padding beyond total_length
    // tolerated and ignored, the way the receive chain treats it
    task automatic parse_frame(input bytes_t f, output udp_hdr_t h, output string err, output bit ok);
        int         total;
        bytes_t     dgram;
        logic [7:0] b20;
        h   = '0;
        err = "";
        ok  = 1'b0;
        if (f.size() < ETH_HDR_LEN + IP_HDR_LEN + UDP_HDR_LEN) begin
            err = "shorter than the three headers"; return;
        end
        if ({f[12], f[13]} != ETHERTYPE_IPV4) begin err = "EtherType"; return; end
        if (f[14] != 8'h45) begin err = "IP version/IHL"; return; end
        total = int'({f[16], f[17]});
        if (total < IP_HDR_LEN + UDP_HDR_LEN) begin err = "total length too small"; return; end
        if (total > f.size() - ETH_HDR_LEN) begin err = "total length past the frame"; return; end
        b20 = f[20];
        if (b20[5] || {b20[4:0], f[21]} != 13'd0) begin err = "fragment"; return; end
        if (f[23] != IP_PROTO_UDP) begin err = "IP protocol"; return; end
        if (!csum_verifies(ones_sum(f, ETH_HDR_LEN, IP_HDR_LEN, 32'h0))) begin
            err = "IP checksum"; return;
        end
        begin
            logic [47:0] l_dst_mac = {f[0], f[1], f[2], f[3], f[4], f[5]};
            logic [47:0] l_src_mac = {f[6], f[7], f[8], f[9], f[10], f[11]};
            logic [15:0] l_ip_id   = {f[18], f[19]};
            logic [31:0] l_src_ip  = {f[26], f[27], f[28], f[29]};
            logic [31:0] l_dst_ip  = {f[30], f[31], f[32], f[33]};
            h.dst_mac = l_dst_mac;
            h.src_mac = l_src_mac;
            h.ip_id   = l_ip_id;
            h.df      = b20[6];
            h.ttl     = f[22];
            dgram = bytes_slice(f, ETH_HDR_LEN + IP_HDR_LEN, total - IP_HDR_LEN);
            parse_udp(l_src_ip, l_dst_ip, dgram, h, err, ok);
        end
    endtask

    // The L4 unit of a frame, header and payload, for driving a
    // socket input from a frame
    function automatic bytes_t frame_l4(input bytes_t f);
        int total = int'({f[16], f[17]});
        return bytes_slice(f, ETH_HDR_LEN + IP_HDR_LEN, total - IP_HDR_LEN);
    endfunction

    // The L4 payload of a frame that parse_frame accepted
    function automatic bytes_t frame_payload(input bytes_t f);
        return udp_payload(frame_l4(f));
    endfunction

    //-------------------------------------------
    // Text
    //-------------------------------------------
    function automatic string hdr_str(input udp_hdr_t h);
        return $sformatf("%0d.%0d.%0d.%0d:%0d > %0d.%0d.%0d.%0d:%0d%s",
                         h.src_ip[31:24], h.src_ip[23:16], h.src_ip[15:8], h.src_ip[7:0], h.src_port,
                         h.dst_ip[31:24], h.dst_ip[23:16], h.dst_ip[15:8], h.dst_ip[7:0], h.dst_port,
                         h.no_checksum ? " (no checksum)" : "");
    endfunction

endpackage
