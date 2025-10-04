//-----------------------------------------------------------------------------
// Title         : AXI Stream Upsizer Testbench
// Project       : AXI Stream Upsizer
//-----------------------------------------------------------------------------
// File          : axi_stream_upsizer_tb.sv
// Author        : christophe <christophe@fixe>
//-----------------------------------------------------------------------------
// Description   :
// Testbench of the AXI Stream Upsizer module.
//-----------------------------------------------------------------------------
// Copyright (c) 2025 by Christophe Clienti This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

`timescale 1ns / 100ps

module axi_stream_upsizer_tb;

    localparam int             UPSIZE_RATIO   = 4;
    localparam int             IN_DATA_WIDTH  = 2;
    localparam int             IN_USER_WIDTH  = 1;
    localparam int             OUT_USER_WIDTH = IN_USER_WIDTH * UPSIZE_RATIO;
    localparam int             OUT_DATA_WIDTH = IN_DATA_WIDTH * UPSIZE_RATIO;


    logic                      clock;
    logic                      sreset;
    logic [IN_DATA_WIDTH-1:0]  s_axi_tdata;
    logic [IN_USER_WIDTH-1:0]  s_axi_tuser;
    logic                      s_axi_tvalid;
    logic                      s_axi_tlast;
    logic                      s_axi_tready;
    logic [OUT_DATA_WIDTH-1:0] m_axi_tdata;
    logic [OUT_USER_WIDTH-1:0] m_axi_tuser;
    logic                      m_axi_tvalid;
    logic                      m_axi_tlast;
    logic [UPSIZE_RATIO-1:0]   m_axi_tkeep;
    logic                      m_axi_tready;

    int                        cpt;

    //----------------------------------------------------------------
    // DUT
    //----------------------------------------------------------------
    axi_stream_upsizer
    #(
        .UPSIZE_RATIO   (UPSIZE_RATIO),
        .IN_DATA_WIDTH  (IN_DATA_WIDTH),
        .IN_USER_WIDTH  (IN_USER_WIDTH)
    )
    axi_stream_upsizer_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (s_axi_tdata),
        .s_axi_tuser  (s_axi_tuser),
        .s_axi_tvalid (s_axi_tvalid),
        .s_axi_tlast  (s_axi_tlast),
        .s_axi_tready (s_axi_tready),
        .m_axi_tdata  (m_axi_tdata),
        .m_axi_tuser  (m_axi_tuser),
        .m_axi_tvalid (m_axi_tvalid),
        .m_axi_tlast  (m_axi_tlast),
        .m_axi_tkeep  (m_axi_tkeep),
        .m_axi_tready (m_axi_tready)
    );

    //----------------------------------------------------------------
    // Clock and reset generation
    //----------------------------------------------------------------
    initial begin
        clock       = 0;
        sreset      = 1;
        #40 sreset  = 0;
    end

    always
        #10 clock = !clock;

    //----------------------------------------------
    // Value Change Dump
    //----------------------------------------------
    initial  begin
        $dumpfile ("axi_stream_upsizer_tb.vcd");
        $dumpvars;
    end


    //----------------------------------------------------------------
    // Generate stimulus
    //----------------------------------------------------------------
    always_ff @(posedge clock) begin
        if (sreset) begin
            m_axi_tready <= 1'b1;
        end
        else begin
            m_axi_tready <= $urandom_range(0, 1) == 1 ? 1'b1 : 1'b0;
        end
    end

    always_ff @(posedge clock) begin
        if (sreset) begin
            cpt <= 0;
        end
        else begin
            if (m_axi_tready) begin
                cpt <= cpt + 1;
            end
        end
    end

    always_comb begin
        case (cpt)
             0: begin s_axi_tdata = 2'b00; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b0; s_axi_tlast  = 1'b0; end

             // First packet (4 beats)
             1: begin s_axi_tdata = 2'b00; s_axi_tuser = 1'b1; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
             2: begin s_axi_tdata = 2'b01; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
             3: begin s_axi_tdata = 2'b10; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
             4: begin s_axi_tdata = 2'b11; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b1; end

             // Second packet (1 beats)
             5: begin s_axi_tdata = 2'b10; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b1; end

             // Wait state
             6: begin s_axi_tdata = 2'b00; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b0; s_axi_tlast  = 1'b0; end

             // Third packet (3 beats)
             7: begin s_axi_tdata = 2'b11; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
             8: begin s_axi_tdata = 2'b00; s_axi_tuser = 1'b1; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
             9: begin s_axi_tdata = 2'b01; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b1; end

             // Fourth packet (8 beats)
            10: begin s_axi_tdata = 2'b00; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
            11: begin s_axi_tdata = 2'b01; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
            12: begin s_axi_tdata = 2'b10; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
            13: begin s_axi_tdata = 2'b11; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
            14: begin s_axi_tdata = 2'b11; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
            15: begin s_axi_tdata = 2'b10; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
            16: begin s_axi_tdata = 2'b01; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
            17: begin s_axi_tdata = 2'b00; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b1; end

            // Fifth packet (7 beats)
            18: begin s_axi_tdata = 2'b00; s_axi_tuser = 1'b1; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
            19: begin s_axi_tdata = 2'b01; s_axi_tuser = 1'b1; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
            20: begin s_axi_tdata = 2'b10; s_axi_tuser = 1'b1; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
            21: begin s_axi_tdata = 2'b11; s_axi_tuser = 1'b1; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
            22: begin s_axi_tdata = 2'b11; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
            23: begin s_axi_tdata = 2'b10; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b0; end
            24: begin s_axi_tdata = 2'b11; s_axi_tuser = 1'b1; s_axi_tvalid = 1'b1; s_axi_tlast  = 1'b1; end

            // End of simulation
            25: begin s_axi_tdata = 2'b00; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b0; s_axi_tlast  = 1'b0; end
            26: begin s_axi_tdata = 2'b00; s_axi_tuser = 1'b0; s_axi_tvalid = 1'b0; s_axi_tlast  = 1'b0; end
            default: $finish;
        endcase
    end

    //----------------------------------------------------------------
    // Check outputs
    //----------------------------------------------------------------

    always_ff @(posedge clock) begin
        if (!sreset && m_axi_tready) begin
            case (cpt)
                // First packet (4 beats)
                5: begin
                    assert(m_axi_tvalid == 1'b1);
                    assert(m_axi_tdata == 8'b11100100);
                    assert(m_axi_tuser == 4'b0001);
                    assert(m_axi_tlast == 1'b1);
                    assert(m_axi_tkeep == 4'b1111);
                end
                // Second packet (1 beat)
                6: begin
                    assert(m_axi_tvalid == 1'b1);
                    assert(m_axi_tdata == 8'b00000010);
                    assert(m_axi_tuser == 4'b0000);
                    assert(m_axi_tlast == 1'b1);
                    assert(m_axi_tkeep == 4'b0001);
                end
                // Third packet (3 beats)
                10: begin
                    assert(m_axi_tvalid == 1'b1);
                    assert(m_axi_tdata == 8'b00010011);
                    assert(m_axi_tuser == 4'b0010);
                    assert(m_axi_tlast == 1'b1);
                    assert(m_axi_tkeep == 4'b0111);
                end
                // Fourth packet (8 beats)
                14: begin
                    assert(m_axi_tvalid == 1'b1);
                    assert(m_axi_tdata == 8'b11100100);
                    assert(m_axi_tuser == 4'b0000);
                    assert(m_axi_tlast == 1'b0);
                    assert(m_axi_tkeep == 4'b1111);
                end
                18: begin
                    assert(m_axi_tvalid == 1'b1);
                    assert(m_axi_tdata == 8'b00011011);
                    assert(m_axi_tuser == 4'b0000);
                    assert(m_axi_tlast == 1'b1);
                    assert(m_axi_tkeep == 4'b1111);
                end
                // Fifth packet (7 beats)
                22: begin
                    assert(m_axi_tvalid == 1'b1);
                    assert(m_axi_tdata == 8'b11100100);
                    assert(m_axi_tuser == 4'b1111);
                    assert(m_axi_tlast == 1'b0);
                    assert(m_axi_tkeep == 4'b1111);
                end
                25: begin
                    assert(m_axi_tvalid == 1'b1);
                    assert(m_axi_tdata == 8'b00111011);
                    assert(m_axi_tuser == 4'b0100);
                    assert(m_axi_tlast == 1'b1);
                    assert(m_axi_tkeep == 4'b0111);
                end
                default: assert(m_axi_tvalid == 1'b0);
            endcase
        end
    end

endmodule
