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

// Parallel memory: 3 prime-interleaved banks, dual (2-lane) strided
// access pair for a dual load/store (LD2/ST2) unit. Same interface
// family as parmem5_2 / parmem5_4 / parmemn (per-lane enables, packed
// lane data) so the memories are interchangeable under a common L/S
// unit. Measured combinational figures: ~300 LUTs / 3 RAMB36, clka
// slack at artifact level @ 5 ns OOC on xc7z020-1 -- see
// hw/lib/parmemn/RESULTS.md (B3L2).
//
//   lane i (i = 0..1): EA_i = addr + i*stride, enabled by lane_en[i];
//   both enabled lanes share `wen` (dual load or dual store).
//
// CRT addressing, no divider: bank = EA mod 3, index = EA[DEPTH-1:0]
// (bijective since gcd(3, 2^DEPTH) = 1). The pair conflicts iff
// stride == 0 (mod 3) -- `conflict` is a pure function of the stride
// residue and the lane mask (deliberately not gated by oob*, keeping
// the EA1 adder out of its cone); it may assert together with oob*,
// the trap taking precedence. On conflict lane 0 is served (steering
// priority; if lane 0 is out of range the bank idles). Power-of-2
// strides never conflict.
//
// Lane 1's bank id is the parallel residue (bank0 + stride) mod 3,
// computed IN PARALLEL with the EA1 adder (mod is a homomorphism); a
// sign-correction constant accounts for the two's-complement
// representation (the raw-pattern residue is off by 2^STRIDE_W mod 3
// when stride is negative).
//
// EA1 is range-checked at FULL width before truncation: a negative or
// overflowing EA1 can alias an in-range address after truncation (e.g.
// DEPTH=4: 0 + (-20) truncates to 44 < 48). Out-of-range lanes are
// reported on oob[i] and suppressed individually.
//
// Side B is a single linear-addressed port with its own clock and CRT
// decode (network interface). Side A reads: 1 + ADRREG + OUTREGA
// cycles; side B reads: 1 + OUTREGB cycles (the dpmemrf output
// register is enable-gated -- hold the enable one extra cycle to
// flush). READ_FIRST: a write returns the pre-write content.
//
// ADRREG = 1 inserts a pipeline register at the end of the address
// phase (bank enables/WE/address/data muxes and bank ids), breaking
// the stride/addr worst-case paths before the bank access. conflict
// and oob stay COMBINATIONAL (computed before the register, from the
// ports only): the issue-cycle contract is unchanged -- only the data
// latency grows.

