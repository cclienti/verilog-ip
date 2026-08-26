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
// Title         : CRC-32 Step Testbench
//-----------------------------------------------------------------------------
// File          : crc32_tb.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-24
// Last modified : 2026-08-24
//-----------------------------------------------------------------------------
// Description :
// Testbench of the CRC-32 step module. The DATA_WIDTH configuration space
// is swept: instances at 1, 2, 4 and 8 bits per step consume the same two
// messages LSB-first and must all reach the same CRC, checked against
// references computed independently ("123456789" is the textbook check
// value 0xCBF43926, the 60-byte ramp comes from zlib.crc32). A fifth
// instance checks the POLY parameter with CRC-32C (Castagnoli) and its
// textbook check value.

`timescale 1 ns / 100 ps

module crc32_tb;
    //----------------------------------------------------------------
    // Reference messages and CRC values
    //----------------------------------------------------------------
    localparam logic [31:0] CRC32_CHECK   = 32'hCBF43926; // crc32("123456789")
    localparam logic [31:0] CRC32_RAMP    = 32'hB0EC7FEE; // crc32(bytes 0..59)
    localparam logic [31:0] CRC32C_CHECK  = 32'hE3069283; // crc32c("123456789")

    logic [7:0] msg_check [0:8];
    logic [7:0] msg_ramp [0:59];

    integer     errors = 0;
    integer     done = 0;

    initial begin
        for (int i = 0; i < 9; i++) msg_check[i] = 8'h31 + 8'(i); // "123456789"
        for (int i = 0; i < 60; i++) msg_ramp[i] = 8'(i);
    end

    //----------------------------------------------------------------
    // Sweep DATA_WIDTH: every width must reach the same CRC
    //----------------------------------------------------------------
    genvar g;
    generate
        for (g = 0; g < 4; g++) begin : gen_width
            localparam int W = 1 << g;

            logic [31:0]  crc_in;
            logic [W-1:0] data;
            logic [31:0]  crc_out;

            crc32
            #(
                .DATA_WIDTH (W)
            )
            crc32_inst
            (
                .crc_in  (crc_in),
                .data    (data),
                .crc_out (crc_out)
            );

            initial begin : run_vectors
                logic [31:0] c;
                #100;

                c = 32'hFFFFFFFF;
                for (int b = 0; b < 9; b++) begin
                    for (int j = 0; j < 8/W; j++) begin
                        crc_in = c;
                        data   = msg_check[b][j*W +: W];
                        #1;
                        c = crc_out;
                    end
                end
                if (~c !== CRC32_CHECK) begin
                    errors = errors + 1;
                    $error("width %0d: check message gave %08x, expected %08x",
                           W, ~c, CRC32_CHECK);
                end

                c = 32'hFFFFFFFF;
                for (int b = 0; b < 60; b++) begin
                    for (int j = 0; j < 8/W; j++) begin
                        crc_in = c;
                        data   = msg_ramp[b][j*W +: W];
                        #1;
                        c = crc_out;
                    end
                end
                if (~c !== CRC32_RAMP) begin
                    errors = errors + 1;
                    $error("width %0d: ramp message gave %08x, expected %08x",
                           W, ~c, CRC32_RAMP);
                end

                done = done + 1;
            end
        end
    endgenerate

    //----------------------------------------------------------------
    // Sweep POLY: CRC-32C at 8 bits per step
    //----------------------------------------------------------------
    logic [31:0] crc32c_crc_in;
    logic [7:0]  crc32c_data;
    logic [31:0] crc32c_crc_out;

    crc32
    #(
        .POLY       (32'h82F63B78),
        .DATA_WIDTH (8)
    )
    crc32c_inst
    (
        .crc_in  (crc32c_crc_in),
        .data    (crc32c_data),
        .crc_out (crc32c_crc_out)
    );

    initial begin : run_crc32c
        logic [31:0] c;
        #100;

        c = 32'hFFFFFFFF;
        for (int b = 0; b < 9; b++) begin
            crc32c_crc_in = c;
            crc32c_data   = msg_check[b];
            #1;
            c = crc32c_crc_out;
        end
        if (~c !== CRC32C_CHECK) begin
            errors = errors + 1;
            $error("crc32c: check message gave %08x, expected %08x", ~c, CRC32C_CHECK);
        end

        done = done + 1;
    end

    //----------------------------------------------------------------
    // Verdict
    //----------------------------------------------------------------
    initial begin
        #10000;
        if (done != 5) begin
            errors = errors + 1;
            $error("only %0d of 5 checkers finished", done);
        end
        if (errors == 0)
          $display("crc32_tb: ALL TESTS PASSED");
        else
          $display("crc32_tb: %0d ERROR(S)", errors);
        $finish;
    end

endmodule
