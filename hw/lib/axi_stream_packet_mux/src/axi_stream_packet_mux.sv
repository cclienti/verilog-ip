//-----------------------------------------------------------------------------
// Title         : AXI Stream Packet Mux
//-----------------------------------------------------------------------------
// File          : axi_stream_packet_mux.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-25
// Last modified : 2026-08-25
//-----------------------------------------------------------------------------
// Description: Frame-atomic round-robin merge of NB_INPUTS AXI streams
// into one. A frame is granted at its first beat and the grant is locked
// until its tlast beat is accepted, whatever tvalid does in between --
// a slow producer stretches its frame, it is never interleaved. The
// rotation pointer moves past the granted input at every frame end, so
// contending inputs are served strictly in turn and none can starve.
// Arbitration is a rotating-priority pointer rather than the prra
// component: prra holds its grant until the request SIGNAL drops, which
// fits level-held requesters, while a packet mux must rotate at frame
// boundaries even when the same source immediately presents its next
// frame.
//
// Per-input buses are packed: input i owns bit slice [i*W +: W]. The
// INFO_WIDTH side-band follows the convention of the packet FIFO: the
// producer holds s_info stable for the whole frame and the granted
// input's word is presented on m_info for the whole output frame.
// One idle cycle separates frames (the grant is registered).
//-----------------------------------------------------------------------------
// Copyright (c) 2026 by Christophe Clienti. This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module axi_stream_packet_mux #(
    parameter int NB_INPUTS  = 3,
    parameter int DATA_WIDTH = 8,
    parameter int INFO_WIDTH = 1
)(
    input logic                              clock,
    input logic                              sreset,

    // AXI Stream inputs, input i on bit slice [i*W +: W]
    input logic [NB_INPUTS*DATA_WIDTH-1:0]   s_axi_tdata,
    input logic [NB_INPUTS-1:0]              s_axi_tuser,
    input logic [NB_INPUTS-1:0]              s_axi_tvalid,
    input logic [NB_INPUTS-1:0]              s_axi_tlast,
    output logic [NB_INPUTS-1:0]             s_axi_tready,
    input logic [NB_INPUTS*INFO_WIDTH-1:0]   s_info,

    // AXI Stream output, one frame at a time
    output logic [DATA_WIDTH-1:0]            m_axi_tdata,
    output logic                             m_axi_tuser,
    output logic                             m_axi_tvalid,
    output logic                             m_axi_tlast,
    input logic                              m_axi_tready,
    output logic [INFO_WIDTH-1:0]            m_info
);

    localparam int SEL_W = (NB_INPUTS < 2) ? 1 : $clog2(NB_INPUTS);

    logic             busy;
    logic [SEL_W-1:0] sel;
    logic [SEL_W-1:0] ptr;   // rotation pointer: next input to favor

    //-------------------------------------------
    // Rotating-priority grant, evaluated while idle
    //-------------------------------------------
    logic             grant_valid;
    logic [SEL_W-1:0] grant_idx;

    // The offset-0 candidate (the pointer itself) is assigned last, so
    // it wins; each further offset has lower priority
    always_comb begin
        grant_valid = 1'b0;
        grant_idx   = '0;
        for (int i = NB_INPUTS-1; i >= 0; i--) begin
            if (s_axi_tvalid[(32'(ptr) + i) % NB_INPUTS]) begin
                grant_valid = 1'b1;
                grant_idx   = SEL_W'((32'(ptr) + i) % NB_INPUTS);
            end
        end
    end

    //-------------------------------------------
    // Frame lock
    //-------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            busy <= 1'b0;
            sel  <= '0;
            ptr  <= '0;
        end
        else if (!busy) begin
            if (grant_valid) begin
                busy <= 1'b1;
                sel  <= grant_idx;
                ptr  <= SEL_W'((32'(grant_idx) + 1) % NB_INPUTS);
            end
        end
        else if (m_axi_tvalid && m_axi_tready && m_axi_tlast) begin
            busy <= 1'b0; // frame delivered, re-arbitrate
        end
    end

    //-------------------------------------------
    // Passthrough of the granted input
    //-------------------------------------------
    assign m_axi_tdata  = s_axi_tdata[sel*DATA_WIDTH +: DATA_WIDTH];
    assign m_axi_tuser  = s_axi_tuser[sel];
    assign m_axi_tlast  = s_axi_tlast[sel];
    assign m_axi_tvalid = busy && s_axi_tvalid[sel];
    assign m_info       = s_info[sel*INFO_WIDTH +: INFO_WIDTH];

    always_comb begin
        s_axi_tready = '0;
        if (busy) begin
            s_axi_tready[sel] = m_axi_tready;
        end
    end

endmodule
