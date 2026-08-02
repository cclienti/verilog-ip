// Generic waveform dump driver
// Copyright (C) 2026 Christophe Clienti - All Rights Reserved
//
// Elaborated as a second root module beside the testbench, so that no
// testbench has to spell out the name of its dump file. iverilog.mk
// passes both macros below; the defaults only serve a hand-run
// iverilog invocation.
//
// The dump *format* is not set here: vvp takes it from an extended
// argument or, in its absence, from the IVERILOG_DUMPER environment
// variable, which iverilog.mk exports.

// This module has no delay, so its time unit is irrelevant -- but a file
// without a timescale, elaborated next to testbenches that have one, makes
// iverilog warn on every single build. The precision is the coarsest of
// the tree: simulation precision is the minimum over all directives, so
// 1ns can never make an existing one finer.
`timescale 1ns / 1ns

`ifndef DUMP_FILE
 `define DUMP_FILE "dump.fst"
`endif

`ifndef DUMP_SCOPE
 `define DUMP_SCOPE tb
`endif

module wave_dumper;
   initial begin
      $dumpfile(`DUMP_FILE);
      $dumpvars(0, `DUMP_SCOPE);
   end
endmodule
