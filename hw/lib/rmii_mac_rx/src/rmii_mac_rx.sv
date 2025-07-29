//-----------------------------------------------------------------------------
// Title         : RMII MAC Receiver (Fast Ethernet)
//-----------------------------------------------------------------------------
// File          : rmii_mac_rx.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2025-07-28
// Last modified : 2025-07-28
//-----------------------------------------------------------------------------
// Description: This module implements a simple RMII MAC receiver for Fast
// Ethernet. It receives data from the PHY and outputs Ethernet frame as a AXI
// stream data. The preamble and SFD are not sent to the AXI stream, only the
// payload is.
//-----------------------------------------------------------------------------
// Copyright (c) 2025 by Christophe Clienti. This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module rmii_mac_rx
   (input logic        clock,
    input logic        srst,

    input logic [1:0]  rxd,
    input logic        rxen,

    output logic       axi_tvalid,
    output logic       axi_tlast,
    output logic [1:0] axi_tdata
);

    //-------------------------------------------
    // Input synchronization
    //-------------------------------------------

    logic [1:0] rxd_d [0:2];
    logic       rxen_d [0:2];

    always @(posedge clock) begin
        rxd_d[0]   <= rxd;
        rxen_d[0] <= rxen;
        for(int i = 1; i <= 2; i++) begin
            rxd_d[i] <= rxd_d[i-1];
            rxen_d[i] <= rxen_d[i-1];
        end
    end

    //-------------------------------------------
    // Detect start/end of frame
    //-------------------------------------------
    logic starting;
    logic rxen_falling;

    assign starting = (rxd_d[2] == 2'b11) & !axi_tvalid;
    assign rxen_falling = rxen_d[1] && !rxen_d[0];

    always_ff @(posedge clock or posedge srst) begin
        if (srst) begin
            axi_tvalid <= 1'b0;
            axi_tlast  <= 1'b0;
        end else begin
            if (!axi_tvalid && starting) begin
                axi_tvalid <= 1'b1;
                axi_tlast  <= 1'b0;
            end
            else if (rxen_falling) begin
                axi_tvalid <= 1'b1;
                axi_tlast  <= 1'b1;
            end
            else if (axi_tlast) begin
                axi_tvalid  <= 1'b0;
                axi_tlast   <= 1'b0;
            end
        end
    end

    //-------------------------------------------
    // Manage TData
    //-------------------------------------------
    assign axi_tdata = rxd_d[2];

endmodule
