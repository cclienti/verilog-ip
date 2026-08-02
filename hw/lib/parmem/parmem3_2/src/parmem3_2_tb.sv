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

// Self-checking testbench for parmem3_2 (3 banks, 2 lanes). A second
// instance covers OUTREG = 1. Mirrors the reference model in
// hw/vliw/study/crt_addressing.py:
//   1. bijection: fill with single writes, read back with single reads
//   2. pair read, strides -11..11 with stride % 3 != 0 (signed strides
//      exercise the two's-complement residue correction): no conflict,
//      both data correct
//   3. pair read, stride % 3 == 0 (including 0): conflict, lane 0 wins
//   4. pair write (ST2-style pairs), verified by read-back
//   5. partial lane masks: disabled lanes have no side effects; lane 1
//      alone is served at addr + stride; single active lane never
//      conflicts
//   6. out-of-range: EA0 top-bits check; EA1 negative and overflowing,
//      including the truncation-alias trap (EA1 < 0 truncating into a
//      VALID address): flagged, suppressed, no memory corruption
//   7. READ_FIRST: a write returns the pre-write cell content
//   8. side B (NI, own clock): linear fill + read back, cross-checked
//      against side A
//   9. OUTREG = 1 variant: 2-cycle reads with the enable-extension
//      protocol, sides A and B
//  10. ADRREG = 1 variant: address-phase pipeline register, 2-cycle
//      reads (no enable extension needed), conflict/oob still
//      combinational in the issue cycle

