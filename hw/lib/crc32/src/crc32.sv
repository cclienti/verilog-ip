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
// Title         : CRC-32 Step
//-----------------------------------------------------------------------------
// File          : crc32.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-24
// Last modified : 2026-08-24
//-----------------------------------------------------------------------------
// Description: Combinational CRC-32 step in the reflected (LSB-first)
// form: crc_out is crc_in advanced by DATA_WIDTH input bits, data[0]
// first. The default polynomial is the IEEE 802.3 / zlib one. The seed
// is not a parameter on purpose: it lives in the register the client
// owns and feeds back through crc_in, so any seed and any final
// complement policy work unchanged. For the Ethernet FCS: seed the
// register with 32'hFFFFFFFF, step every frame byte through, and the
// FCS is the complemented register sent low byte first.

`timescale 1 ns / 100 ps

module crc32 #(
    parameter logic [31:0] POLY       = 32'hEDB88320, // reflected polynomial
    parameter int          DATA_WIDTH = 8             // bits consumed per step
)(
    input logic [31:0]           crc_in,
    input logic [DATA_WIDTH-1:0] data,
    output logic [31:0]          crc_out
);

    function automatic logic [31:0] crc32_step(input logic [31:0]           crc,
                                               input logic [DATA_WIDTH-1:0] din);
        logic [31:0] c;
        c = crc;
        for (int i = 0; i < DATA_WIDTH; i++) begin
            if (c[0] ^ din[i]) begin
                c = (c >> 1) ^ POLY;
            end
            else begin
                c = c >> 1;
            end
        end
        return c;
    endfunction

    assign crc_out = crc32_step(crc_in, data);

endmodule
