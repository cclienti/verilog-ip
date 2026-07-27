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

// Parallel memory for a dual load/store (LD2/ST2) unit:
// 3 prime-interleaved banks on true-dual-port dual-clock BRAM (dpmemrf,
// READ_FIRST), accessed as a strided pair from ONE instruction:
//
//   dual = 0 :  single access  at EA0 = addr
//   dual = 1 :  pair access    at EA0 = addr and EA1 = addr + stride
//               (both accesses share `wen`: two loads or two stores)
//
// CRT addressing, no divider: bank = EA mod 3, index = EA[DEPTH-1:0]
// (bijective since gcd(3, 2^DEPTH) = 1). The pair conflicts exactly when
// stride is a multiple of 3; power-of-2 strides never conflict. On
// conflict, access 0 is served and access 1 is dropped -- `conflict` is
// the caller's request to serialize. It is a pure function of the stride
// residue (deliberately not gated by oob*, keeping the EA1 adder out of
// its cone); it may assert together with oob1, in which case the oob
// trap takes precedence in the caller.
//
// bank1 computation (PARRES parameter):
//   PARRES = 0: bank1 = mod3(EA1) -- the adder and the mod-3 tree are in
//               series on the address path.
//   PARRES = 1: bank1 = (bank0 + stride) mod 3, computed IN PARALLEL with
//               the EA1 adder (mod is a homomorphism); a sign-correction
//               constant accounts for the two's-complement representation
//               (the raw-pattern residue is off by 2^STRIDE_W mod 3 when
//               stride is negative).
// Both are functionally identical; PARRES exists to measure the timing
// difference of the two implementations.
//
// EA1 is range-checked at FULL width before truncation: a negative or
// overflowing EA1 can alias an in-range address after truncation (e.g.
// DEPTH=4: 0 + (-20) truncates to 44 < 48). Out-of-range accesses are
// reported on oob0/oob1 and suppressed.
//
// Side B is a single linear-addressed port with its own clock and CRT
// decode (network interface): single requester, no conflicts, no muxes
// (address/data broadcast, enable gating only).
//
// Reads are synchronous: 1 cycle (2 with OUTREG* = 1; the dpmemrf output
// register is enable-gated -- keep the port enabled one extra cycle to
// flush). READ_FIRST: a write returns the pre-write cell content.

