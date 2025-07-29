//-----------------------------------------------------------------------------
// Title         : RMII MAC Receiver (Fast Ethernet)
//-----------------------------------------------------------------------------
// File          : rmii_mac_rx_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2025-07-28
// Last modified : 2025-07-28
//-----------------------------------------------------------------------------
// Description :
// Testbench of the RMII MAC Receiver module.
//-----------------------------------------------------------------------------
// Copyright (c) 2025 by Christophe Clienti. This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------



`timescale 1 ns / 100 ps

module rmii_mac_rx_tb;
    //----------------------------------------------------------------
    // Constants
    //----------------------------------------------------------------
    localparam int C_NUM_TEST_VECTORS = 490; // Number of test vectors
    //----------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------

    logic       clock;
    logic       srst;
    logic [1:0] rxd;
    logic       rxen;
    logic       axi_tvalid;
    logic       axi_tlast;
    logic [1:0] axi_tdata;
    logic       axi_tuser;
    logic       axi_tready;

    logic [2:0] test_vectors [0:552];

    //----------------------------------------------------------------
    // DUT
    //----------------------------------------------------------------

    rmii_mac_rx rmii_mac_rx_inst (
        .clock      (clock),
        .srst       (srst),
        .rxd        (rxd),
        .rxen       (rxen),
        .axi_tvalid (axi_tvalid),
        .axi_tlast  (axi_tlast),
        .axi_tdata  (axi_tdata),
        .axi_tuser  (axi_tuser),
        .axi_tready (axi_tready)
    );

    //----------------------------------------------------------------
    // Clock and reset generation
    //----------------------------------------------------------------

    initial begin
        clock     = 0;
        srst      = 1;
        #40 srst  = 0;
    end

    always
        #10 clock = !clock;

    //----------------------------------------------
    // Value Change Dump
    //----------------------------------------------
    initial  begin
        $dumpfile ("rmii_mac_rx_tb.vcd");
        $dumpvars;
    end

    //----------------------------------------------------------------
    // Checks
    //----------------------------------------------------------------

    //----------------------------------------------------------------
    // Test vectors
    //----------------------------------------------------------------
    integer cpt = 0;
    integer cpt_mod = 0;

    initial begin
        $readmemb("inputs.mem", test_vectors);
        #50000 $finish;
    end

    always @(posedge clock) begin
        if(srst == 1'b1) begin
            cpt <= 0;
            cpt_mod <= 0;
        end
        else begin
            cpt <= cpt + 1;
            cpt_mod <= (cpt + 1) % C_NUM_TEST_VECTORS;
        end
    end

    always @(*) begin
        if (cpt_mod >= 1 && cpt_mod <= C_NUM_TEST_VECTORS) begin
            rxd = test_vectors[cpt_mod-1][2:1];
            rxen = test_vectors[cpt_mod-1][0];
        end
        else if (cpt_mod > C_NUM_TEST_VECTORS) begin
            rxd = 2'b00;
            rxen = 1'b0;
        end
        else begin
            rxd = 2'b00;
            rxen = 1'b0;
        end
    end

    //----------------------------------------------------------------
    // Optional: simulate AXI backpressure
    //----------------------------------------------------------------
    // Simulate a brief AXI backpressure to trigger ERROR or DROP
    always @(posedge clock) begin
        if (cpt >= 700 && cpt < 701) begin
            axi_tready <= 0;
        end
        else begin
            axi_tready <= 1;
        end
    end
endmodule
