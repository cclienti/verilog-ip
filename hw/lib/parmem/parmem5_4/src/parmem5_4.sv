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

// Parallel memory: 5 prime-interleaved banks, quad (4-lane) strided
// access group. Member of the parmem prime-interleaved family, at
// (NB_BANKS, NB_LANES) = (5, 4) -- standalone body so that pipeline
// registers can be inserted to break the worst-case
// paths (measured combinational figures for this configuration:
// 955 LUTs / 5 RAMB36, clka WNS -1.994 ns @ 5 ns OOC on xc7z020-1 --
// see hw/lib/parmem/doc/RESULTS.md).
//
//   lane i (i = 0..3): EA_i = addr + i*stride, enabled by lane_en[i];
//   all enabled lanes share `wen` (group load or group store).
//
// CRT addressing, no divider: bank = EA mod 5, index = EA[DEPTH-1:0]
// (bijective since gcd(5, 2^DEPTH) = 1). Lanes collide iff
// stride == 0 (mod 5) -- `conflict` is ONE bit and a pure function of
// the stride residue and the lane mask; it may assert together with
// oob*, the trap taking precedence. On conflict the lowest enabled
// lane is served (steering priority; if that lane is out of range the
// bank idles). Power-of-2 strides never conflict.
//
// Every EA is range-checked at FULL width before truncation; out-of-
// range lanes are reported on oob[i] and suppressed individually.
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

