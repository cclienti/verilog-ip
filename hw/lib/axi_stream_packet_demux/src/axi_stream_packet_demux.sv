//-----------------------------------------------------------------------------
// Title         : AXI Stream Packet Demux
//-----------------------------------------------------------------------------
// File          : axi_stream_packet_demux.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-25
// Last modified : 2026-08-25
//-----------------------------------------------------------------------------
// Description: Frame-atomic route of one AXI stream to one of NB_OUTPUTS
// streams. The route comes from the s_sel side-band, which the upstream
// parser presents with the first beat of the frame (an EtherType or
// protocol field it has already decoded); the demux samples it there
// and holds it to tlast, so a select that moves mid-frame cannot split
// a frame across outputs. A select value of NB_OUTPUTS or more discards
// the frame: it is consumed at full rate and no output sees a beat --
// the unknown-EtherType branch comes for free.
//
// Per-output buses are packed: output i owns bit slice [i*W +: W]. The
// INFO_WIDTH side-band passes through on the shared m_info bus, valid
// for whichever output is receiving the frame, following the
// stable-for-the-whole-frame convention of the packet FIFO and mux.
//-----------------------------------------------------------------------------
// Copyright (c) 2026 by Christophe Clienti. This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module axi_stream_packet_demux #(
    parameter int NB_OUTPUTS = 3,
    parameter int DATA_WIDTH = 8,
    parameter int INFO_WIDTH = 1,
    // Wide enough to hold NB_OUTPUTS itself, the discard code
    localparam int SEL_W = $clog2(NB_OUTPUTS + 1)
)(
    input logic                              clock,
    input logic                              sreset,

    // AXI Stream input; s_sel routes the frame, values >= NB_OUTPUTS
    // discard it, both sampled on the first beat
    input logic [DATA_WIDTH-1:0]             s_axi_tdata,
    input logic                              s_axi_tuser,
    input logic                              s_axi_tvalid,
    input logic                              s_axi_tlast,
    output logic                             s_axi_tready,
    input logic [SEL_W-1:0]                  s_sel,
    input logic [INFO_WIDTH-1:0]             s_info,

    // AXI Stream outputs, output i on bit slice [i*W +: W]
    output logic [NB_OUTPUTS*DATA_WIDTH-1:0] m_axi_tdata,
    output logic [NB_OUTPUTS-1:0]            m_axi_tuser,
    output logic [NB_OUTPUTS-1:0]            m_axi_tvalid,
    output logic [NB_OUTPUTS-1:0]            m_axi_tlast,
    input logic [NB_OUTPUTS-1:0]             m_axi_tready,
    output logic [INFO_WIDTH-1:0]            m_info
);

    logic             in_frame;
    logic [SEL_W-1:0] sel_q;
    logic [SEL_W-1:0] cur_sel;
    logic             discard;
    logic             s_accept;

    // First beat routes on the live select and latches it; the rest of
    // the frame follows the latch
    assign cur_sel = in_frame ? sel_q : s_sel;
    assign discard = 32'(cur_sel) >= NB_OUTPUTS;

    // A discarded frame is consumed at full rate; a routed one follows
    // its output's ready. Every routable cur_sel matches one branch.
    always_comb begin
        s_axi_tready = discard;
        for (int i = 0; i < NB_OUTPUTS; i++) begin
            if (32'(cur_sel) == i) begin
                s_axi_tready = m_axi_tready[i];
            end
        end
    end

    assign s_accept = s_axi_tvalid && s_axi_tready;

    always_ff @(posedge clock) begin
        if (sreset) begin
            in_frame <= 1'b0;
            sel_q    <= '0;
        end
        else if (s_accept) begin
            if (s_axi_tlast) begin
                in_frame <= 1'b0;
            end
            else if (!in_frame) begin
                in_frame <= 1'b1;
                sel_q    <= s_sel;
            end
        end
    end

    //-------------------------------------------
    // Broadcast the payload, gate the valids
    //-------------------------------------------
    genvar g;
    generate
        for (g = 0; g < NB_OUTPUTS; g++) begin : gen_outputs
            assign m_axi_tdata[g*DATA_WIDTH +: DATA_WIDTH] = s_axi_tdata;
            assign m_axi_tuser[g]  = s_axi_tuser;
            assign m_axi_tlast[g]  = s_axi_tlast;
            // The comparison alone excludes discard codes: cur_sel of
            // NB_OUTPUTS or more can never equal an output index
            assign m_axi_tvalid[g] = s_axi_tvalid && (32'(cur_sel) == g);
        end
    endgenerate

    assign m_info = s_info;

endmodule
