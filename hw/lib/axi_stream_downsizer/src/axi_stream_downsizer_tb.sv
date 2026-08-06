//-----------------------------------------------------------------------------
// Title         : AXI Stream Downsizer Testbench
// Project       : AXI Stream Downsizer
//-----------------------------------------------------------------------------
// File          : axi_stream_downsizer_tb.sv
// Author        : Christophe Clienti
//-----------------------------------------------------------------------------
// Description   :
// Testbench of the AXI Stream Downsizer module. The stimulus is the wide
// stream the matching upsizer testbench expects as its output, so the
// checked narrow stream is that testbench's input: the pair round-trips.
// The output side applies random backpressure; the expected sequence of
// accepted transfers is unaffected by it, so the reference is a flat
// list indexed by a transfer counter.
//-----------------------------------------------------------------------------
// Copyright (c) 2025 by Christophe Clienti This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

`timescale 1ns / 100ps

module axi_stream_downsizer_tb;

    localparam int DOWNSIZE_RATIO = 4;
    localparam int OUT_DATA_WIDTH = 2;
    localparam int OUT_USER_WIDTH = 1;
    localparam int IN_DATA_WIDTH  = OUT_DATA_WIDTH * DOWNSIZE_RATIO;
    localparam int IN_USER_WIDTH  = OUT_USER_WIDTH * DOWNSIZE_RATIO;

    localparam int NB_TRANSFERS = 23;

    integer errors = 0;

    logic                      clock;
    logic                      sreset;

    logic [IN_DATA_WIDTH-1:0]  s_axi_tdata;
    logic [IN_USER_WIDTH-1:0]  s_axi_tuser;
    logic                      s_axi_tvalid;
    logic                      s_axi_tlast;
    logic [DOWNSIZE_RATIO-1:0] s_axi_tkeep;
    logic                      s_axi_tready;

    logic [OUT_DATA_WIDTH-1:0] m_axi_tdata;
    logic [OUT_USER_WIDTH-1:0] m_axi_tuser;
    logic                      m_axi_tvalid;
    logic                      m_axi_tlast;
    logic                      m_axi_tready;

    //----------------------------------------------------------------
    // DUT
    //----------------------------------------------------------------
    axi_stream_downsizer
    #(
        .DOWNSIZE_RATIO (DOWNSIZE_RATIO),
        .OUT_DATA_WIDTH (OUT_DATA_WIDTH),
        .OUT_USER_WIDTH (OUT_USER_WIDTH)
    )
    axi_stream_downsizer_inst
    (
        .clock        (clock),
        .sreset       (sreset),
        .s_axi_tdata  (s_axi_tdata),
        .s_axi_tuser  (s_axi_tuser),
        .s_axi_tvalid (s_axi_tvalid),
        .s_axi_tlast  (s_axi_tlast),
        .s_axi_tkeep  (s_axi_tkeep),
        .s_axi_tready (s_axi_tready),
        .m_axi_tdata  (m_axi_tdata),
        .m_axi_tuser  (m_axi_tuser),
        .m_axi_tvalid (m_axi_tvalid),
        .m_axi_tlast  (m_axi_tlast),
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

    // The beat index advances every cycle while idle, and on the input
    // handshake while a beat is presented: the wide beat holds until the
    // DUT has drained it.
    integer beat;

    always_ff @(posedge clock) begin
        if (sreset) begin
            beat <= 0;
        end
        else if (!s_axi_tvalid || s_axi_tready) begin
            beat <= beat + 1;
        end
    end

    always_comb begin
        case (beat)
            // First packet: one full beat
            1: begin s_axi_tdata = 8'b11100100; s_axi_tuser = 4'b0001; s_axi_tkeep = 4'b1111; s_axi_tvalid = 1'b1; s_axi_tlast = 1'b1; end

            // Second packet: a single kept sub-word
            2: begin s_axi_tdata = 8'b00000010; s_axi_tuser = 4'b0000; s_axi_tkeep = 4'b0001; s_axi_tvalid = 1'b1; s_axi_tlast = 1'b1; end

            // Third packet: three kept sub-words, after an idle cycle
            4: begin s_axi_tdata = 8'b00010011; s_axi_tuser = 4'b0010; s_axi_tkeep = 4'b0111; s_axi_tvalid = 1'b1; s_axi_tlast = 1'b1; end

            // Fourth packet: two full beats
            5: begin s_axi_tdata = 8'b11100100; s_axi_tuser = 4'b0000; s_axi_tkeep = 4'b1111; s_axi_tvalid = 1'b1; s_axi_tlast = 1'b0; end
            6: begin s_axi_tdata = 8'b00011011; s_axi_tuser = 4'b0000; s_axi_tkeep = 4'b1111; s_axi_tvalid = 1'b1; s_axi_tlast = 1'b1; end

            // Fifth packet: a full beat then a partial one, after an idle cycle
            8: begin s_axi_tdata = 8'b11100100; s_axi_tuser = 4'b1111; s_axi_tkeep = 4'b1111; s_axi_tvalid = 1'b1; s_axi_tlast = 1'b0; end
            9: begin s_axi_tdata = 8'b00111011; s_axi_tuser = 4'b0100; s_axi_tkeep = 4'b0111; s_axi_tvalid = 1'b1; s_axi_tlast = 1'b1; end

            default: begin s_axi_tdata = '0; s_axi_tuser = '0; s_axi_tkeep = '0; s_axi_tvalid = 1'b0; s_axi_tlast = 1'b0; end
        endcase
    end

    //----------------------------------------------------------------
    // Check outputs
    //----------------------------------------------------------------
    // The narrow stream the wide stimulus must unpack to, low sub-word
    // first -- the upsizer testbench's input sequence.
    logic [OUT_DATA_WIDTH-1:0] ref_data [0:NB_TRANSFERS-1];
    logic                      ref_user [0:NB_TRANSFERS-1];
    logic                      ref_last [0:NB_TRANSFERS-1];

    // Arrays rather than unpacked-array parameters, which iverilog does
    // not support.
    initial begin
        // packet 1
        ref_data[0]=2'b00; ref_data[1]=2'b01; ref_data[2]=2'b10; ref_data[3]=2'b11;
        ref_user[0]=1'b1;  ref_user[1]=1'b0;  ref_user[2]=1'b0;  ref_user[3]=1'b0;
        ref_last[0]=1'b0;  ref_last[1]=1'b0;  ref_last[2]=1'b0;  ref_last[3]=1'b1;
        // packet 2
        ref_data[4]=2'b10; ref_user[4]=1'b0; ref_last[4]=1'b1;
        // packet 3
        ref_data[5]=2'b11; ref_data[6]=2'b00; ref_data[7]=2'b01;
        ref_user[5]=1'b0;  ref_user[6]=1'b1;  ref_user[7]=1'b0;
        ref_last[5]=1'b0;  ref_last[6]=1'b0;  ref_last[7]=1'b1;
        // packet 4
        ref_data[8]=2'b00;  ref_data[9]=2'b01;  ref_data[10]=2'b10; ref_data[11]=2'b11;
        ref_data[12]=2'b11; ref_data[13]=2'b10; ref_data[14]=2'b01; ref_data[15]=2'b00;
        ref_user[8]=1'b0;  ref_user[9]=1'b0;  ref_user[10]=1'b0; ref_user[11]=1'b0;
        ref_user[12]=1'b0; ref_user[13]=1'b0; ref_user[14]=1'b0; ref_user[15]=1'b0;
        ref_last[8]=1'b0;  ref_last[9]=1'b0;  ref_last[10]=1'b0; ref_last[11]=1'b0;
        ref_last[12]=1'b0; ref_last[13]=1'b0; ref_last[14]=1'b0; ref_last[15]=1'b1;
        // packet 5
        ref_data[16]=2'b00; ref_data[17]=2'b01; ref_data[18]=2'b10; ref_data[19]=2'b11;
        ref_data[20]=2'b11; ref_data[21]=2'b10; ref_data[22]=2'b11;
        ref_user[16]=1'b1; ref_user[17]=1'b1; ref_user[18]=1'b1; ref_user[19]=1'b1;
        ref_user[20]=1'b0; ref_user[21]=1'b0; ref_user[22]=1'b1;
        ref_last[16]=1'b0; ref_last[17]=1'b0; ref_last[18]=1'b0; ref_last[19]=1'b0;
        ref_last[20]=1'b0; ref_last[21]=1'b0; ref_last[22]=1'b1;
    end

    integer transfers = 0;

    always_ff @(posedge clock) begin
        if (!sreset && m_axi_tvalid && m_axi_tready) begin
            if (transfers >= NB_TRANSFERS) begin
                errors = errors + 1;
                $display("Error: unexpected transfer %0d: data %b user %b last %b",
                         transfers, m_axi_tdata, m_axi_tuser, m_axi_tlast);
            end
            else if (m_axi_tdata !== ref_data[transfers] ||
                     m_axi_tuser !== ref_user[transfers] ||
                     m_axi_tlast !== ref_last[transfers]) begin
                errors = errors + 1;
                $display("Error: transfer %0d: data %b user %b last %b (ref %b %b %b)",
                         transfers, m_axi_tdata, m_axi_tuser, m_axi_tlast,
                         ref_data[transfers], ref_user[transfers], ref_last[transfers]);
            end
            transfers <= transfers + 1;
        end
    end

    // The verdict requires the whole sequence: a DUT that never produces
    // a transfer must not pass on silence.
    initial begin
        wait (transfers == NB_TRANSFERS);
        repeat (10) @(posedge clock);
        if (errors == 0)
            $display("axi_stream_downsizer_tb: ALL TESTS PASSED (%0d transfers)", transfers);
        else
            $display("axi_stream_downsizer_tb: %0d ERROR(S)", errors);
        $finish;
    end

    initial begin
        #100_000;
        $display("axi_stream_downsizer_tb: TIMEOUT - %0d of %0d transfers seen", transfers, NB_TRANSFERS);
        $display("axi_stream_downsizer_tb: 1 ERROR(S)");
        $finish;
    end

endmodule
