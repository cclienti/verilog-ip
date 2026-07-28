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

// Self-checking testbench for parmem5_2 (5 banks, 2 lanes).
// Phases:
//   1. bijection: single-lane fill, single-lane read back
//   2. pair read, signed strides with stride % 5 != 0: no conflict,
//      both active lanes correct
//   3. stride % 5 == 0 (including 0): conflict, lane 0 wins
//   4. pair write, verified by read-back
//   5. partial lane masks: disabled lanes have no side effects;
//      single active lane never conflicts
//   6. out-of-range: per-lane oob (including the truncation-alias trap
//      with negative strides), suppressed individually
//   7. side B (NI, own clock): linear fill + read back, cross-checked
//      against side A
//   8. ADRREG = 1 variant: address-phase pipeline register, 2-cycle
//      reads, conflict/oob still combinational in the issue cycle

module parmem5_2_tb();

   parameter DEPTH    = 4;
   parameter WIDTH    = 32;
   parameter STRIDE_W = 6;

   localparam NB_BANKS = 5;
   localparam NB_LANES = 2;
   localparam AW       = DEPTH + 3;
   localparam WORDS    = NB_BANKS * (1 << DEPTH);

   logic                      clka, clkb;
   logic                      en, wen;
   logic [NB_LANES-1:0]       lane_en;
   logic [AW-1:0]             addr;
   logic [STRIDE_W-1:0]       stride;
   logic [NB_LANES*WIDTH-1:0] dia;
   logic [NB_LANES*WIDTH-1:0] doa;
   logic                      conflict;
   logic [NB_LANES-1:0]       oob;

   logic                      enb, web;
   logic [AW-1:0]             addrb;
   logic [WIDTH-1:0]          dib;
   logic [WIDTH-1:0]          dob;
   logic                      oobb;

   int                        errors = 0;

   logic [WIDTH-1:0]          refmem [0:WORDS-1];


   parmem5_2 #(.DEPTH(DEPTH), .WIDTH(WIDTH), .STRIDE_W(STRIDE_W),
               .OUTREGA(0), .OUTREGB(0))
   parmem5_2_inst (.clka(clka), .en(en), .wen(wen), .lane_en(lane_en),
                   .addr(addr), .stride(stride), .dia(dia), .doa(doa),
                   .conflict(conflict), .oob(oob),
                   .clkb(clkb), .enb(enb), .web(web), .addrb(addrb),
                   .dib(dib), .dob(dob), .oobb(oobb));

   // ADRREG = 1 variant: address-phase pipeline register, 2-cycle reads
   logic                      en_p, wen_p;
   logic [NB_LANES-1:0]       lane_en_p;
   logic [AW-1:0]             addr_p;
   logic [STRIDE_W-1:0]       stride_p;
   logic [NB_LANES*WIDTH-1:0] dia_p, doa_p;
   logic                      conflict_p;
   logic [NB_LANES-1:0]       oob_p;

   parmem5_2 #(.DEPTH(DEPTH), .WIDTH(WIDTH), .STRIDE_W(STRIDE_W),
               .ADRREG(1), .OUTREGA(0), .OUTREGB(0))
   parmem5_2_adr_inst (.clka(clka), .en(en_p), .wen(wen_p),
                       .lane_en(lane_en_p), .addr(addr_p),
                       .stride(stride_p), .dia(dia_p), .doa(doa_p),
                       .conflict(conflict_p), .oob(oob_p),
                       .clkb(clkb), .enb(1'b0), .web(1'b0), .addrb('0),
                       .dib('0), .dob(), .oobb());

   //----------------------------------------------------------------
   // VCD
   //----------------------------------------------------------------
   initial begin
      $dumpfile("parmem5_2_tb.vcd");
      $dumpvars(0, parmem5_2_tb);
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
      en = 0; wen = 0; lane_en = '0; addr = '0; stride = '0; dia = '0;
      enb = 0; web = 0; addrb = '0; dib = '0;
   endtask

   task automatic idle_p();
      en_p = 0; wen_p = 0; lane_en_p = '0; addr_p = '0; stride_p = '0;
      dia_p = '0;
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

   // all lane EAs in range?
   function automatic bit group_in_range(input int a, input int s,
                                         input logic [NB_LANES-1:0] mask);
      for (int i = 0; i < NB_LANES; i++) begin
         if (mask[i] && (a + i * s < 0 || a + i * s >= WORDS)) begin
            return 0;
         end
      end
      return 1;
   endfunction

   //----------------------------------------------------------------
   // Test sequence
   //----------------------------------------------------------------
   initial begin
      int s, ea, a0, s_neg, smax;
      idle();
      idle_p();
      @(posedge clka);

      //--- Phase 1: fill (single-lane), read back (single-lane) -------
      for (int a = 0; a < WORDS; a++) begin
         write_single(a, pattern(a));
         refmem[a] = pattern(a);
      end
      for (int a = 0; a < WORDS; a++) begin
         read_check_single(a, refmem[a], "bijection");
      end
      $display("phase 1 (bijection, %0d words, M=%0d) done",
               WORDS, NB_BANKS);

      //--- Phase 2: pair read, signed strides, stride %% 5 != 0 -------
      // clamp the sweep to the signed stride field range
      smax = 2 * NB_BANKS + 1;
      if (smax > (1 << (STRIDE_W - 1)) - 1) begin
         smax = (1 << (STRIDE_W - 1)) - 1;
      end
      for (s = -smax; s <= smax; s++) begin
         if (s % NB_BANKS == 0) continue;
         for (int a = 0; a < WORDS; a++) begin
            if (!group_in_range(a, s, '1)) continue;
            @(negedge clka);
            en = 1; wen = 0; lane_en = '1;
            addr = a[AW-1:0]; stride = s[STRIDE_W-1:0];
            #2;
            check($sformatf("s %0d a %0d: conflict", s, a),
                  conflict === 1'b0);
            check($sformatf("s %0d a %0d: oob", s, a), oob === '0);
            @(negedge clka);
            idle();
            for (int i = 0; i < NB_LANES; i++) begin
               check($sformatf("s %0d a %0d: lane %0d data", s, a, i),
                     doa[i*WIDTH +: WIDTH] === refmem[a + i * s]);
            end
         end
      end
      $display("phase 2 (pair read, stride %% 5 != 0) done");

      //--- Phase 3: stride %% 5 == 0 -> conflict, lane 0 wins ---------
      for (s = -NB_BANKS; s <= NB_BANKS; s += NB_BANKS) begin
         for (int a = 0; a < WORDS; a += 7) begin
            if (!group_in_range(a, s, '1)) continue;
            @(negedge clka);
            en = 1; wen = 0; lane_en = '1;
            addr = a[AW-1:0]; stride = s[STRIDE_W-1:0];
            #2;
            check($sformatf("s %0d a %0d: conflict expected", s, a),
                  conflict === 1'b1);
            @(negedge clka);
            idle();
            check($sformatf("s %0d a %0d: lane 0 wins", s, a),
                  doa[0 +: WIDTH] === refmem[a]);
         end
      end
      $display("phase 3 (stride %% 5 == 0, conflicts) done");

      //--- Phase 4: pair write, verified by read-back -----------------
      for (s = 1; s <= NB_BANKS + 2; s += NB_BANKS - 1) begin
         if (s % NB_BANKS == 0) continue;
         for (int a = 0; a < WORDS; a += 2 * NB_LANES + 1) begin
            if (!group_in_range(a, s, '1)) continue;
            @(negedge clka);
            en = 1; wen = 1; lane_en = '1;
            addr = a[AW-1:0]; stride = s[STRIDE_W-1:0];
            for (int i = 0; i < NB_LANES; i++) begin
               dia[i*WIDTH +: WIDTH] = pattern(a + i * s) ^ 32'h0F0F0F0F;
            end
            #2;
            check($sformatf("stn s %0d a %0d: conflict", s, a),
                  conflict === 1'b0);
            @(negedge clka);
            idle();
            for (int i = 0; i < NB_LANES; i++) begin
               refmem[a + i * s] = pattern(a + i * s) ^ 32'h0F0F0F0F;
            end
            for (int i = 0; i < NB_LANES; i++) begin
               read_check_single(a + i * s, refmem[a + i * s],
                                 $sformatf("stn s %0d lane %0d", s, i));
            end
         end
      end
      $display("phase 4 (pair write) done");

      //--- Phase 5: partial lane masks ---------------------------------
      begin
         // disabled lane must have no side effect on a pair write
         @(negedge clka);
         en = 1; wen = 1; lane_en = 'b1;   // lane 0 only
         addr = 1; stride = STRIDE_W'(1);
         dia = '1;                          // garbage on all lanes
         dia[0 +: WIDTH] = 32'hDEAD0010;
         @(negedge clka);
         idle();
         refmem[1] = 32'hDEAD0010;
         read_check_single(1, refmem[1], "mask: lane 0 write landed");
         read_check_single(2, refmem[2], "mask: lane 1 not written");
         // single active lane, stride % 5 == 0: no pair -> no conflict
         @(negedge clka);
         en = 1; wen = 0; lane_en = 'b1;
         addr = 0; stride = STRIDE_W'(NB_BANKS);
         #2;
         check("mask: single lane never conflicts", conflict === 1'b0);
         @(negedge clka);
         idle();
      end
      $display("phase 5 (partial lane masks) done");

      //--- Phase 6: out-of-range, per lane -----------------------------
      // last lane overflows, lane 0 proceeds
      begin
         a0 = WORDS - 1;
         @(negedge clka);
         en = 1; wen = 0; lane_en = '1;
         addr = a0[AW-1:0]; stride = STRIDE_W'(1);
         #2;
         check("oob: lane 1 flagged", oob[1] === 1'b1);
         check("oob: lane 0 clean", oob[0] === 1'b0);
         @(negedge clka);
         idle();
         check("oob: lane 0 data valid", doa[0 +: WIDTH] === refmem[a0]);
      end
      // negative stride, truncation-alias trap: suppressed write
      begin
         s_neg = -(WORDS + NB_BANKS - 1);  // EA1 < 0 for addr 0
         if (s_neg >= -(1 << (STRIDE_W - 1))) begin
            @(negedge clka);
            en = 1; wen = 1; lane_en = 2'b11;
            addr = '0; stride = s_neg[STRIDE_W-1:0];
            dia[0 +: WIDTH] = 32'hDEAD0011;
            dia[WIDTH +: WIDTH] = 32'hBAD00BAD;
            #2;
            check("alias trap: lane 1 oob", oob[1] === 1'b1);
            check("alias trap: lane 0 clean", oob[0] === 1'b0);
            @(negedge clka);
            idle();
            refmem[0] = 32'hDEAD0011;
            read_check_single(0, refmem[0], "alias trap: lane 0 written");
            // scan whole memory: no cell may hold the trap pattern
            for (int a = 1; a < WORDS; a++) begin
               check($sformatf("alias trap: cell %0d untouched", a),
                     refmem[a] !== 32'hBAD00BAD);
            end
         end
      end
      $display("phase 6 (out-of-range, alias trap) done");

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
      @(negedge clkb);
      idle();
      for (int a = 0; a < WORDS; a++) begin
         @(negedge clkb);
         enb = 1; web = 0; addrb = a[AW-1:0];
         @(negedge clkb);
         idle();
         check($sformatf("NI readback: addr %0d", a), dob === refmem[a]);
      end
      for (int a = 0; a < WORDS; a += 7) begin
         read_check_single(a, refmem[a], "NI-to-core cross-check");
      end
      $display("phase 7 (side B / NI, dual clock) done");

      //--- Phase 8: ADRREG = 1 variant ---------------------------------
      // The address phase is registered: writes commit one cycle later,
      // reads return 2 cycles after the access (single-cycle enable).
      // conflict/oob stay combinational in the issue cycle.
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
      // pair read through the pipeline, stride % 5 != 0
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
      // conflict is still reported in the ISSUE cycle
      @(negedge clka);
      en_p = 1; wen_p = 0; lane_en_p = '1;
      addr_p = 0; stride_p = STRIDE_W'(NB_BANKS);
      #2;
      check("adrreg: conflict combinational in issue cycle",
            conflict_p === 1'b1);
      @(negedge clka);
      idle_p();
      @(negedge clka);
      $display("phase 8 (ADRREG=1 variant, 2-cycle reads) done");

      //--- Summary ------------------------------------------------------
      if (errors == 0) begin
         $display("parmem5_2_tb: ALL TESTS PASSED (%0d words)", WORDS);
      end
      else begin
         $display("parmem5_2_tb: FAILED with %0d error(s)", errors);
      end
      $finish;
   end


endmodule // parmem5_2_tb
