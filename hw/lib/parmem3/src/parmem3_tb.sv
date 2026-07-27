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



`timescale 1 ns / 100 ps

// Self-checking testbench for parmem3. Two DUTs (PARRES = 1 and
// PARRES = 0) are driven identically; checks are applied to the
// parallel-residue instance and cross-checked against the serial one.
// A third instance covers OUTREG = 1. Mirrors the reference model in
// hw/vliw/study/crt_addressing.py:
//   1. bijection: fill with single writes, read back with single reads
//   2. dual read, strides -11..11 with stride % 3 != 0 (signed strides
//      exercise the two's-complement residue correction): no conflict,
//      both data correct
//   3. dual read, stride % 3 == 0 (including 0): conflict, access 0 wins
//   4. dual write (ST2-style pairs), verified by read-back
//   5. out-of-range: EA0 top-bits check; EA1 negative and overflowing,
//      including the truncation-alias trap (EA1 < 0 truncating into a
//      VALID address): flagged, suppressed, no memory corruption
//   6. READ_FIRST: a write returns the pre-write cell content
//   7. side B (NI, own clock): linear fill + read back, cross-checked
//      against side A
//   8. OUTREG = 1 variant: 2-cycle reads with the enable-extension
//      protocol, sides A and B

module parmem3_tb();

   parameter DEPTH    = 4;
   parameter WIDTH    = 32;
   parameter STRIDE_W = 6;

   localparam AW    = DEPTH + 2;
   localparam WORDS = 3 * (1 << DEPTH);

   logic                clka, clkb;
   logic                en, wen, dual;
   logic [AW-1:0]       addr;
   logic [STRIDE_W-1:0] stride;
   logic [WIDTH-1:0]    dia0, dia1;

   logic [WIDTH-1:0]    doa0, doa1, doa0_s, doa1_s;
   logic                conflict, oob0, oob1;
   logic                conflict_s, oob0_s, oob1_s;

   logic                enb, web;
   logic [AW-1:0]       addrb;
   logic [WIDTH-1:0]    dib;
   logic [WIDTH-1:0]    dob, dob_s;
   logic                oobb, oobb_s;

   // OUTREG = 1 variant (independent instance and signals)
   logic                en_r, wen_r;
   logic [AW-1:0]       addr_r;
   logic [WIDTH-1:0]    dia0_r, doa0_r;
   logic                enb_r, web_r;
   logic [AW-1:0]       addrb_r;
   logic [WIDTH-1:0]    dib_r, dob_r;

   int                  errors = 0;

   logic [WIDTH-1:0]    refmem [0:WORDS-1];


   // reference instance: parallel residue
   parmem3 #(.DEPTH(DEPTH), .WIDTH(WIDTH), .STRIDE_W(STRIDE_W),
             .OUTREGA(0), .OUTREGB(0), .PARRES(1))
   dut_par (.clka(clka), .en(en), .wen(wen), .dual(dual),
            .addr(addr), .stride(stride), .dia0(dia0), .dia1(dia1),
            .doa0(doa0), .doa1(doa1),
            .conflict(conflict), .oob0(oob0), .oob1(oob1),
            .clkb(clkb), .enb(enb), .web(web), .addrb(addrb),
            .dib(dib), .dob(dob), .oobb(oobb));

   // cross-check instance: serial residue (mod3 of the EA1 sum)
   parmem3 #(.DEPTH(DEPTH), .WIDTH(WIDTH), .STRIDE_W(STRIDE_W),
             .OUTREGA(0), .OUTREGB(0), .PARRES(0))
   dut_ser (.clka(clka), .en(en), .wen(wen), .dual(dual),
            .addr(addr), .stride(stride), .dia0(dia0), .dia1(dia1),
            .doa0(doa0_s), .doa1(doa1_s),
            .conflict(conflict_s), .oob0(oob0_s), .oob1(oob1_s),
            .clkb(clkb), .enb(enb), .web(web), .addrb(addrb),
            .dib(dib), .dob(dob_s), .oobb(oobb_s));

   // OUTREG = 1 variant: 2-cycle reads, enable-gated output register
   parmem3 #(.DEPTH(DEPTH), .WIDTH(WIDTH), .STRIDE_W(STRIDE_W),
             .OUTREGA(1), .OUTREGB(1), .PARRES(1))
   dut_reg (.clka(clka), .en(en_r), .wen(wen_r), .dual(1'b0),
            .addr(addr_r), .stride('0), .dia0(dia0_r), .dia1('0),
            .doa0(doa0_r), .doa1(),
            .conflict(), .oob0(), .oob1(),
            .clkb(clkb), .enb(enb_r), .web(web_r), .addrb(addrb_r),
            .dib(dib_r), .dob(dob_r), .oobb());

   //----------------------------------------------------------------
   // VCD
   //----------------------------------------------------------------
   initial begin
      $dumpfile("parmem3_tb.vcd");
      $dumpvars(0, parmem3_tb);
   end

   //----------------------------------------------------------------
   // Clock generation (side B deliberately unrelated to side A)
   //----------------------------------------------------------------
   initial begin
      clka = 0;
      clkb = 0;
   end

   always begin
      #5 clka = ~clka;
   end

   always begin
      #7 clkb = ~clkb;
   end

   //----------------------------------------------------------------
   // Helpers
   //----------------------------------------------------------------
   function automatic logic [WIDTH-1:0] pattern(input int a);
      return 32'hA5A50000 + a[15:0] * 16'h0021;
   endfunction

   function automatic logic [WIDTH-1:0] pattern_ni(input int a);
      return 32'h0C0DE000 + a[15:0] * 16'h0013;
   endfunction

   task automatic idle();
      en = 0; wen = 0; dual = 0; addr = '0; stride = '0;
      dia0 = '0; dia1 = '0;
      enb = 0; web = 0; addrb = '0; dib = '0;
   endtask

   task automatic idle_r();
      en_r = 0; wen_r = 0; addr_r = '0; dia0_r = '0;
      enb_r = 0; web_r = 0; addrb_r = '0; dib_r = '0;
   endtask

   task automatic check(input string what, input bit cond);
      if (!cond) begin
         errors++;
         $display("Error: %s (time %0t)", what, $time);
      end
   endtask

   // both PARRES instances must always agree
   task automatic xcheck(input string what);
      check({what, " [par/ser conflict mismatch]"}, conflict === conflict_s);
      check({what, " [par/ser oob mismatch]"},
            (oob0 === oob0_s) && (oob1 === oob1_s));
   endtask

   task automatic write_single(input int a, input logic [WIDTH-1:0] d);
      @(negedge clka);
      en = 1; wen = 1; dual = 0; addr = a[AW-1:0]; dia0 = d;
      @(negedge clka);
      idle();
   endtask

   task automatic read_check_single(input int a, input logic [WIDTH-1:0] exp,
                                    input string what);
      @(negedge clka);
      en = 1; wen = 0; dual = 0; addr = a[AW-1:0];
      @(negedge clka);
      idle();
      check($sformatf("%s: addr %0d read %08h expected %08h",
                      what, a, doa0, exp), doa0 === exp);
      check($sformatf("%s: addr %0d serial instance", what, a),
            doa0_s === exp);
   endtask

   //----------------------------------------------------------------
   // Test sequence
   //----------------------------------------------------------------
   initial begin
      int s, a1;
      idle();
      idle_r();
      @(posedge clka);

      //--- Phase 1: fill (single writes), read back (single reads) ----
      for (int a = 0; a < WORDS; a++) begin
         write_single(a, pattern(a));
         refmem[a] = pattern(a);
      end
      for (int a = 0; a < WORDS; a++) begin
         read_check_single(a, refmem[a], "bijection");
      end
      $display("phase 1 (bijection, %0d words) done", WORDS);

      //--- Phase 2: dual read, signed strides, stride %% 3 != 0 -------
      for (s = -11; s <= 11; s++) begin
         if (s % 3 == 0) continue;
         for (int a = 0; a < WORDS; a++) begin
            a1 = a + s;
            if (a1 < 0 || a1 >= WORDS) continue;
            @(negedge clka);
            en = 1; wen = 0; dual = 1;
            addr = a[AW-1:0]; stride = s[STRIDE_W-1:0];
            #2;
            check($sformatf("stride %0d addr %0d: conflict", s, a),
                  conflict === 1'b0);
            xcheck($sformatf("stride %0d addr %0d", s, a));
            @(negedge clka);
            idle();
            check($sformatf("stride %0d addr %0d: data0", s, a),
                  doa0 === refmem[a]);
            check($sformatf("stride %0d addr %0d: data1", s, a),
                  doa1 === refmem[a1]);
            check($sformatf("stride %0d addr %0d: serial data", s, a),
                  (doa0_s === refmem[a]) && (doa1_s === refmem[a1]));
         end
      end
      $display("phase 2 (dual read, signed strides, no conflict) done");

      //--- Phase 3: stride %% 3 == 0 -> conflict (including 0) --------
      for (s = -9; s <= 9; s += 3) begin
         for (int a = 0; a < WORDS; a += 7) begin
            a1 = a + s;
            if (a1 < 0 || a1 >= WORDS) continue;
            @(negedge clka);
            en = 1; wen = 0; dual = 1;
            addr = a[AW-1:0]; stride = s[STRIDE_W-1:0];
            #2;
            check($sformatf("stride %0d addr %0d: conflict expected", s, a),
                  conflict === 1'b1);
            xcheck($sformatf("stride %0d addr %0d", s, a));
            @(negedge clka);
            idle();
            check($sformatf("stride %0d addr %0d: access 0 wins", s, a),
                  doa0 === refmem[a]);
         end
      end
      $display("phase 3 (stride %% 3 == 0, conflicts) done");

      //--- Phase 4: dual writes (ST2-style pairs) ---------------------
      for (s = 1; s <= 4; s += 3) begin            // strides 1 and 4
         for (int a = 0; a + s < WORDS; a += 5) begin
            @(negedge clka);
            en = 1; wen = 1; dual = 1;
            addr = a[AW-1:0]; stride = s[STRIDE_W-1:0];
            dia0 = pattern(a) ^ 32'h00FF00FF;
            dia1 = pattern(a + s) ^ 32'hFF00FF00;
            #2;
            check($sformatf("st2 stride %0d addr %0d: conflict", s, a),
                  conflict === 1'b0);
            @(negedge clka);
            idle();
            refmem[a]     = pattern(a) ^ 32'h00FF00FF;
            refmem[a + s] = pattern(a + s) ^ 32'hFF00FF00;
            read_check_single(a, refmem[a],
                              $sformatf("st2 stride %0d word0", s));
            read_check_single(a + s, refmem[a + s],
                              $sformatf("st2 stride %0d word1", s));
         end
      end
      $display("phase 4 (dual writes) done");

      //--- Phase 5: out-of-range --------------------------------------
      // EA0 top-bits check
      @(negedge clka);
      en = 1; wen = 1; dual = 0;
      addr = WORDS[AW-1:0]; dia0 = 32'hBAD00BAD;
      #2;
      check("ea0 oob: flagged", oob0 === 1'b1);
      xcheck("ea0 oob");
      @(negedge clka);
      idle();
      read_check_single(0, refmem[0], "ea0 oob: aliased cell untouched");
      // truncation-alias trap: 0 + (-20) = -20, truncates to 44 < WORDS
      @(negedge clka);
      en = 1; wen = 1; dual = 1;
      addr = '0; stride = STRIDE_W'(-20);
      dia0 = 32'hDEAD0005; dia1 = 32'hBAD00BAD;
      #2;
      check("ea1 alias trap: oob1 flagged", oob1 === 1'b1);
      check("ea1 alias trap: access 0 not flagged", oob0 === 1'b0);
      xcheck("ea1 alias trap");
      @(negedge clka);
      idle();
      refmem[0] = 32'hDEAD0005;                   // access 0 proceeds
      read_check_single(44, refmem[44], "ea1 alias trap: word 44 untouched");
      read_check_single(0, refmem[0], "ea1 alias trap: word 0 written");
      // overflow above the valid range
      @(negedge clka);
      en = 1; wen = 0; dual = 1;
      addr = (WORDS - 1); stride = STRIDE_W'(4);
      #2;
      check("ea1 overflow: oob1 flagged", oob1 === 1'b1);
      xcheck("ea1 overflow");
      @(negedge clka);
      idle();
      // conflict is a pure stride function: it co-asserts with oob1
      // when stride % 3 == 0 AND EA1 is out of range (oob wins upstream)
      @(negedge clka);
      en = 1; wen = 0; dual = 1;
      addr = (WORDS - 1); stride = STRIDE_W'(3);
      #2;
      check("conflict/oob co-assert: oob1", oob1 === 1'b1);
      check("conflict/oob co-assert: conflict", conflict === 1'b1);
      xcheck("conflict/oob co-assert");
      @(negedge clka);
      idle();
      $display("phase 5 (out-of-range, alias trap) done");

      //--- Phase 6: READ_FIRST -- write returns pre-write content -----
      @(negedge clka);
      en = 1; wen = 1; dual = 0; addr = 2; dia0 = 32'hDEAD0006;
      @(negedge clka);
      idle();
      check("read-first: old data during write", doa0 === refmem[2]);
      refmem[2] = 32'hDEAD0006;
      read_check_single(2, refmem[2], "read-first: new data afterwards");
      $display("phase 6 (READ_FIRST) done");

      //--- Phase 7: side B (NI) fill and read back ---------------------
      for (int a = 0; a < WORDS; a++) begin
         @(negedge clkb);
         enb = 1; web = 1; addrb = a[AW-1:0]; dib = pattern_ni(a);
         refmem[a] = pattern_ni(a);
         @(negedge clkb);
         idle();
      end
      @(negedge clkb);
      enb = 1; web = 1; addrb = WORDS[AW-1:0]; dib = 32'hBAD00BAD;
      #2;
      check("NI oob: oobb flagged", oobb === 1'b1);
      check("NI oob: serial instance", oobb_s === 1'b1);
      @(negedge clkb);
      idle();
      for (int a = 0; a < WORDS; a++) begin
         @(negedge clkb);
         enb = 1; web = 0; addrb = a[AW-1:0];
         @(negedge clkb);
         idle();
         check($sformatf("NI readback: addr %0d read %08h expected %08h",
                         a, dob, refmem[a]), dob === refmem[a]);
         check($sformatf("NI readback: addr %0d serial instance", a),
               dob_s === refmem[a]);
      end
      for (int a = 0; a < WORDS; a += 7) begin
         read_check_single(a, refmem[a], "NI-to-core cross-check");
      end
      $display("phase 7 (side B / NI, dual clock) done");

      //--- Phase 8: OUTREG = 1 variant ----------------------------------
      // Writes are single-cycle; reads keep the enable asserted for TWO
      // cycles (the dpmemrf output register is enable-gated), data is
      // valid after the second enabled edge.
      for (int a = 0; a < WORDS; a++) begin
         @(negedge clka);
         en_r = 1; wen_r = 1; addr_r = a[AW-1:0];
         dia0_r = pattern(a) ^ 32'h5A5A5A5A;
         @(negedge clka);
         idle_r();
      end
      for (int a = 0; a < WORDS; a++) begin
         @(negedge clka);
         en_r = 1; wen_r = 0; addr_r = a[AW-1:0];
         @(negedge clka);              // 2nd enabled cycle flushes DO reg
         @(negedge clka);
         idle_r();
         check($sformatf("outreg A: addr %0d read %08h expected %08h",
                         a, doa0_r, pattern(a) ^ 32'h5A5A5A5A),
               doa0_r === (pattern(a) ^ 32'h5A5A5A5A));
      end
      for (int a = 0; a < WORDS; a += 5) begin
         @(negedge clkb);
         enb_r = 1; web_r = 0; addrb_r = a[AW-1:0];
         @(negedge clkb);
         @(negedge clkb);
         idle_r();
         check($sformatf("outreg B: addr %0d read %08h expected %08h",
                         a, dob_r, pattern(a) ^ 32'h5A5A5A5A),
               dob_r === (pattern(a) ^ 32'h5A5A5A5A));
      end
      $display("phase 8 (OUTREG=1 variant, 2-cycle reads) done");

      //--- Summary ------------------------------------------------------
      if (errors == 0) begin
         $display("parmem3_tb: ALL TESTS PASSED (%0d words, DEPTH=%0d)",
                  WORDS, DEPTH);
      end
      else begin
         $display("parmem3_tb: FAILED with %0d error(s)", errors);
      end
      $finish;
   end


endmodule // parmem3_tb
