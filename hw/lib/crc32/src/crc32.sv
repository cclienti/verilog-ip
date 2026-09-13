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
// Last modified : 2026-09-13
//-----------------------------------------------------------------------------
// Description: Combinational CRC-32 step in the reflected (LSB-first)
// form: crc_out is crc_in advanced by DATA_WIDTH input bits, data[0]
// first. The default polynomial is the IEEE 802.3 / zlib one. The seed
// is not a parameter on purpose: it lives in the register the client
// owns and feeds back through crc_in, so any seed and any final
// complement policy work unchanged. For the Ethernet FCS: seed the
// register with 32'hFFFFFFFF, step every frame byte through, and the
// FCS is the complemented register sent low byte first.
//
// The step is a one-level XOR reduction, not the DATA_WIDTH sequential
// conditional stages the textbook bit-serial recurrence needs. CRC-32
// is linear over GF(2) in {crc_in, data}, so the whole map is exactly
// the XOR of the bit-serial recurrence evaluated on each SET input bit
// alone -- the basis expansion of a linear map. step_ref below is that
// recurrence, kept only to build the two constant matrices (mask_crc,
// mask_data) at elaboration time for the given POLY/DATA_WIDTH; it
// never reaches hardware itself. Measured on the Zedboard TCP
// endpoint: the bit-serial form, unrolled combinationally every cycle
// in axi_stream_eth_fcs_gen, was the fabric-domain critical path once
// the TCP checksum accumulator was fixed -- 31 logic levels, 16
// CARRY4, arriving through whichever control signal happened to gate
// the byte on the bus that cycle (with_mss_q in the TCP transmit
// builder), which was otherwise unrelated to the actual depth.

`timescale 1 ns / 100 ps

module crc32 #(
    parameter logic [31:0] POLY       = 32'hEDB88320, // reflected polynomial
    parameter int          DATA_WIDTH = 8             // bits consumed per step
)(
    input logic [31:0]           crc_in,
    input logic [DATA_WIDTH-1:0] data,
    output logic [31:0]          crc_out
);

    function automatic logic [31:0] step_ref(input logic [31:0]           crc,
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

    logic [31:0] mask_crc  [0:31];           // step_ref with one crc_in bit set, rest zero
    logic [31:0] mask_data [0:DATA_WIDTH-1]; // step_ref with one data bit set, rest zero

    for (genvar i = 0; i < 32; i++) begin : gen_mask_crc
        assign mask_crc[i] = step_ref(32'h1 << i, '0);
    end
    for (genvar i = 0; i < DATA_WIDTH; i++) begin : gen_mask_data
        assign mask_data[i] = step_ref('0, DATA_WIDTH'(1) << i);
    end

    always_comb begin
        crc_out = 32'h0;
        for (int i = 0; i < 32; i++) begin
            if (crc_in[i]) crc_out = crc_out ^ mask_crc[i];
        end
        for (int i = 0; i < DATA_WIDTH; i++) begin
            if (data[i]) crc_out = crc_out ^ mask_data[i];
        end
    end

endmodule