module parmem3
  #(parameter DEPTH    = 10,  //log2 of words per bank; 3*2^DEPTH words total
    parameter WIDTH    = 32,
    parameter STRIDE_W = 12,  //signed stride width, in words; <= DEPTH+2
    parameter OUTREGA  = 0,   //extra side-A output register (fmax option)
    parameter OUTREGB  = 0,   //extra side-B output register (fmax option)
    parameter PARRES   = 1)   //bank1: 1 = parallel residue, 0 = mod3(EA1)

   (//Side A: one dual load/store access pair
    input  logic                clka,
    input  logic                en,
    input  logic                wen,     //shared: 2 loads or 2 stores
    input  logic                dual,    //0: single access at addr
    input  logic [DEPTH+1:0]    addr,
    input  logic [STRIDE_W-1:0] stride,  //signed, in words
    input  logic [WIDTH-1:0]    dia0,
    input  logic [WIDTH-1:0]    dia1,
    output logic [WIDTH-1:0]    doa0,
    output logic [WIDTH-1:0]    doa1,

    output logic                conflict, //stride % 3 == 0: serialize
    output logic                oob0,     //EA0 out of range, suppressed
    output logic                oob1,     //EA1 out of range, suppressed

    //Side B: single linear-addressed port (network interface)
    input  logic                clkb,
    input  logic                enb,
    input  logic                web,
    input  logic [DEPTH+1:0]    addrb,
    input  logic [WIDTH-1:0]    dib,
    output logic [WIDTH-1:0]    dob,
    output logic                oobb);

   localparam AW = DEPTH + 2;        //linear address width, 3*2^DEPTH < 2^AW
   localparam CM = (STRIDE_W % 2 == 0) ? 1 : 2;  // 2^STRIDE_W mod 3


   //----------------------------------------------------------------
   // mod-3 digit-sum tree (casting out threes, base-4 digits) and
   // small mod-3 adder (both synthesize to LUT trees)
   //----------------------------------------------------------------
   function automatic logic [1:0] mod3(input logic [31:0] a);
      int unsigned s;
      begin
         s = 0;
         for (int i = 0; i < 32; i += 2) begin
            s += {30'b0, a[i+1], a[i]};
         end
         s = (s & 3) + ((s >> 2) & 3) + ((s >> 4) & 3);
         if (s >= 6) s -= 6;
         if (s >= 3) s -= 3;
         return s[1:0];
      end
   endfunction

   function automatic logic [1:0] mod3_add(input logic [1:0] a, b);
      logic [2:0] s;
      begin
         s = {1'b0, a} + {1'b0, b};
         if (s >= 3) begin
            s = s - 3;
         end
         return s[1:0];
      end
   endfunction


   //----------------------------------------------------------------
   // Effective addresses: EA0 = addr, EA1 = addr + stride
   // (full-width computation, range check before truncation)
   //----------------------------------------------------------------
   logic signed [AW:0] ea1_full;
   logic [DEPTH-1:0]   idx0, idx1;

   assign ea1_full = $signed({1'b0, addr})
                     + (AW + 1)'($signed(stride));
   assign idx0 = addr[DEPTH-1:0];
   assign idx1 = ea1_full[DEPTH-1:0];

   assign oob0 = en & (addr[AW-1:AW-2] == 2'b11);
   // full-width range test as a pure 3-bit check on the sum -- no second
   // carry chain after the adder: negative <=> sign bit; >= 3*2^DEPTH
   // <=> both top bits of the in-range field set (3*2^DEPTH = "11" << DEPTH)
   assign oob1 = en & dual
                 & (ea1_full[AW] | (ea1_full[AW-1] & ea1_full[AW-2]));


   //----------------------------------------------------------------
   // Stride residue (always computed): stride mod 3 from the raw
   // two's-complement pattern, corrected by -(2^STRIDE_W mod 3) when
   // negative. Runs in parallel with the EA1 adder.
   //----------------------------------------------------------------
   logic [1:0] smod, scorr;

   assign smod  = mod3({{(32 - STRIDE_W){1'b0}}, stride});
   assign scorr = stride[STRIDE_W-1] ? mod3_add(smod, 2'(3 - CM))
                                     : smod;


   //----------------------------------------------------------------
   // Bank computation: bank0 from addr; bank1 serial or parallel
   //----------------------------------------------------------------
   logic [1:0] bank0, bank1;

   assign bank0 = mod3({{(32 - AW){1'b0}}, addr});

   generate
      if (PARRES != 0) begin: gen_bank1_par
         assign bank1 = mod3_add(bank0, scorr);
      end
      else begin: gen_bank1_ser
         // adder then tree, in series
         assign bank1 = mod3({{(32 - AW){1'b0}}, ea1_full[AW-1:0]});
      end
   endgenerate


   //----------------------------------------------------------------
   // Access qualification and conflict.
   //
   // conflict is a PURE function of the stride residue: same bank
   // <=> stride % 3 == 0 (bank0 cancels out of the comparison), and
   // it is deliberately NOT gated by oob* -- keeping the EA1 adder
   // and range compare out of the conflict cone, since conflict is
   // the caller's stall request and its most timing-critical output.
   // conflict may therefore assert together with oob1; the oob trap
   // takes precedence in the caller.
   //----------------------------------------------------------------
   logic ce0, ce1;

   assign ce0 = en & ~oob0;
   assign ce1 = en & dual & ~oob1;

   assign conflict = en & dual & (scorr == 2'd0);


   //----------------------------------------------------------------
   // Side A per-bank steering (access 0 priority; access 1 dropped
   // on conflict); one shared wen gate per bank
   //----------------------------------------------------------------
   logic [2:0]       sel0, sel1, ena_bank, wea_bank;
   logic [DEPTH-1:0] addra_bank [0:2];
   logic [WIDTH-1:0] dia_bank [0:2];

   genvar b;
   generate
      for (b = 0; b < 3; b = b + 1) begin: gen_asteer
         assign sel0[b]      = ce0 & (bank0 == b[1:0]);
         assign sel1[b]      = ce1 & (bank1 == b[1:0]) & ~sel0[b];
         assign ena_bank[b]  = sel0[b] | sel1[b];
         assign wea_bank[b]  = ena_bank[b] & wen;
         assign addra_bank[b] = sel0[b] ? idx0 : idx1;
         assign dia_bank[b]   = sel0[b] ? dia0 : dia1;
      end
   endgenerate


   //----------------------------------------------------------------
   // Side B: CRT decode, single requester
   //----------------------------------------------------------------
   logic [1:0]       bankb;
   logic [DEPTH-1:0] idxb;
   logic             ceb;
   logic [2:0]       enb_bank, web_bank;

   assign bankb = mod3({{(32 - AW){1'b0}}, addrb});
   assign idxb  = addrb[DEPTH-1:0];
   assign oobb  = enb & (addrb[AW-1:AW-2] == 2'b11);
   assign ceb   = enb & ~oobb;

   generate
      for (b = 0; b < 3; b = b + 1) begin: gen_bsteer
         assign enb_bank[b] = ceb & (bankb == b[1:0]);
         assign web_bank[b] = enb_bank[b] & web;
      end
   endgenerate


   //----------------------------------------------------------------
   // Banks: true dual port, dual clock, READ_FIRST both sides
   //----------------------------------------------------------------
   logic [WIDTH-1:0] bankdoa [0:2];
   logic [WIDTH-1:0] bankdob [0:2];

   generate
      for (b = 0; b < 3; b = b + 1) begin: gen_bank
         dpmemrf #(.DEPTH(DEPTH), .WIDTH(WIDTH),
                   .OUTREGA(OUTREGA), .OUTREGB(OUTREGB))
         bank_inst (.clka(clka), .ena(ena_bank[b]), .wea(wea_bank[b]),
                    .addra(addra_bank[b]), .dia(dia_bank[b]),
                    .doa(bankdoa[b]),
                    .clkb(clkb), .enb(enb_bank[b]), .web(web_bank[b]),
                    .addrb(idxb), .dib(dib),
                    .dob(bankdob[b]));
      end
   endgenerate


   //----------------------------------------------------------------
   // Return path: 3:1 bank mux per access, select = registered bank
   // id aligned with the bank read latency (1 + OUTREG cycles)
   //----------------------------------------------------------------
   logic [1:0] bank0_r, bank1_r, bankb_r;

   always_ff @(posedge clka) begin
      if (ce0 == 1'b1) begin
         bank0_r <= bank0;
      end
      if (ce1 == 1'b1) begin
         bank1_r <= bank1;
      end
   end

   always_ff @(posedge clkb) begin
      if (ceb == 1'b1) begin
         bankb_r <= bankb;
      end
   end

   generate
      if (OUTREGA != 0) begin: gen_selra
         logic [1:0] bank0_rr, bank1_rr;
         logic       ce0_d, ce1_d;
         always_ff @(posedge clka) begin
            ce0_d <= ce0;
            ce1_d <= ce1;
            if (ce0_d == 1'b1) begin
               bank0_rr <= bank0_r;
            end
            if (ce1_d == 1'b1) begin
               bank1_rr <= bank1_r;
            end
         end
         assign doa0 = bankdoa[bank0_rr];
         assign doa1 = bankdoa[bank1_rr];
      end
      else begin: gen_selra
         assign doa0 = bankdoa[bank0_r];
         assign doa1 = bankdoa[bank1_r];
      end
   endgenerate

   generate
      if (OUTREGB != 0) begin: gen_selrb
         logic [1:0] bankb_rr;
         logic       ceb_d;
         always_ff @(posedge clkb) begin
            ceb_d <= ceb;
            if (ceb_d == 1'b1) begin
               bankb_rr <= bankb_r;
            end
         end
         assign dob = bankdob[bankb_rr];
      end
      else begin: gen_selrb
         assign dob = bankdob[bankb_r];
      end
   endgenerate


endmodule // parmem3