module parmem3_2_tb();

   parameter DEPTH    = 4;
   parameter WIDTH    = 32;
   parameter STRIDE_W = 6;

   localparam AW    = DEPTH + 2;
   localparam WORDS = 3 * (1 << DEPTH);
   localparam NB    = WIDTH / 8;

   logic                clka, clkb;
   logic                en, wen;
   logic [1:0]          lane_en;
   logic [AW-1:0]       addr;
   logic [STRIDE_W-1:0] stride;
   logic [2*WIDTH-1:0]  dia;
   logic [2*WIDTH-1:0]  doa;
   logic [2*NB-1:0]     ben;
   logic                freeze;
   logic                conflict;
   logic [1:0]          oob;

   logic                enb, web;
   logic [NB-1:0]       benb;
   logic [AW-1:0]       addrb;
   logic [WIDTH-1:0]    dib;
   logic [WIDTH-1:0]    dob;
   logic                oobb;

   // OUTREG = 1 variant (independent instance and signals)
   logic                en_r, wen_r;
   logic [AW-1:0]       addr_r;
   logic [2*WIDTH-1:0]  dia_r, doa_r;
   logic                enb_r, web_r;
   logic [NB-1:0]       benb_r;
   logic [AW-1:0]       addrb_r;
   logic [WIDTH-1:0]    dib_r, dob_r;

   // ADRREG = 1 variant (independent instance and signals)
   logic                en_p, wen_p;
   logic [1:0]          lane_en_p;
   logic [AW-1:0]       addr_p;
   logic [STRIDE_W-1:0] stride_p;
   logic [2*WIDTH-1:0]  dia_p, doa_p;
   logic [2*NB-1:0]     ben_p;
   logic                freeze_p;
   logic                conflict_p;
   logic [1:0]          oob_p;

   int                  errors = 0;

   logic [WIDTH-1:0]    refmem [0:WORDS-1];


   parmem3_2 #(.DEPTH(DEPTH), .WIDTH(WIDTH), .STRIDE_W(STRIDE_W),
             .OUTREGA(0), .OUTREGB(0))
   parmem3_2_inst (.clka(clka), .en(en), .wen(wen), .lane_en(lane_en),
                 .addr(addr), .stride(stride), .ben(ben), .dia(dia), .doa(doa),
                 .freeze(freeze), .conflict(conflict), .oob(oob),
                 .clkb(clkb), .enb(enb), .web(web), .benb(benb), .addrb(addrb),
                 .dib(dib), .dob(dob), .oobb(oobb));

   // OUTREG = 1 variant: 2-cycle reads, enable-gated output register
   parmem3_2 #(.DEPTH(DEPTH), .WIDTH(WIDTH), .STRIDE_W(STRIDE_W),
             .OUTREGA(1), .OUTREGB(1))
   parmem3_2_reg_inst (.clka(clka), .en(en_r), .wen(wen_r), .lane_en(2'b01),
                     .addr(addr_r), .stride('0), .ben({2*NB{1'b1}}),
                     .dia(dia_r), .doa(doa_r),
                     .freeze(), .conflict(), .oob(),
                     .clkb(clkb), .enb(enb_r), .web(web_r), .benb(benb_r),
                     .addrb(addrb_r),
                     .dib(dib_r), .dob(dob_r), .oobb());

   // ADRREG = 1 variant: address-phase pipeline register, 2-cycle reads
   parmem3_2 #(.DEPTH(DEPTH), .WIDTH(WIDTH), .STRIDE_W(STRIDE_W),
             .ADRREG(1), .OUTREGA(0), .OUTREGB(0))
   parmem3_2_adr_inst (.clka(clka), .en(en_p), .wen(wen_p), .lane_en(lane_en_p),
                     .addr(addr_p), .stride(stride_p), .ben(ben_p), .dia(dia_p),
                     .doa(doa_p), .freeze(freeze_p),
                     .conflict(conflict_p), .oob(oob_p),
                     .clkb(clkb), .enb(1'b0), .web(1'b0), .benb('0), .addrb('0),
                     .dib('0), .dob(), .oobb());

   //----------------------------------------------------------------
   // Serialization sweep: the same stimulus into all four
   // ADRREG x OUTREGA combinations. The replay path is timed by
   // SER_D = ADRREG + 1 + OUTREGA, so it must be exercised in every
   // one of them -- a conflicting pair driven only at ADRREG=0/
   // OUTREGA=0 leaves three quarters of the path unverified.
   //----------------------------------------------------------------
   logic                en_s, wen_s;
   logic [1:0]          lane_en_s;
   logic [AW-1:0]       addr_s;
   logic [STRIDE_W-1:0] stride_s;
   logic [2*NB-1:0]     ben_s;
   logic [2*WIDTH-1:0]  dia_s;
   logic [2*WIDTH-1:0]  doa_s [0:3];
   logic [3:0]          freeze_s;

   generate
      for (genvar g = 0; g < 4; g = g + 1) begin: gen_sweep
         // g[0] = ADRREG, g[1] = OUTREGA
         parmem3_2 #(.DEPTH(DEPTH), .WIDTH(WIDTH), .STRIDE_W(STRIDE_W),
                     .ADRREG(g % 2), .OUTREGA(g / 2), .OUTREGB(0))
         sweep_inst (.clka(clka), .en(en_s), .wen(wen_s),
                     .lane_en(lane_en_s), .addr(addr_s), .stride(stride_s),
                     .ben(ben_s), .dia(dia_s), .doa(doa_s[g]),
                     .freeze(freeze_s[g]), .conflict(), .oob(),
                     .clkb(clkb), .enb(1'b0), .web(1'b0), .benb('0),
                     .addrb('0), .dib('0), .dob(), .oobb());
      end
   endgenerate

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
      en = 0; wen = 0; lane_en = '0; addr = '0; stride = '0; dia = '0;
      ben = '1;                       // full-word writes unless stated
      enb = 0; web = 0; addrb = '0; dib = '0; benb = '1;
   endtask

   task automatic idle_r();
      en_r = 0; wen_r = 0; addr_r = '0; dia_r = '0;
      enb_r = 0; web_r = 0; addrb_r = '0; dib_r = '0; benb_r = '1;
   endtask

   task automatic idle_s();
      en_s = 0; wen_s = 0; lane_en_s = '0; addr_s = '0; stride_s = '0;
      dia_s = '0; ben_s = '1;
   endtask

   task automatic idle_p();
      en_p = 0; wen_p = 0; lane_en_p = '0; addr_p = '0; stride_p = '0;
      dia_p = '0; ben_p = '1;
   endtask

   task automatic check(input string what, input bit cond);
      if (!cond) begin
         errors++;
         $display("Error: %s (time %0t)", what, $time);
      end
   endtask

   task automatic write_single(input int a, input logic [WIDTH-1:0] d);
      @(negedge clka);
      en = 1; wen = 1; lane_en = 'b1; addr = a[AW-1:0];
      dia = '0;
      dia[0 +: WIDTH] = d;
      @(negedge clka);
      idle();
   endtask

   task automatic read_check_single(input int a, input logic [WIDTH-1:0] exp,
                                    input string what);
      @(negedge clka);
      en = 1; wen = 0; lane_en = 'b1; addr = a[AW-1:0];
      @(negedge clka);
      idle();
      check($sformatf("%s: addr %0d read %08h expected %08h",
                      what, a, doa[0 +: WIDTH], exp),
            doa[0 +: WIDTH] === exp);
   endtask

   //----------------------------------------------------------------
   // Test sequence
   //----------------------------------------------------------------
   initial begin
      int s, a1;
      idle();
      idle_r();
      idle_p();
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

      //--- Phase 2: pair read, signed strides, stride %% 3 != 0 -------
      for (s = -11; s <= 11; s++) begin
         if (s % 3 == 0) continue;
         for (int a = 0; a < WORDS; a++) begin
            a1 = a + s;
            if (a1 < 0 || a1 >= WORDS) continue;
            @(negedge clka);
            en = 1; wen = 0; lane_en = '1;
            addr = a[AW-1:0]; stride = s[STRIDE_W-1:0];
            #2;
            check($sformatf("stride %0d addr %0d: conflict", s, a),
                  conflict === 1'b0);
            check($sformatf("stride %0d addr %0d: oob", s, a), oob === '0);
            @(negedge clka);
            idle();
            check($sformatf("stride %0d addr %0d: data0", s, a),
                  doa[0 +: WIDTH] === refmem[a]);
            check($sformatf("stride %0d addr %0d: data1", s, a),
                  doa[WIDTH +: WIDTH] === refmem[a1]);
         end
      end
      $display("phase 2 (pair read, signed strides, no conflict) done");

      //--- Phase 3: stride %% 3 == 0, non-zero -> internal serialization
      // The memory serves lane 0, raises `freeze` for exactly one cycle
      // while it serves lane 1, and replays lane 0's word so the pair
      // still leaves together. The core holds its inputs while frozen,
      // which is what the extra negedge below models.
      for (s = -9; s <= 9; s += 3) begin
         if (s == 0) continue;                  // same_word: see phase 3b
         for (int a = 0; a < WORDS; a += 7) begin
            a1 = a + s;
            if (a1 < 0 || a1 >= WORDS) continue;
            @(negedge clka);
            en = 1; wen = 0; lane_en = '1;
            addr = a[AW-1:0]; stride = s[STRIDE_W-1:0];
            #2;
            check($sformatf("stride %0d addr %0d: conflict expected", s, a),
                  conflict === 1'b1);
            check($sformatf("stride %0d addr %0d: freeze not yet", s, a),
                  freeze === 1'b0);
            @(negedge clka);                    // core is frozen: hold inputs
            #2;
            check($sformatf("stride %0d addr %0d: freeze asserted", s, a),
                  freeze === 1'b1);
            @(negedge clka);
            idle();
            #2;
            check($sformatf("stride %0d addr %0d: freeze released", s, a),
                  freeze === 1'b0);
            check($sformatf("stride %0d addr %0d: lane 0 replayed", s, a),
                  doa[0 +: WIDTH] === refmem[a]);
            check($sformatf("stride %0d addr %0d: lane 1 served", s, a),
                  doa[WIDTH +: WIDTH] === refmem[a1]);
         end
      end
      $display("phase 3 (stride %% 3 == 0, serialized pairs) done");

      //--- Phase 3b: stride 0 -> same word, one access, no freeze ------
      for (int a = 0; a < WORDS; a += 5) begin
         @(negedge clka);
         en = 1; wen = 0; lane_en = '1;
         addr = a[AW-1:0]; stride = '0;
         #2;
         check($sformatf("stride 0 addr %0d: no conflict on a read", a),
               conflict === 1'b0);
         @(negedge clka);
         idle();
         #2;
         check($sformatf("stride 0 addr %0d: never freezes", a),
               freeze === 1'b0);
         check($sformatf("stride 0 addr %0d: lane 0", a),
               doa[0 +: WIDTH] === refmem[a]);
         check($sformatf("stride 0 addr %0d: lane 1 gets the same word", a),
               doa[WIDTH +: WIDTH] === refmem[a]);
      end
      // ...but a same-word WRITE has two masks and two data words, so it
      // serializes like any other conflict
      @(negedge clka);
      en = 1; wen = 1; lane_en = '1; addr = 6; stride = '0;
      ben = '1;
      dia[0 +: WIDTH]     = 32'h11112222;
      dia[WIDTH +: WIDTH] = 32'h33334444;
      #2;
      check("stride 0 write: conflict expected", conflict === 1'b1);
      @(negedge clka);                          // frozen: hold
      #2;
      check("stride 0 write: freeze asserted", freeze === 1'b1);
      @(negedge clka);
      idle();
      refmem[6] = 32'h33334444;                 // lane 1 writes last
      read_check_single(6, refmem[6], "stride 0 write: lane 1 landed last");
      $display("phase 3b (stride 0, same word) done");

      //--- Phase 4: pair writes (ST2-style) ---------------------------
      for (s = 1; s <= 4; s += 3) begin            // strides 1 and 4
         for (int a = 0; a + s < WORDS; a += 5) begin
            @(negedge clka);
            en = 1; wen = 1; lane_en = '1;
            addr = a[AW-1:0]; stride = s[STRIDE_W-1:0];
            dia[0 +: WIDTH]     = pattern(a) ^ 32'h00FF00FF;
            dia[WIDTH +: WIDTH] = pattern(a + s) ^ 32'hFF00FF00;
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
      $display("phase 4 (pair writes) done");

      //--- Phase 5: partial lane masks --------------------------------
      begin
         // disabled lane must have no side effect on a pair write
         @(negedge clka);
         en = 1; wen = 1; lane_en = 'b1;   // lane 0 only
         addr = 1; stride = STRIDE_W'(1);
         dia = '1;                          // garbage on lane 1
         dia[0 +: WIDTH] = 32'hDEAD0010;
         @(negedge clka);
         idle();
         refmem[1] = 32'hDEAD0010;
         read_check_single(1, refmem[1], "mask: lane 0 write landed");
         read_check_single(2, refmem[2], "mask: lane 1 not written");
         // lane 1 alone: served at addr + stride
         @(negedge clka);
         en = 1; wen = 0; lane_en = 2'b10;
         addr = 3; stride = STRIDE_W'(2);
         #2;
         check("mask: lane 1 alone, no conflict", conflict === 1'b0);
         @(negedge clka);
         idle();
         check("mask: lane 1 alone, data", doa[WIDTH +: WIDTH] === refmem[5]);
         // single active lane, stride % 3 == 0: no pair -> no conflict
         @(negedge clka);
         en = 1; wen = 0; lane_en = 'b1;
         addr = 0; stride = STRIDE_W'(3);
         #2;
         check("mask: single lane never conflicts", conflict === 1'b0);
         @(negedge clka);
         idle();
      end
      $display("phase 5 (partial lane masks) done");

      //--- Phase 5b: byte write enables (the byte-sliced banks) --------
      begin
         logic [WIDTH-1:0] base_w;
         // seed a known word
         base_w = 32'h01234567;
         write_single(7, base_w);
         refmem[7] = base_w;
         // low half only
         @(negedge clka);
         en = 1; wen = 1; lane_en = 'b1; addr = 7; stride = '0;
         ben = '0; ben[1:0] = 2'b11;
         dia[0 +: WIDTH] = 32'hAAAABBBB;
         @(negedge clka);
         idle();
         refmem[7] = {base_w[31:16], 16'hBBBB};
         read_check_single(7, refmem[7], "ben: low half written");
         // single byte, byte 2
         @(negedge clka);
         en = 1; wen = 1; lane_en = 'b1; addr = 7; stride = '0;
         ben = '0; ben[2] = 1'b1;
         dia[0 +: WIDTH] = 32'h00CC0000;
         @(negedge clka);
         idle();
         refmem[7] = {refmem[7][31:24], 8'hCC, refmem[7][15:0]};
         read_check_single(7, refmem[7], "ben: byte 2 written");
         // no byte enabled: the word must not change at all
         @(negedge clka);
         en = 1; wen = 1; lane_en = 'b1; addr = 7; stride = '0;
         ben = '0;
         dia[0 +: WIDTH] = 32'hDEADBEEF;
         @(negedge clka);
         idle();
         read_check_single(7, refmem[7], "ben: empty mask writes nothing");
         // lane 1 carries its own mask on a strided pair
         @(negedge clka);
         en = 1; wen = 1; lane_en = '1; addr = 8; stride = STRIDE_W'(1);
         ben = '0; ben[0] = 1'b1; ben[NB + 3] = 1'b1;   // lane 0 byte 0, lane 1 byte 3
         dia[0 +: WIDTH]     = 32'h00000077;
         dia[WIDTH +: WIDTH] = 32'h88000000;
         @(negedge clka);
         idle();
         refmem[8] = {refmem[8][31:8], 8'h77};
         refmem[9] = {8'h88, refmem[9][23:0]};
         read_check_single(8, refmem[8], "ben: lane 0 mask");
         read_check_single(9, refmem[9], "ben: lane 1 mask");
      end
      $display("phase 5b (byte write enables) done");

      //--- Phase 6: out-of-range --------------------------------------
      // EA0 top-bits check
      @(negedge clka);
      en = 1; wen = 1; lane_en = 'b1;
      addr = WORDS[AW-1:0];
      dia[0 +: WIDTH] = 32'hBAD00BAD;
      #2;
      check("ea0 oob: flagged", oob[0] === 1'b1);
      @(negedge clka);
      idle();
      read_check_single(0, refmem[0], "ea0 oob: aliased cell untouched");
      // truncation-alias trap: 0 + (-20) = -20, truncates to 44 < WORDS
      @(negedge clka);
      en = 1; wen = 1; lane_en = '1;
      addr = '0; stride = STRIDE_W'(-20);
      dia[0 +: WIDTH]     = 32'hDEAD0005;
      dia[WIDTH +: WIDTH] = 32'hBAD00BAD;
      #2;
      check("ea1 alias trap: oob[1] flagged", oob[1] === 1'b1);
      check("ea1 alias trap: lane 0 not flagged", oob[0] === 1'b0);
      @(negedge clka);
      idle();
      refmem[0] = 32'hDEAD0005;                   // lane 0 proceeds
      read_check_single(44, refmem[44], "ea1 alias trap: word 44 untouched");
      read_check_single(0, refmem[0], "ea1 alias trap: word 0 written");
      // overflow above the valid range
      @(negedge clka);
      en = 1; wen = 0; lane_en = '1;
      addr = (WORDS - 1); stride = STRIDE_W'(4);
      #2;
      check("ea1 overflow: oob[1] flagged", oob[1] === 1'b1);
      @(negedge clka);
      idle();
      // conflict is a pure stride function: it co-asserts with oob[1]
      // when stride % 3 == 0 AND EA1 is out of range (oob wins upstream)
      @(negedge clka);
      en = 1; wen = 0; lane_en = '1;
      addr = (WORDS - 1); stride = STRIDE_W'(3);
      #2;
      check("conflict/oob co-assert: oob[1]", oob[1] === 1'b1);
      check("conflict/oob co-assert: conflict", conflict === 1'b1);
      @(negedge clka);
      idle();
      $display("phase 6 (out-of-range, alias trap) done");

      //--- Phase 7: READ_FIRST -- write returns pre-write content -----
      @(negedge clka);
      en = 1; wen = 1; lane_en = 'b1; addr = 2;
      dia[0 +: WIDTH] = 32'hDEAD0006;
      @(negedge clka);
      idle();
      check("read-first: old data during write",
            doa[0 +: WIDTH] === refmem[2]);
      refmem[2] = 32'hDEAD0006;
      read_check_single(2, refmem[2], "read-first: new data afterwards");
      $display("phase 7 (READ_FIRST) done");

      //--- Phase 8: side B (NI) fill and read back ---------------------
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
      @(negedge clkb);
      idle();
      for (int a = 0; a < WORDS; a++) begin
         @(negedge clkb);
         enb = 1; web = 0; addrb = a[AW-1:0];
         @(negedge clkb);
         idle();
         check($sformatf("NI readback: addr %0d read %08h expected %08h",
                         a, dob, refmem[a]), dob === refmem[a]);
      end
      for (int a = 0; a < WORDS; a += 7) begin
         read_check_single(a, refmem[a], "NI-to-core cross-check");
      end
      $display("phase 8 (side B / NI, dual clock) done");

      //--- Phase 9: OUTREG = 1 variant ----------------------------------
      // Writes are single-cycle; reads keep the enable asserted for TWO
      // cycles (the dpmemrf output register is enable-gated), data is
      // valid after the second enabled edge.
      for (int a = 0; a < WORDS; a++) begin
         @(negedge clka);
         en_r = 1; wen_r = 1; addr_r = a[AW-1:0];
         dia_r = '0;
         dia_r[0 +: WIDTH] = pattern(a) ^ 32'h5A5A5A5A;
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
                         a, doa_r[0 +: WIDTH], pattern(a) ^ 32'h5A5A5A5A),
               doa_r[0 +: WIDTH] === (pattern(a) ^ 32'h5A5A5A5A));
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
      $display("phase 9 (OUTREG=1 variant, 2-cycle reads) done");

      //--- Phase 10: ADRREG = 1 variant ---------------------------------
      // The address phase is registered: writes commit one cycle later,
      // reads return 2 cycles after the access (single-cycle enable, no
      // enable-extension protocol). conflict/oob stay combinational.
      for (int a = 0; a < WORDS; a++) begin
         @(negedge clka);
         en_p = 1; wen_p = 1; lane_en_p = 'b1; addr_p = a[AW-1:0];
         dia_p = '0;
         dia_p[0 +: WIDTH] = pattern(a) ^ 32'h3C3C3C3C;
         @(negedge clka);
         idle_p();
      end
      for (int a = 0; a < WORDS; a++) begin
         @(negedge clka);
         en_p = 1; wen_p = 0; lane_en_p = 'b1; addr_p = a[AW-1:0];
         @(negedge clka);
         idle_p();
         @(negedge clka);              // data valid 2 cycles after access
         check($sformatf("adrreg: addr %0d read %08h expected %08h",
                         a, doa_p[0 +: WIDTH], pattern(a) ^ 32'h3C3C3C3C),
               doa_p[0 +: WIDTH] === (pattern(a) ^ 32'h3C3C3C3C));
      end
      // pair read through the pipeline, stride % 3 != 0
      @(negedge clka);
      en_p = 1; wen_p = 0; lane_en_p = '1;
      addr_p = 6; stride_p = STRIDE_W'(2);
      #2;
      check("adrreg pair: no conflict", conflict_p === 1'b0);
      check("adrreg pair: no oob", oob_p === '0);
      @(negedge clka);
      idle_p();
      @(negedge clka);
      check("adrreg pair: lane 0 data",
            doa_p[0 +: WIDTH] === (pattern(6) ^ 32'h3C3C3C3C));
      check("adrreg pair: lane 1 data",
            doa_p[WIDTH +: WIDTH] === (pattern(8) ^ 32'h3C3C3C3C));
      // conflict and oob are still reported in the ISSUE cycle
      @(negedge clka);
      en_p = 1; wen_p = 0; lane_en_p = '1;
      addr_p = 0; stride_p = STRIDE_W'(3);
      #2;
      check("adrreg: conflict combinational in issue cycle",
            conflict_p === 1'b1);
      @(negedge clka);
      idle_p();
      @(negedge clka);
      $display("phase 10 (ADRREG=1 variant, 2-cycle reads) done");

      //--- Phase 11: serialization across all ADRREG x OUTREGA --------
      // The replay register is timed by SER_D = ADRREG + 1 + OUTREGA,
      // so a conflicting pair has to be checked in every configuration.
      // The core is modelled faithfully: it holds its inputs for the
      // freeze cycle, then issues an unrelated bundle (en low) -- which
      // is what stops an enable-gated bank output register from
      // advancing if the replay depends on it.
      begin
         int ser_d, va, vb;
         idle_s();
         // fill the words the pair will touch, on every sweep DUT at once
         for (int a = 0; a < 16; a++) begin
            @(negedge clka);
            en_s = 1; wen_s = 1; lane_en_s = 'b1; addr_s = a[AW-1:0];
            stride_s = '0; ben_s = '1;
            dia_s[0 +: WIDTH] = pattern(a);
            @(negedge clka);
            idle_s();
         end

         for (int g = 0; g < 4; g++) begin
            ser_d = (g % 2) + 1 + (g / 2);        // ADRREG + 1 + OUTREGA
            va = 6; vb = 9;                       // stride 3: same bank
            // conflicting pair
            @(negedge clka);
            en_s = 1; wen_s = 0; lane_en_s = '1;
            addr_s = va[AW-1:0]; stride_s = STRIDE_W'(3);
            @(negedge clka);                      // frozen: core holds
            #2;
            check($sformatf("sweep g%0d (ADRREG=%0d OUTREGA=%0d): freeze",
                            g, g % 2, g / 2), freeze_s[g] === 1'b1);
            @(negedge clka);
            idle_s();                             // core resumes elsewhere
            // the pair presents SER_D cycles after the second access
            repeat (ser_d - 1) @(negedge clka);
            check($sformatf("sweep g%0d (ADRREG=%0d OUTREGA=%0d): lane 0 = %08h exp %08h",
                            g, g % 2, g / 2, doa_s[g][0 +: WIDTH], pattern(va)),
                  doa_s[g][0 +: WIDTH] === pattern(va));
            check($sformatf("sweep g%0d (ADRREG=%0d OUTREGA=%0d): lane 1 = %08h exp %08h",
                            g, g % 2, g / 2, doa_s[g][WIDTH +: WIDTH], pattern(vb)),
                  doa_s[g][WIDTH +: WIDTH] === pattern(vb));
            repeat (3) @(negedge clka);
            idle_s();
         end
      end
      $display("phase 11 (serialization across ADRREG x OUTREGA) done");

      //--- Summary ------------------------------------------------------
      if (errors == 0) begin
         $display("parmem3_2_tb: ALL TESTS PASSED (%0d words, DEPTH=%0d)",
                  WORDS, DEPTH);
      end
      else begin
         $display("parmem3_2_tb: FAILED with %0d error(s)", errors);
      end
      $finish;
   end


endmodule // parmem3_2_tb
