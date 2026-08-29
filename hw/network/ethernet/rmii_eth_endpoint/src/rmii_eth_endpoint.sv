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
// Title         : RMII Ethernet Endpoint
//-----------------------------------------------------------------------------
// File          : rmii_eth_endpoint.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-29
// Last modified : 2026-08-29
//-----------------------------------------------------------------------------
// Description: This module closes the loop on the whole Fast Ethernet
// stack: an ARP/ICMP endpoint between the RMII pins of a PHY, one
// 50 MHz clock domain. It answers ARP requests and ICMP echo requests
// for local_ip and consumes everything else silently.
//
// Receive: the RMII MAC strips preamble/SFD, the upsizer folds dibits
// into bytes ({4{tuser}} and tkeep glued down to the checker's single
// bit, an incomplete last byte folded in as an error), the FCS checker
// flags bad frames with tuser on their last beat, and the packet FIFO
// in DROP_ON_FULL mode absorbs them -- behind it only complete valid
// frames exist, with their length on the first beat, which is what the
// parsers' drop convention requires. The eth parser then steers the
// packet demux (IPv4 on output 0, ARP on output 1, everything else at
// the discard code), and the IPv4 parser repeats the pattern one layer
// up into the ICMP echo responder.
//
// Transmit: the packet mux merges the two responders' complete
// Ethernet reply frames, the FCS generator pads to the minimum frame
// and appends the CRC, the downsizer unfolds bytes to dibits
// (replicating the single tuser bit), and the RMII MAC adds
// preamble/SFD and the inter-frame gap.
//
// While a responder drains a reply the receive chain behind the FIFO
// stalls (head-of-line, documented in each responder); the FIFO's
// slack absorbs it and DROP_ON_FULL sheds the excess instead of
// stalling the MAC, which cannot pause the wire. local_mac/local_ip
// are sampled per frame inside the protocol blocks, so they may be
// tied to constants or driven at run time. The eth parser's
// promiscuous mode and multicast accept are left off: this endpoint
// only ever answers frames addressed to it or broadcast.

