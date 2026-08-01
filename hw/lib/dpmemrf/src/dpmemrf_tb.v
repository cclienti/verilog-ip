// SPDX-License-Identifier: CERN-OHL-P-2.0
// Copyright (c) 2013-2026 Christophe Clienti
//
// This source describes Open Hardware and is licensed under the CERN-OHL-P v2.
// You may redistribute and modify this file under the terms of the CERN-OHL-P v2
// (https://ohwr.org/cern_ohl_p_v2.txt).
//
// This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING
// OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A PARTICULAR PURPOSE.
// Please see the CERN-OHL-P v2 for applicable conditions.



`timescale 1 ns / 100 ps

// Self-checking testbench for dpmemrf. Three instances cover the
// configuration space that matters:
//
//   u_plain  BYTE_WE=0 OUTREGA=0 OUTREGB=0   1-cycle reads, word writes
//   u_reg    BYTE_WE=0 OUTREGA=1 OUTREGB=1   2-cycle reads, enable-gated
//   u_be     BYTE_WE=1 OUTREGA=0 OUTREGB=0   per-byte write enables
//
// Phases:
//   1. port A bijection: fill the whole depth, read every word back
//   2. READ_FIRST on port A -- a write returns the pre-write content
//   3. port B bijection on its own, unrelated clock
//   4. cross-port: written on B, read on A (and the converse)
//   5. enable gating -- the output register holds while en is low
//   6. OUTREG variant: 2-cycle reads and the extra hold cycle
//   7. byte write enables: full, half, single byte, empty mask
//   8. byte write enables on side B
//
// The two clocks are deliberately unrelated in period so that nothing
// in the dual-port behaviour depends on their alignment.

module dpmemrf_tb();

   parameter DEPTH = 6;
   parameter WIDTH = 32;

   localparam WORDS = 1 << DEPTH;
   localparam NB    = WIDTH / 8;

   integer          errors = 0;

   // ---- u_plain: BYTE_WE = 0, no output registers -----------------
   reg              clka, clkb;
   reg              ena, wea;
   reg [DEPTH-1:0]  addra;
   reg [WIDTH-1:0]  dia;
   wire [WIDTH-1:0] doa;
   reg              enb, web;
   reg [DEPTH-1:0]  addrb;
   reg [WIDTH-1:0]  dib;
   wire [WIDTH-1:0] dob;

   // ---- u_reg: BYTE_WE = 0, both output registers ------------------
   reg              ena_r, wea_r;
   reg [DEPTH-1:0]  addra_r;
   reg [WIDTH-1:0]  dia_r;
   wire [WIDTH-1:0] doa_r;
   reg              enb_r, web_r;
   reg [DEPTH-1:0]  addrb_r;
   reg [WIDTH-1:0]  dib_r;
   wire [WIDTH-1:0] dob_r;

   // ---- u_be: BYTE_WE = 1 ------------------------------------------
   reg              ena_e;
   reg [NB-1:0]     wea_e;
   reg [DEPTH-1:0]  addra_e;
   reg [WIDTH-1:0]  dia_e;
   wire [WIDTH-1:0] doa_e;
   reg              enb_e;
   reg [NB-1:0]     web_e;
   reg [DEPTH-1:0]  addrb_e;
   reg [WIDTH-1:0]  dib_e;
   wire [WIDTH-1:0] dob_e;

   reg [WIDTH-1:0]  refmem [0:WORDS-1];


   dpmemrf #(.DEPTH(DEPTH), .WIDTH(WIDTH), .BYTE_WE(0),
             .OUTREGA(0), .OUTREGB(0))
   u_plain (.clka(clka), .ena(ena), .wea(wea),
            .addra(addra), .dia(dia), .doa(doa),
            .clkb(clkb), .enb(enb), .web(web),
            .addrb(addrb), .dib(dib), .dob(dob));

   dpmemrf #(.DEPTH(DEPTH), .WIDTH(WIDTH), .BYTE_WE(0),
             .OUTREGA(1), .OUTREGB(1))
   u_reg (.clka(clka), .ena(ena_r), .wea(wea_r),
          .addra(addra_r), .dia(dia_r), .doa(doa_r),
          .clkb(clkb), .enb(enb_r), .web(web_r),
          .addrb(addrb_r), .dib(dib_r), .dob(dob_r));

   dpmemrf #(.DEPTH(DEPTH), .WIDTH(WIDTH), .BYTE_WE(1),
             .OUTREGA(0), .OUTREGB(0))
   u_be (.clka(clka), .ena(ena_e), .wea(wea_e),
         .addra(addra_e), .dia(dia_e), .doa(doa_e),
         .clkb(clkb), .enb(enb_e), .web(web_e),
         .addrb(addrb_e), .dib(dib_e), .dob(dob_e));

   //----------------------------------------------------------------
   // Clocks (unrelated periods on purpose)
   //----------------------------------------------------------------
   initial begin
      clka = 1'b0;
      clkb = 1'b0;
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
   function automatic [WIDTH-1:0] pattern(input integer a);
      pattern = 32'hC0DE0000 + a[15:0] * 16'h0111;
   endfunction

   function automatic [WIDTH-1:0] pattern_b(input integer a);
      pattern_b = 32'h5A5A0000 + a[15:0] * 16'h0017;
   endfunction

   task automatic check(input string what, input bit cond);
      if (!cond) begin
         errors = errors + 1;
         $display("Error: %s (time %0t)", what, $time);
      end
   endtask

   task automatic idle_a();
      ena = 0; wea = 0; addra = '0; dia = '0;
   endtask

   task automatic idle_b();
      enb = 0; web = 0; addrb = '0; dib = '0;
   endtask

   task automatic idle_r();
      ena_r = 0; wea_r = 0; addra_r = '0; dia_r = '0;
      enb_r = 0; web_r = 0; addrb_r = '0; dib_r = '0;
   endtask

   task automatic idle_e();
      ena_e = 0; wea_e = '0; addra_e = '0; dia_e = '0;
      enb_e = 0; web_e = '0; addrb_e = '0; dib_e = '0;
   endtask

   // ---- port A of u_plain -----------------------------------------
   task automatic a_write(input integer a, input [WIDTH-1:0] d);
      @(negedge clka);
      ena = 1; wea = 1; addra = a[DEPTH-1:0]; dia = d;
      @(negedge clka);
      idle_a();
   endtask

   task automatic a_read_check(input integer a, input [WIDTH-1:0] exp,
                               input string what);
      @(negedge clka);
      ena = 1; wea = 0; addra = a[DEPTH-1:0];
      @(negedge clka);
      idle_a();
      check($sformatf("%s: addr %0d read %08h expected %08h",
                      what, a, doa, exp), doa === exp);
   endtask

   // ---- port A of u_be --------------------------------------------
   task automatic e_write(input integer a, input [WIDTH-1:0] d,
                          input [NB-1:0] m);
      @(negedge clka);
      ena_e = 1; wea_e = m; addra_e = a[DEPTH-1:0]; dia_e = d;
      @(negedge clka);
      idle_e();
   endtask

   task automatic e_read_check(input integer a, input [WIDTH-1:0] exp,
                               input string what);
      @(negedge clka);
      ena_e = 1; wea_e = '0; addra_e = a[DEPTH-1:0];
      @(negedge clka);
      idle_e();
      check($sformatf("%s: addr %0d read %08h expected %08h",
                      what, a, doa_e, exp), doa_e === exp);
   endtask

   //----------------------------------------------------------------
   // Test sequence
   //----------------------------------------------------------------
   initial begin
      reg [WIDTH-1:0] held, seed;
      integer         a;

      idle_a();
      idle_b();
      idle_r();
      idle_e();
      @(posedge clka);

      //--- Phase 1: port A bijection ------------------------------
      for (a = 0; a < WORDS; a = a + 1) begin
         a_write(a, pattern(a));
         refmem[a] = pattern(a);
      end
      for (a = 0; a < WORDS; a = a + 1) begin
         a_read_check(a, refmem[a], "phase1 bijection");
      end
      $display("phase 1 (port A bijection, %0d words) done", WORDS);

      //--- Phase 2: READ_FIRST on port A --------------------------
      @(negedge clka);
      ena = 1; wea = 1; addra = 5; dia = 32'hFEED0005;
      @(negedge clka);
      idle_a();
      check($sformatf("phase2 READ_FIRST: got %08h expected %08h",
                      doa, refmem[5]), doa === refmem[5]);
      refmem[5] = 32'hFEED0005;
      a_read_check(5, refmem[5], "phase2 new content");
      $display("phase 2 (READ_FIRST) done");

      //--- Phase 3: port B bijection, own clock -------------------
      for (a = 0; a < WORDS; a = a + 1) begin
         @(negedge clkb);
         enb = 1; web = 1; addrb = a[DEPTH-1:0]; dib = pattern_b(a);
         refmem[a] = pattern_b(a);
         @(negedge clkb);
         idle_b();
      end
      for (a = 0; a < WORDS; a = a + 1) begin
         @(negedge clkb);
         enb = 1; web = 0; addrb = a[DEPTH-1:0];
         @(negedge clkb);
         idle_b();
         check($sformatf("phase3 port B: addr %0d read %08h expected %08h",
                         a, dob, refmem[a]), dob === refmem[a]);
      end
      // READ_FIRST holds on port B too: a write returns the pre-write word
      @(negedge clkb);
      enb = 1; web = 1; addrb = 7; dib = 32'hB00B0007;
      @(negedge clkb);
      idle_b();
      check($sformatf("phase3 READ_FIRST on B: got %08h expected %08h",
                      dob, refmem[7]), dob === refmem[7]);
      refmem[7] = 32'hB00B0007;
      @(negedge clkb);
      enb = 1; web = 0; addrb = 7;
      @(negedge clkb);
      idle_b();
      check($sformatf("phase3 B new content: got %08h expected %08h",
                      dob, refmem[7]), dob === refmem[7]);
      $display("phase 3 (port B bijection, own clock) done");

      //--- Phase 4: cross-port ------------------------------------
      // written through B above, read through A here
      for (a = 0; a < WORDS; a = a + 8) begin
         a_read_check(a, refmem[a], "phase4 B->A");
      end
      // written through A, read through B
      a_write(9, 32'hA5A50009);
      refmem[9] = 32'hA5A50009;
      @(negedge clkb);
      enb = 1; web = 0; addrb = 9;
      @(negedge clkb);
      idle_b();
      check($sformatf("phase4 A->B: read %08h expected %08h",
                      dob, refmem[9]), dob === refmem[9]);
      $display("phase 4 (cross-port) done");

      //--- Phase 5: enable gating holds the output ----------------
      @(negedge clka);
      ena = 1; wea = 0; addra = 3;
      @(negedge clka);
      idle_a();
      held = doa;
      check($sformatf("phase5 seed: read %08h expected %08h",
                      held, refmem[3]), held === refmem[3]);
      // en low, address moved: the output must not follow
      @(negedge clka);
      ena = 0; wea = 0; addra = 4;
      @(negedge clka);
      idle_a();
      check($sformatf("phase5 hold: %08h drifted (addr 4 is %08h)",
                      doa, refmem[4]), doa === held);
      $display("phase 5 (enable gating) done");

      //--- Phase 6: OUTREG variant, 2-cycle reads -----------------
      // Seed two words, then read the first one out completely so that
      // doa_r holds a known value distinct from the second.
      @(negedge clka);
      ena_r = 1; wea_r = 1; addra_r = 12; dia_r = 32'h1234ABCD;
      @(negedge clka);
      ena_r = 1; wea_r = 1; addra_r = 13; dia_r = 32'h99998888;
      @(negedge clka);
      idle_r();
      // a read needs the enable held for two cycles with OUTREG = 1
      @(negedge clka);
      ena_r = 1; wea_r = 0; addra_r = 12;
      @(negedge clka);
      ena_r = 1; wea_r = 0; addra_r = 12;
      @(negedge clka);
      idle_r();
      check($sformatf("phase6 OUTREG read: %08h expected 1234ABCD", doa_r),
            doa_r === 32'h1234ABCD);

      // The output register is enable-gated, a contract the callers rely
      // on: a read issued for a SINGLE cycle loads doa_reg but does not
      // flush it to doa. doa must therefore still show word 12 -- if the
      // gating were dropped, word 13 would appear one cycle after the
      // enable falls.
      @(negedge clka);
      ena_r = 1; wea_r = 0; addra_r = 13;   // one enable cycle only
      @(negedge clka);
      idle_r();
      @(negedge clka);                      // an ungated doa would flush here
      check($sformatf("phase6 OUTREG gating: %08h leaked (expected 1234ABCD)",
                      doa_r), doa_r === 32'h1234ABCD);

      // hold the enable long enough and word 13 comes out
      @(negedge clka);
      ena_r = 1; wea_r = 0; addra_r = 13;
      @(negedge clka);
      ena_r = 1; wea_r = 0; addra_r = 13;
      @(negedge clka);
      idle_r();
      check($sformatf("phase6 OUTREG flush: %08h expected 99998888", doa_r),
            doa_r === 32'h99998888);
      $display("phase 6 (OUTREG = 1 variant) done");

      //--- Phase 7: byte write enables ----------------------------
      seed = 32'h01234567;
      e_write(20, seed, {NB{1'b1}});          // full mask
      refmem[20] = seed;
      e_read_check(20, refmem[20], "phase7 full mask");

      e_write(20, 32'hAAAABBBB, 4'b0011);     // low half only
      refmem[20] = {seed[31:16], 16'hBBBB};
      e_read_check(20, refmem[20], "phase7 low half");

      e_write(20, 32'h00CC0000, 4'b0100);     // byte 2 only
      refmem[20] = {refmem[20][31:24], 8'hCC, refmem[20][15:0]};
      e_read_check(20, refmem[20], "phase7 byte 2");

      e_write(20, 32'hDEADBEEF, 4'b0000);     // empty mask: no write
      e_read_check(20, refmem[20], "phase7 empty mask");

      e_write(20, 32'h11223344, 4'b1000);     // top byte only
      refmem[20] = {8'h11, refmem[20][23:0]};
      e_read_check(20, refmem[20], "phase7 byte 3");
      $display("phase 7 (byte write enables, port A) done");

      //--- Phase 8: byte write enables on side B ------------------
      @(negedge clkb);
      enb_e = 1; web_e = 4'b0110; addrb_e = 20; dib_e = 32'h00778800;
      @(negedge clkb);
      idle_e();
      refmem[20] = {refmem[20][31:24], 8'h77, 8'h88, refmem[20][7:0]};
      e_read_check(20, refmem[20], "phase8 side B mask");
      $display("phase 8 (byte write enables, side B) done");

      //--- Verdict ------------------------------------------------
      repeat (4) @(negedge clka);
      if (errors == 0) begin
         $display("dpmemrf_tb: ALL TESTS PASSED (%0d words, DEPTH=%0d)",
                  WORDS, DEPTH);
      end
      else begin
         $display("dpmemrf_tb: %0d ERROR(S)", errors);
      end
      $finish;
   end

endmodule
