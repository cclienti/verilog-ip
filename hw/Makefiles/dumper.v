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