module parmem5_4
  #(parameter DEPTH    = 10,  //log2 of words per bank; 5*2^DEPTH words total
    parameter WIDTH    = 32,
    parameter STRIDE_W = 12,  //signed stride width, in words; <= DEPTH+3
    parameter ADRREG   = 0,   //register the address phase (+1 cycle, fmax option)
    parameter OUTREGA  = 0,   //extra side-A output register (fmax option)
    parameter OUTREGB  = 0)   //extra side-B output register (fmax option)

   (//Side A: one quad strided load/store access group
    input  logic                clka,
    input  logic                en,
    input  logic                wen,      //shared by the group
    input  logic [3:0]          lane_en,  //per-lane enable
    input  logic [DEPTH+2:0]    addr,     //lane 0 linear address
    input  logic [STRIDE_W-1:0] stride,   //signed, in words
    input  logic [4*WIDTH-1:0]  dia,      //lane write data
    output logic [4*WIDTH-1:0]  doa,      //lane read data

    output logic                conflict, //stride % 5 == 0: serialize
    output logic [3:0]          oob,      //EA_i out of range

    //Side B: single linear-addressed port (network interface)
    input  logic                clkb,
    input  logic                enb,
    input  logic                web,
    input  logic [DEPTH+2:0]    addrb,
    input  logic [WIDTH-1:0]    dib,
    output logic [WIDTH-1:0]    dob,
    output logic                oobb);

   localparam NL  = 4;                    //lanes
   localparam AW  = DEPTH + 3;            //linear address width
   localparam EAW = AW + 4;               //lane EA: sign + |3*stride| margin
   localparam SMW = STRIDE_W + 3;         //lane stride multiple, i <= 3

   // mod-5 digit fold: base-4 digits with alternating signs (4 == -1
   // mod 5); |neg| <= 24 -> OFFSET = 25; first-fold value <= 49 (6 bits)
   localparam SRW    = 6;
   localparam OFFSET = 25;
   // 2^STRIDE_W mod 5 (two's-complement sign correction; 2^k mod 5
   // cycles 1, 2, 4, 3)
   localparam CM = (STRIDE_W % 4 == 0) ? 1 : (STRIDE_W % 4 == 1) ? 2
                 : (STRIDE_W % 4 == 2) ? 4 : 3;

   initial begin
      assert (STRIDE_W <= AW)
        else $fatal(1, "STRIDE_W must be <= DEPTH + 3");
   end


   //----------------------------------------------------------------
   // mod-5 helpers (all arithmetic on narrow bounded vectors)
   //----------------------------------------------------------------
   function automatic logic [2:0] mod5(input logic [31:0] a);
      logic [SRW-1:0] pos, neg, s;
      begin
         pos = '0;
         neg = '0;
         for (int i = 0; i < 16; i++) begin
            if ((i % 2) == 1) begin
               neg += SRW'((a >> (2 * i)) & 2'b11);
            end
            else begin
               pos += SRW'((a >> (2 * i)) & 2'b11);
            end
         end
         s = pos - neg + SRW'(OFFSET);
         // bounded value (s <= 49): constant modulo = small LUT function
         return 3'(s % SRW'(5));
      end
   endfunction

   // one-hot variant: reduction and bank compare fused per output bit
   function automatic logic [4:0] mod5_oh(input logic [31:0] a);
      logic [2:0] r;
      logic [4:0] oh;
      begin
         r = mod5(a);
         for (int b = 0; b < 5; b++) begin
            oh[b] = (r == 3'(b));
         end
         return oh;
      end
   endfunction

   function automatic logic [2:0] f_enc(input logic [4:0] oh);
      logic [2:0] r;
      begin
         r = '0;
         for (int b = 0; b < 5; b++) begin
            if (oh[b]) begin
               r |= 3'(b);
            end
         end
         return r;
      end
   endfunction

   function automatic logic [2:0] mod5_add(input logic [2:0] a, b);
      logic [3:0] s;
      begin
         s = {1'b0, a} + {1'b0, b};
         if (s >= 5) begin
            s = s - 4'd5;
         end
         return s[2:0];
      end
   endfunction

   // (i * r) mod 5 for constant i, r < 5: pure 3-bit LUT functions
   function automatic logic [2:0] mod5_muli(input logic [2:0] r,
                                            input int unsigned i);
      return 3'((32'(r) * i) % 5);
   endfunction


   //================================================================
   // ADDRESS PHASE -- closed by the optional ADRREG pipeline register
   // (addra_bank / dia_bank / ena_bank / wea_bank / bank ids), before
   // the bank access. conflict and oob are computed in this section
   // and stay combinational regardless of ADRREG.
   //================================================================

   //----------------------------------------------------------------
   // Stride residue, sign-corrected (drives conflict and lane banks)
   //----------------------------------------------------------------
   logic [2:0] smod, scorr;

   assign smod  = mod5({{(32 - STRIDE_W){1'b0}}, stride});
   assign scorr = stride[STRIDE_W-1] ? mod5_add(smod, 3'(5 - CM)) : smod;

   //----------------------------------------------------------------
   // Lane effective addresses (parallel adders; 2s is a shift, 3s one
   // narrow pre-add) and lane bank ids (depth-constant: bank0 plus a
   // per-lane constant multiple of the stride residue)
   //----------------------------------------------------------------
   logic signed [SMW-1:0] sx;
   logic signed [EAW-1:0] ea_full [0:NL-1];
   logic [DEPTH-1:0]      idx [0:NL-1];
   logic [NL-1:0][2:0]    bank;
   logic [4:0]            bank0_oh;
   logic [NL-1:0]         ce;

   assign sx = SMW'($signed(stride));

   assign ea_full[0] = EAW'($signed({1'b0, addr}));
   assign ea_full[1] = EAW'($signed({1'b0, addr})) + EAW'(sx);
   assign ea_full[2] = EAW'($signed({1'b0, addr})) + EAW'(sx <<< 1);
   assign ea_full[3] = EAW'($signed({1'b0, addr}))
                       + EAW'(SMW'(sx + (sx <<< 1)));

   assign bank0_oh = mod5_oh({{(32 - AW){1'b0}}, addr});
   assign bank[0]  = f_enc(bank0_oh);
   assign bank[1]  = mod5_add(bank[0], scorr);
   assign bank[2]  = mod5_add(bank[0], mod5_muli(scorr, 2));
   assign bank[3]  = mod5_add(bank[0], mod5_muli(scorr, 3));

   generate
      for (genvar i = 0; i < NL; i = i + 1) begin: gen_idx
         assign idx[i] = ea_full[i][DEPTH-1:0];
      end
   endgenerate

   //----------------------------------------------------------------
   // Out-of-range: sign | (top bits >= 5) -- no carry chain after the
   // adders (full-width check before truncation: negative/overflowing
   // sums would alias in-range cells)
   //----------------------------------------------------------------
   assign oob[0] = en & lane_en[0] & (addr[AW-1:DEPTH] >= 3'd5);

   generate
      for (genvar i = 1; i < NL; i = i + 1) begin: gen_oob
         assign oob[i] = en & lane_en[i]
                         & (ea_full[i][EAW-1]
                            | (ea_full[i][EAW-2:DEPTH] >= (EAW - 1 - DEPTH)'(5)));
      end
   endgenerate

   assign ce = {NL{en}} & lane_en & ~oob;

   //----------------------------------------------------------------
   // Conflict: pure function of the stride residue and the lane mask
   //----------------------------------------------------------------
   assign conflict = en & (scorr == '0) & ($countones(lane_en) > 1);

   //----------------------------------------------------------------
   // Per-bank steering: raw-match ownership (EARLY cone: residues and
   // lane mask only -- oob/adders stay on the enable/WE cone); mux
   // selects use first-match among lanes 0..2 with lane 3 as default
   //----------------------------------------------------------------
   logic [4:0]       ena_bank, wea_bank;
   logic [DEPTH-1:0] addra_bank [0:4];
   logic [WIDTH-1:0] dia_bank [0:4];

   generate
      for (genvar b = 0; b < 5; b = b + 1) begin: gen_asteer
         logic [NL-1:0] rawm, sel, msel;

         assign rawm[0] = lane_en[0] & bank0_oh[b];
         assign rawm[1] = lane_en[1] & (bank[1] == 3'(b));
         assign rawm[2] = lane_en[2] & (bank[2] == 3'(b));
         assign rawm[3] = lane_en[3] & (bank[3] == 3'(b));

         // lowest raw-matching lane owns the bank (enable/WE cone)
         assign sel[0] = rawm[0];
         assign sel[1] = rawm[1] & ~rawm[0];
         assign sel[2] = rawm[2] & ~(|rawm[1:0]);
         assign sel[3] = rawm[3] & ~(|rawm[2:0]);

         assign ena_bank[b] = |(sel & ce);
         assign wea_bank[b] = ena_bank[b] & wen;

         // mux selects: lane 3 as default (its residue never enters
         // the select cone); equivalent whenever the bank is enabled
         assign msel[0] = rawm[0];
         assign msel[1] = rawm[1] & ~rawm[0];
         assign msel[2] = rawm[2] & ~(|rawm[1:0]);
         assign msel[3] = ~(|rawm[2:0]);

         always_comb begin
            addra_bank[b] = '0;
            dia_bank[b]   = '0;
            for (int i = 0; i < NL; i++) begin
               if (msel[i]) begin
                  addra_bank[b] |= idx[i];
                  dia_bank[b]   |= dia[i*WIDTH +: WIDTH];
               end
            end
         end
      end
   endgenerate

   //----------------------------------------------------------------
   // Optional address-phase pipeline register (ADRREG = 1): breaks
   // the stride/addr worst-case paths before the bank access; +1
   // cycle on data. Bank ids are load-enabled by ce (select-hold
   // semantics, matching the return-path registers).
   //----------------------------------------------------------------
   logic [4:0]         ena_bank_q, wea_bank_q;
   logic [DEPTH-1:0]   addra_bank_q [0:4];
   logic [WIDTH-1:0]   dia_bank_q [0:4];
   logic [NL-1:0]      ce_q;
   logic [NL-1:0][2:0] bank_q;

   generate
      if (ADRREG != 0) begin: gen_adrreg
         always_ff @(posedge clka) begin
            ena_bank_q <= ena_bank;
            wea_bank_q <= wea_bank;
            ce_q       <= ce;
            for (int b = 0; b < 5; b++) begin
               addra_bank_q[b] <= addra_bank[b];
               dia_bank_q[b]   <= dia_bank[b];
            end
            for (int i = 0; i < NL; i++) begin
               if (ce[i] == 1'b1) begin
                  bank_q[i] <= bank[i];
               end
            end
         end
      end
      else begin: gen_adrreg
         assign ena_bank_q = ena_bank;
         assign wea_bank_q = wea_bank;
         assign ce_q       = ce;
         assign bank_q     = bank;
         for (genvar b = 0; b < 5; b = b + 1) begin: gen_pass
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
   logic [4:0]       bankb_oh;
   logic [2:0]       bankb;
   logic [DEPTH-1:0] idxb;
   logic             ceb;
   logic [4:0]       enb_bank, web_bank;

   assign bankb_oh = mod5_oh({{(32 - AW){1'b0}}, addrb});
   assign bankb    = f_enc(bankb_oh);
   assign idxb     = addrb[DEPTH-1:0];
   assign oobb     = enb & (addrb[AW-1:DEPTH] >= 3'd5);
   assign ceb      = enb & ~oobb;

   generate
      for (genvar b = 0; b < 5; b = b + 1) begin: gen_bsteer
         assign enb_bank[b] = ceb & bankb_oh[b];
         assign web_bank[b] = enb_bank[b] & web;
      end
   endgenerate

   //----------------------------------------------------------------
   // Banks: true dual port, dual clock, READ_FIRST both sides
   //----------------------------------------------------------------
   logic [WIDTH-1:0] bankdoa [0:4];
   logic [WIDTH-1:0] bankdob [0:4];

   generate
      for (genvar b = 0; b < 5; b = b + 1) begin: gen_bank
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
   // Return path: per-lane 5:1 bank mux, select = registered bank id
   // aligned with the bank read latency (1 + OUTREG cycles)
   //----------------------------------------------------------------
   logic [NL-1:0][2:0] bank_r;
   logic [2:0]         bankb_r;

   generate
      for (genvar i = 0; i < NL; i = i + 1) begin: gen_selr
         always_ff @(posedge clka) begin
            if (ce_q[i] == 1'b1) begin
               bank_r[i] <= bank_q[i];
            end
         end

         if (OUTREGA != 0) begin: gen_rr
            logic [2:0] bank_rr;
            logic       ce_d;
            always_ff @(posedge clka) begin
               ce_d <= ce_q[i];
               if (ce_d == 1'b1) begin
                  bank_rr <= bank_r[i];
               end
            end
            assign doa[i*WIDTH +: WIDTH] = bankdoa[bank_rr];
         end
         else begin: gen_rr
            assign doa[i*WIDTH +: WIDTH] = bankdoa[bank_r[i]];
         end
      end
   endgenerate

   always_ff @(posedge clkb) begin
      if (ceb == 1'b1) begin
         bankb_r <= bankb;
      end
   end

   generate
      if (OUTREGB != 0) begin: gen_selrb
         logic [2:0] bankb_rr;
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


endmodule // parmem5_4
