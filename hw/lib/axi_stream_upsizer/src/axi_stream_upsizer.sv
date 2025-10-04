//-----------------------------------------------------------------------------
// Title         : AXI Stream Upsizer
// Project       : AXI Stream Upsizer
//-----------------------------------------------------------------------------
// File          : axi_stream_upsizer.sv
// Author        : Christophe Clienti
//-----------------------------------------------------------------------------
// Description   :
// This module upsizes the data width of an AXI stream.
//-----------------------------------------------------------------------------
// Copyright (c) 2025 by Christophe Clienti This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

`timescale 1ns / 100ps

module axi_stream_upsizer #(
    parameter int  UPSIZE_RATIO = 4,
    parameter int  IN_DATA_WIDTH = 2,
    parameter int  IN_USER_WIDTH = 1,
    localparam int OUT_DATA_WIDTH = IN_DATA_WIDTH * UPSIZE_RATIO,
    localparam int OUT_USER_WIDTH = IN_USER_WIDTH * UPSIZE_RATIO
)(
    input logic                       clock,
    input logic                       sreset,

    // AXI Stream input
    input logic [IN_DATA_WIDTH-1:0]   s_axi_tdata,
    input logic [IN_USER_WIDTH-1:0]   s_axi_tuser,
    input logic                       s_axi_tvalid,
    input logic                       s_axi_tlast,
    output logic                      s_axi_tready,

    // AXI Stream output
    output logic [OUT_DATA_WIDTH-1:0] m_axi_tdata,
    output logic [OUT_USER_WIDTH-1:0] m_axi_tuser,
    output logic                      m_axi_tvalid,
    output logic                      m_axi_tlast,
    output logic [UPSIZE_RATIO-1:0]   m_axi_tkeep,
    input logic                       m_axi_tready);

    // Internal signals
    logic [IN_DATA_WIDTH-1:0] data_buffer [0:UPSIZE_RATIO-1];
    logic [IN_USER_WIDTH-1:0] user_buffer [0:UPSIZE_RATIO-1];
    logic [UPSIZE_RATIO-1:0]  buffer_ce, tkeep;

    // Shift register to enable the right sub-word in the data/user
    // buffers.  The CE signal is a one-hot signal that indicates
    // which buffer to fill, and the tkeep bits can be derived from
    // it.
    always_ff @(posedge clock) begin
        if (sreset) begin
            buffer_ce <= {{UPSIZE_RATIO-1{1'b0}}, 1'b1};
            tkeep <= {{UPSIZE_RATIO-1{1'b0}}, 1'b1};
        end
        else if (m_axi_tready && s_axi_tvalid) begin
            if (buffer_ce[UPSIZE_RATIO-1] || s_axi_tlast) begin
                buffer_ce <= {{UPSIZE_RATIO-1{1'b0}}, 1'b1};
                tkeep <= {{UPSIZE_RATIO-1{1'b0}}, 1'b1};
            end
            else begin
                buffer_ce <= {buffer_ce[UPSIZE_RATIO-2:0], buffer_ce[UPSIZE_RATIO-1]};
                tkeep <= {tkeep[UPSIZE_RATIO-2:0], 1'b1};
            end
        end
    end

    // Generate UPSIZE_RATIO registers to store incoming data and user
    // signals. We also assign the output data and user signals.
    genvar i;
    generate
        for (i=0; i<UPSIZE_RATIO; i=i+1) begin : gen_data_buffer
            always_ff @(posedge clock) begin
                if (sreset) begin
                    data_buffer[i] <= '0;
                    user_buffer[i] <= '0;
                end
                if (m_axi_tready) begin
                    if (buffer_ce[i]) begin
                        data_buffer[i] <= s_axi_tdata;
                        user_buffer[i] <= s_axi_tuser;
                    end
                    else if (m_axi_tvalid && i > 0) begin
                        data_buffer[i] <= '0;
                        user_buffer[i] <= '0;
                    end
                end
            end
            assign m_axi_tdata[(i+1)*IN_DATA_WIDTH-1 -: IN_DATA_WIDTH] = data_buffer[i];
            assign m_axi_tuser[(i+1)*IN_USER_WIDTH-1 -: IN_USER_WIDTH] = user_buffer[i];
        end
    endgenerate

    // Output valid and last signals
    always_ff @(posedge clock) begin
        if (sreset) begin
            m_axi_tvalid <= 1'b0;
        end
        else if (m_axi_tready) begin
            m_axi_tvalid <= s_axi_tvalid && (s_axi_tlast || buffer_ce[UPSIZE_RATIO-1]);
        end
    end

    always_ff @(posedge clock) begin
        if (sreset) begin
            m_axi_tlast <= 1'b0;
        end
        else if (m_axi_tready) begin
            m_axi_tlast <= s_axi_tlast;
        end
    end

    always_ff @(posedge clock) begin
        if (sreset) begin
            m_axi_tkeep <= '0;
        end
        else if (m_axi_tready && s_axi_tvalid) begin
            m_axi_tkeep <= tkeep;
        end
    end

    // Ready backpressure handling
    assign s_axi_tready = m_axi_tready;

endmodule