module parmem3
  #(parameter DEPTH    = 10,  //log2 of words per bank; 3*2^DEPTH words total
    parameter WIDTH    = 32,
    parameter STRIDE_W = 12,  //signed stride width, in words; <= DEPTH+2
    parameter ADRREG   = 0,   //register the address phase (+1 cycle, fmax option)
    parameter OUTREGA  = 0,   //extra side-A output register (fmax option)
    parameter OUTREGB  = 0)   //extra side-B output register (fmax option)

   (//Side A: one dual strided load/store access pair
    input  logic                clka,
    input  logic                en,
    input  logic                wen,      //shared by the pair
    input  logic [1:0]          lane_en,  //per-lane enable
    input  logic [DEPTH+1:0]    addr,     //lane 0 linear address
    input  logic [STRIDE_W-1:0] stride,   //signed, in words
    input  logic [2*WIDTH-1:0]  dia,      //lane write data
    output logic [2*WIDTH-1:0]  doa,      //lane read data

    output logic                conflict, //stride % 3 == 0: serialize
    output logic [1:0]          oob,      //EA_i out of range

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

   initial begin
      assert (STRIDE_W <= AW)
        else $fatal(1, "STRIDE_W must be <= DEPTH + 2");
   end


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


   //================================================================
   // ADDRESS PHASE -- closed by the optional ADRREG pipeline register
   // (addra_bank / dia_bank / ena_bank / wea_bank / bank ids), before
   // the bank access. conflict and oob are computed in this section
   // and stay combinational regardless of ADRREG.
   //================================================================

   //----------------------------------------------------------------
   // Stride residue, sign-corrected (drives conflict and lane 1 bank),
   // in parallel with the EA1 adder
   //----------------------------------------------------------------
   logic [1:0] smod, scorr;

   assign smod  = mod3({{(32 - STRIDE_W){1'b0}}, stride});
   assign scorr = stride[STRIDE_W-1] ? mod3_add(smod, 2'(3 - CM))
                                     : smod;

   //----------------------------------------------------------------
   // Lane effective addresses and bank ids
   //----------------------------------------------------------------
   logic signed [AW:0] ea1_full;
   logic [DEPTH-1:0]   idx0, idx1;
   logic [1:0]         bank0, bank1;
   logic [1:0]         ce;

   assign ea1_full = $signed({1'b0, addr})
                     + (AW + 1)'($signed(stride));
   assign idx0 = addr[DEPTH-1:0];
   assign idx1 = ea1_full[DEPTH-1:0];

   assign bank0 = mod3({{(32 - AW){1'b0}}, addr});
   assign bank1 = mod3_add(bank0, scorr);

   //----------------------------------------------------------------
   // Out-of-range: full-width test as a pure check on the sum -- no
   // second carry chain after the adder: negative <=> sign bit;
   // >= 3*2^DEPTH <=> both top bits of the in-range field set
   // (3*2^DEPTH = "11" << DEPTH)
   //----------------------------------------------------------------
   assign oob[0] = en & lane_en[0] & (addr[AW-1:AW-2] == 2'b11);
   assign oob[1] = en & lane_en[1]
                   & (ea1_full[AW] | (ea1_full[AW-1] & ea1_full[AW-2]));

   assign ce = {2{en}} & lane_en & ~oob;

   //----------------------------------------------------------------
   // Conflict: pure function of the stride residue and the lane mask
   //----------------------------------------------------------------
   assign conflict = en & (scorr == 2'd0) & (lane_en == 2'b11);

   //----------------------------------------------------------------
   // Per-bank steering: raw-match ownership (EARLY cone: residues and
   // lane mask only); mux select = lane 0 match, lane 1 as default --
   // the EA1 adder and oob logic never enter the address/data select
   // cone
   //----------------------------------------------------------------
   logic [2:0]       ena_bank, wea_bank;
   logic [DEPTH-1:0] addra_bank [0:2];
   logic [WIDTH-1:0] dia_bank [0:2];

   generate
      for (genvar b = 0; b < 3; b = b + 1) begin: gen_asteer
         logic [1:0] rawm, sel;

         assign rawm[0] = lane_en[0] & (bank0 == b[1:0]);
         assign rawm[1] = lane_en[1] & (bank1 == b[1:0]);

         assign sel[0] = rawm[0];
         assign sel[1] = rawm[1] & ~rawm[0];

         assign ena_bank[b] = |(sel & ce);
         assign wea_bank[b] = ena_bank[b] & wen;

         assign addra_bank[b] = rawm[0] ? idx0 : idx1;
         assign dia_bank[b]   = rawm[0] ? dia[0 +: WIDTH]
                                        : dia[WIDTH +: WIDTH];
      end
   endgenerate

   //----------------------------------------------------------------
   // Optional address-phase pipeline register (ADRREG = 1): breaks
   // the stride/addr worst-case paths before the bank access; +1
   // cycle on data. Bank ids are load-enabled by ce (select-hold
   // semantics, matching the return-path registers).
   //----------------------------------------------------------------
   logic [2:0]       ena_bank_q, wea_bank_q;
   logic [DEPTH-1:0] addra_bank_q [0:2];
   logic [WIDTH-1:0] dia_bank_q [0:2];
   logic [1:0]       ce_q;
   logic [1:0]       bank0_q, bank1_q;

   generate
      if (ADRREG != 0) begin: gen_adrreg
         always_ff @(posedge clka) begin
            ena_bank_q <= ena_bank;
            wea_bank_q <= wea_bank;
            ce_q       <= ce;
            for (int b = 0; b < 3; b++) begin
               addra_bank_q[b] <= addra_bank[b];
               dia_bank_q[b]   <= dia_bank[b];
            end
            if (ce[0] == 1'b1) begin
               bank0_q <= bank0;
            end
            if (ce[1] == 1'b1) begin
               bank1_q <= bank1;
            end
         end
      end
      else begin: gen_adrreg
         assign ena_bank_q = ena_bank;
         assign wea_bank_q = wea_bank;
         assign ce_q       = ce;
         assign bank0_q    = bank0;
         assign bank1_q    = bank1;
         for (genvar b = 0; b < 3; b = b + 1) begin: gen_pass
            assign addra_bank_q[b] = addra_bank[b];
            assign dia_bank_q[b]   = dia_bank[b];
         end
      end
   endgenerate

   //================================================================
   // END OF ADDRESS PHASE
   //================================================================

   //----------------------------------------------------------------
   // Side B: CRT decode, single requester (no muxes)
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
      for (genvar b = 0; b < 3; b = b + 1) begin: gen_bsteer
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
      for (genvar b = 0; b < 3; b = b + 1) begin: gen_bank
         dpmemrf #(.DEPTH(DEPTH), .WIDTH(WIDTH),
                   .OUTREGA(OUTREGA), .OUTREGB(OUTREGB))
         bank_inst (.clka(clka), .ena(ena_bank_q[b]), .wea(wea_bank_q[b]),
                    .addra(addra_bank_q[b]), .dia(dia_bank_q[b]),
                    .doa(bankdoa[b]),
                    .clkb(clkb), .enb(enb_bank[b]), .web(web_bank[b]),
                    .addrb(idxb), .dib(dib),
                    .dob(bankdob[b]));
      end
   endgenerate

   //----------------------------------------------------------------
   // Return path: per-lane 3:1 bank mux, select = registered bank id
   // aligned with the bank read latency (1 + OUTREG cycles)
   //----------------------------------------------------------------
   logic [1:0][1:0] bank_r;
   logic [1:0]      bankb_r;

   always_ff @(posedge clka) begin
      if (ce_q[0] == 1'b1) begin
         bank_r[0] <= bank0_q;
      end
      if (ce_q[1] == 1'b1) begin
         bank_r[1] <= bank1_q;
      end
   end

   always_ff @(posedge clkb) begin
      if (ceb == 1'b1) begin
         bankb_r <= bankb;
      end
   end

   generate
      if (OUTREGA != 0) begin: gen_selra
         logic [1:0][1:0] bank_rr;
         logic [1:0]      ce_d;
         always_ff @(posedge clka) begin
            ce_d <= ce_q;
            if (ce_d[0] == 1'b1) begin
               bank_rr[0] <= bank_r[0];
            end
            if (ce_d[1] == 1'b1) begin
               bank_rr[1] <= bank_r[1];
            end
         end
         assign doa[0 +: WIDTH]     = bankdoa[bank_rr[0]];
         assign doa[WIDTH +: WIDTH] = bankdoa[bank_rr[1]];
      end
      else begin: gen_selra
         assign doa[0 +: WIDTH]     = bankdoa[bank_r[0]];
         assign doa[WIDTH +: WIDTH] = bankdoa[bank_r[1]];
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