`timescale 1 ns / 100 ps

module rmii_eth_endpoint #(
    parameter int LOG2_FIFO_DEPTH = 11, // receive packet FIFO in bytes, log2
    parameter int LOG2_ICMP_DEPTH = 11  // ICMP payload buffer in bytes, log2
)(
    input logic         clock,  // 50 MHz RMII reference clock
    input logic         sreset,

    // Endpoint identity, sampled per frame by the protocol blocks
    input logic [47:0]  local_mac,
    input logic [31:0]  local_ip,

    // RMII PHY pins
    input logic [1:0]   phy_rxd,
    input logic         phy_crs_dv,
    output logic [1:0]  phy_txd,
    output logic        phy_txen,

    // Sender mapping of every valid ARP packet, one-cycle pulse
    output logic        learn_valid,
    output logic [47:0] learn_mac,
    output logic [31:0] learn_ip
);

    // FIFO m_length port width, the eth parser length side-band
    localparam int LENGTH_W = LOG2_FIFO_DEPTH + 1;

    //-------------------------------------------
    // Receive MAC: preamble/SFD stripped dibits
    //-------------------------------------------
    logic [1:0]  mrx_tdata;   // received dibit stream
    logic        mrx_tuser;   // MAC error flag
    logic        mrx_tvalid;  // dibit valid
    logic        mrx_tlast;   // last dibit of the frame
    logic        mrx_tready;  // upsizer ready

    rmii_mac_rx rmii_mac_rx_inst
    (
        .clock      (clock),
        .srst       (sreset),
        .rxd        (phy_rxd),
        .rxen       (phy_crs_dv),
        .axi_tvalid (mrx_tvalid),
        .axi_tlast  (mrx_tlast),
        .axi_tdata  (mrx_tdata),
        .axi_tuser  (mrx_tuser),
        .axi_tready (mrx_tready)
    );

    //-------------------------------------------
    // Upsizer: dibits to bytes, low dibit first
    //-------------------------------------------
    logic [7:0]  ups_tdata;   // received byte stream
    logic [3:0]  ups_tuser;   // one error bit per dibit
    logic [3:0]  ups_tkeep;   // filled dibits of the last byte
    logic        ups_tvalid;  // byte valid
    logic        ups_tlast;   // last byte of the frame
    logic        ups_tready;  // checker ready
    logic        ups_err;     // reduced error, incomplete last byte folded in

    axi_stream_upsizer
    #(
        .UPSIZE_RATIO  (4),
        .IN_DATA_WIDTH (2),
        .IN_USER_WIDTH (1)
    )
    axi_stream_upsizer_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (mrx_tdata),
        .s_axi_tuser  (mrx_tuser),
        .s_axi_tvalid (mrx_tvalid),
        .s_axi_tlast  (mrx_tlast),
        .s_axi_tready (mrx_tready),
        .m_axi_tdata  (ups_tdata),
        .m_axi_tuser  (ups_tuser),
        .m_axi_tvalid (ups_tvalid),
        .m_axi_tlast  (ups_tlast),
        .m_axi_tkeep  (ups_tkeep),
        .m_axi_tready (ups_tready)
    );

    // Seam glue documented in the chain README: reduce the per-dibit
    // error bits and flag a frame whose last byte is incomplete
    assign ups_err = |ups_tuser || (ups_tlast && ups_tkeep != '1);

    //-------------------------------------------
    // FCS check, then the drop FIFO: only whole
    // valid frames reach the protocol layer
    //-------------------------------------------
    logic [7:0]          chk_tdata;   // FCS-stripped byte stream
    logic                chk_tuser;   // bad-FCS flag on the last beat
    logic                chk_tvalid;  // byte valid
    logic                chk_tlast;   // last byte of the frame
    logic                chk_tready;  // FIFO ready, never low in DROP_ON_FULL
    logic [7:0]          pf_tdata;    // committed frame byte stream
    logic                pf_tvalid;   // byte valid
    logic                pf_tlast;    // last byte of the frame
    logic                pf_tready;   // eth parser ready
    logic                pf_info;     // unused side-band word
    logic [LENGTH_W-1:0] pf_length;   // frame length, first beat onward

    axi_stream_eth_fcs_check axi_stream_eth_fcs_check_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (ups_tdata),
        .s_axi_tuser  (ups_err),
        .s_axi_tvalid (ups_tvalid),
        .s_axi_tlast  (ups_tlast),
        .s_axi_tready (ups_tready),
        .m_axi_tdata  (chk_tdata),
        .m_axi_tuser  (chk_tuser),
        .m_axi_tvalid (chk_tvalid),
        .m_axi_tlast  (chk_tlast),
        .m_axi_tready (chk_tready)
    );

    axi_stream_packet_fifo
    #(
        .DATA_WIDTH   (8),
        .LOG2_DEPTH   (LOG2_FIFO_DEPTH),
        .LOG2_FRAMES  (6),
        .INFO_WIDTH   (1),
        .DROP_ON_FULL (1)
    )
    axi_stream_packet_fifo_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (chk_tdata),
        .s_axi_tuser  (chk_tuser),
        .s_axi_tvalid (chk_tvalid),
        .s_axi_tlast  (chk_tlast),
        .s_axi_tready (chk_tready),
        .s_info       (1'b0),
        .m_axi_tdata  (pf_tdata),
        .m_axi_tvalid (pf_tvalid),
        .m_axi_tlast  (pf_tlast),
        .m_axi_tready (pf_tready),
        .m_info       (pf_info),
        .m_length     (pf_length)
    );

    //-------------------------------------------
    // Eth parser and demux: IPv4 on 0, ARP on 1
    //-------------------------------------------
    logic [7:0]          ethp_tdata;     // eth payload byte stream
    logic                ethp_tuser;     // receive drop flag
    logic                ethp_tvalid;    // byte valid
    logic                ethp_tlast;     // last payload byte
    logic                ethp_tready;    // demux ready
    logic [1:0]          ethp_sel;       // demux select, 2 the discard code
    logic [47:0]         ethp_dst_mac;   // frame destination MAC, unused
    logic [47:0]         ethp_src_mac;   // requester MAC, rides to the ICMP echo
    logic [15:0]         ethp_ethertype; // decoded EtherType, unused
    logic [LENGTH_W-1:0] ethp_length;    // payload length, unused
    logic [15:0]         ethd_tdata;     // demux outputs, IPv4 low byte, ARP high
    logic [1:0]          ethd_tuser;     // per-output drop flags
    logic [1:0]          ethd_tvalid;    // per-output valids
    logic [1:0]          ethd_tlast;     // per-output lasts
    logic [1:0]          ethd_tready;    // per-output readies
    logic                ethd_info;      // unused side-band word

    axi_stream_eth_parser
    #(
        .NB_ETHERTYPES    (2),
        .ETHERTYPES       ({16'h0806, 16'h0800}),
        .LENGTH_WIDTH     (LENGTH_W),
        .ACCEPT_MULTICAST (0)
    )
    axi_stream_eth_parser_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .local_mac    (local_mac),
        .promiscuous  (1'b0),
        .s_axi_tdata  (pf_tdata),
        .s_axi_tuser  (1'b0),
        .s_axi_tvalid (pf_tvalid),
        .s_axi_tlast  (pf_tlast),
        .s_axi_tready (pf_tready),
        .s_length     (pf_length),
        .m_axi_tdata  (ethp_tdata),
        .m_axi_tuser  (ethp_tuser),
        .m_axi_tvalid (ethp_tvalid),
        .m_axi_tlast  (ethp_tlast),
        .m_axi_tready (ethp_tready),
        .m_sel        (ethp_sel),
        .m_dst_mac    (ethp_dst_mac),
        .m_src_mac    (ethp_src_mac),
        .m_ethertype  (ethp_ethertype),
        .m_length     (ethp_length)
    );

    axi_stream_packet_demux
    #(
        .NB_OUTPUTS (2),
        .DATA_WIDTH (8),
        .INFO_WIDTH (1)
    )
    axi_stream_eth_demux_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (ethp_tdata),
        .s_axi_tuser  (ethp_tuser),
        .s_axi_tvalid (ethp_tvalid),
        .s_axi_tlast  (ethp_tlast),
        .s_axi_tready (ethp_tready),
        .s_sel        (ethp_sel),
        .s_info       (1'b0),
        .m_axi_tdata  (ethd_tdata),
        .m_axi_tuser  (ethd_tuser),
        .m_axi_tvalid (ethd_tvalid),
        .m_axi_tlast  (ethd_tlast),
        .m_axi_tready (ethd_tready),
        .m_info       (ethd_info)
    );

    //-------------------------------------------
    // ARP responder on demux output 1
    //-------------------------------------------
    logic [7:0] arp_tdata;   // ARP reply byte stream
    logic       arp_tuser;   // constant zero
    logic       arp_tvalid;  // byte valid
    logic       arp_tlast;   // last reply byte
    logic       arp_tready;  // packet mux grant

    axi_stream_eth_arp axi_stream_eth_arp_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .local_mac    (local_mac),
        .local_ip     (local_ip),
        .s_axi_tdata  (ethd_tdata[15:8]),
        .s_axi_tuser  (ethd_tuser[1]),
        .s_axi_tvalid (ethd_tvalid[1]),
        .s_axi_tlast  (ethd_tlast[1]),
        .s_axi_tready (ethd_tready[1]),
        .m_axi_tdata  (arp_tdata),
        .m_axi_tuser  (arp_tuser),
        .m_axi_tvalid (arp_tvalid),
        .m_axi_tlast  (arp_tlast),
        .m_axi_tready (arp_tready),
        .learn_valid  (learn_valid),
        .learn_mac    (learn_mac),
        .learn_ip     (learn_ip)
    );

    //-------------------------------------------
    // IPv4 parser, demux and the ICMP echo on
    // demux output 0
    //-------------------------------------------
    logic [7:0]  ipp_tdata;     // L4 payload byte stream
    logic        ipp_tuser;     // receive drop flag
    logic        ipp_tvalid;    // byte valid
    logic        ipp_tlast;     // last payload byte
    logic        ipp_tready;    // demux ready
    logic        ipp_sel;       // demux select, 1 the discard code
    logic [31:0] ipp_src_ip;    // requester IP side-band
    logic [31:0] ipp_dst_ip;    // destination IP side-band
    logic [7:0]  ipp_protocol;  // decoded protocol, unused
    logic [15:0] ipp_length;    // L4 payload length side-band
    logic [7:0]  ipd_tdata;     // demux output, the ICMP payload
    logic        ipd_tuser;     // drop flag
    logic        ipd_tvalid;    // byte valid
    logic        ipd_tlast;     // last payload byte
    logic        ipd_tready;    // ICMP echo ready
    logic        ipd_info;      // unused side-band word
    logic [7:0]  icmp_tdata;    // echo reply byte stream
    logic        icmp_tuser;    // constant zero
    logic        icmp_tvalid;   // byte valid
    logic        icmp_tlast;    // last reply byte
    logic        icmp_tready;   // packet mux grant

    axi_stream_ipv4_parser
    #(
        .NB_PROTOCOLS (1),
        .PROTOCOLS    (8'h01)
    )
    axi_stream_ipv4_parser_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .local_ip     (local_ip),
        .s_axi_tdata  (ethd_tdata[7:0]),
        .s_axi_tuser  (ethd_tuser[0]),
        .s_axi_tvalid (ethd_tvalid[0]),
        .s_axi_tlast  (ethd_tlast[0]),
        .s_axi_tready (ethd_tready[0]),
        .m_axi_tdata  (ipp_tdata),
        .m_axi_tuser  (ipp_tuser),
        .m_axi_tvalid (ipp_tvalid),
        .m_axi_tlast  (ipp_tlast),
        .m_axi_tready (ipp_tready),
        .m_sel        (ipp_sel),
        .m_src_ip     (ipp_src_ip),
        .m_dst_ip     (ipp_dst_ip),
        .m_protocol   (ipp_protocol),
        .m_length     (ipp_length)
    );

    axi_stream_packet_demux
    #(
        .NB_OUTPUTS (1),
        .DATA_WIDTH (8),
        .INFO_WIDTH (1)
    )
    axi_stream_ip_demux_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (ipp_tdata),
        .s_axi_tuser  (ipp_tuser),
        .s_axi_tvalid (ipp_tvalid),
        .s_axi_tlast  (ipp_tlast),
        .s_axi_tready (ipp_tready),
        .s_sel        (ipp_sel),
        .s_info       (1'b0),
        .m_axi_tdata  (ipd_tdata),
        .m_axi_tuser  (ipd_tuser),
        .m_axi_tvalid (ipd_tvalid),
        .m_axi_tlast  (ipd_tlast),
        .m_axi_tready (ipd_tready),
        .m_info       (ipd_info)
    );

    // The requester MAC rides from the eth parser around the IPv4
    // layer: the chain is strictly serialized while a frame is in
    // flight, so the side-band cannot change before the sample
    axi_stream_icmp_echo
    #(
        .LOG2_DEPTH (LOG2_ICMP_DEPTH)
    )
    axi_stream_icmp_echo_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .local_mac    (local_mac),
        .local_ip     (local_ip),
        .s_axi_tdata  (ipd_tdata),
        .s_axi_tuser  (ipd_tuser),
        .s_axi_tvalid (ipd_tvalid),
        .s_axi_tlast  (ipd_tlast),
        .s_axi_tready (ipd_tready),
        .s_src_ip     (ipp_src_ip),
        .s_dst_ip     (ipp_dst_ip),
        .s_length     (ipp_length),
        .s_src_mac    (ethp_src_mac),
        .m_axi_tdata  (icmp_tdata),
        .m_axi_tuser  (icmp_tuser),
        .m_axi_tvalid (icmp_tvalid),
        .m_axi_tlast  (icmp_tlast),
        .m_axi_tready (icmp_tready)
    );

    //-------------------------------------------
    // Transmit merge, FCS, downsize, MAC
    //-------------------------------------------
    logic [7:0] mux_tdata;   // merged reply byte stream
    logic       mux_tuser;   // abort flag, forwarded
    logic       mux_tvalid;  // byte valid
    logic       mux_tlast;   // last frame byte
    logic       mux_tready;  // FCS generator ready
    logic       mux_info;    // unused side-band word
    logic [7:0] gen_tdata;   // padded frame with FCS
    logic       gen_tuser;   // abort flag
    logic       gen_tvalid;  // byte valid
    logic       gen_tlast;   // last frame byte
    logic       gen_tready;  // downsizer ready
    logic [1:0] mtx_tdata;   // transmit dibit stream
    logic       mtx_tuser;   // abort flag
    logic       mtx_tvalid;  // dibit valid
    logic       mtx_tlast;   // last dibit of the frame
    logic       mtx_tready;  // MAC consumes one dibit per clock

    axi_stream_packet_mux
    #(
        .NB_INPUTS  (2),
        .DATA_WIDTH (8),
        .INFO_WIDTH (1)
    )
    axi_stream_packet_mux_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  ({icmp_tdata, arp_tdata}),
        .s_axi_tuser  ({icmp_tuser, arp_tuser}),
        .s_axi_tvalid ({icmp_tvalid, arp_tvalid}),
        .s_axi_tlast  ({icmp_tlast, arp_tlast}),
        .s_axi_tready ({icmp_tready, arp_tready}),
        .s_info       (2'b00),
        .m_axi_tdata  (mux_tdata),
        .m_axi_tuser  (mux_tuser),
        .m_axi_tvalid (mux_tvalid),
        .m_axi_tlast  (mux_tlast),
        .m_axi_tready (mux_tready),
        .m_info       (mux_info)
    );

    axi_stream_eth_fcs_gen
    #(
        .MIN_FRAME_BYTES (60)
    )
    axi_stream_eth_fcs_gen_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (mux_tdata),
        .s_axi_tuser  (mux_tuser),
        .s_axi_tvalid (mux_tvalid),
        .s_axi_tlast  (mux_tlast),
        .s_axi_tready (mux_tready),
        .m_axi_tdata  (gen_tdata),
        .m_axi_tuser  (gen_tuser),
        .m_axi_tvalid (gen_tvalid),
        .m_axi_tlast  (gen_tlast),
        .m_axi_tready (gen_tready)
    );

    // Seam glue documented in the chain README: replicate the single
    // abort bit per dibit, whole bytes so tkeep is tied full
    axi_stream_downsizer
    #(
        .DOWNSIZE_RATIO (4),
        .OUT_DATA_WIDTH (2),
        .OUT_USER_WIDTH (1)
    )
    axi_stream_downsizer_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (gen_tdata),
        .s_axi_tuser  ({4{gen_tuser}}),
        .s_axi_tvalid (gen_tvalid),
        .s_axi_tlast  (gen_tlast),
        .s_axi_tkeep  (4'b1111),
        .s_axi_tready (gen_tready),
        .m_axi_tdata  (mtx_tdata),
        .m_axi_tuser  (mtx_tuser),
        .m_axi_tvalid (mtx_tvalid),
        .m_axi_tlast  (mtx_tlast),
        .m_axi_tready (mtx_tready)
    );

    rmii_mac_tx rmii_mac_tx_inst
    (
        .clock      (clock),
        .srst       (sreset),
        .axi_tvalid (mtx_tvalid),
        .axi_tlast  (mtx_tlast),
        .axi_tdata  (mtx_tdata),
        .axi_tuser  (mtx_tuser),
        .axi_tready (mtx_tready),
        .txd        (phy_txd),
        .txen       (phy_txen)
    );

endmodule
