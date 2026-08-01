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

// Parallel memory: 5 prime-interleaved banks, dual (2-lane) strided
// access group. Member of the parmem prime-interleaved family, at
// (NB_BANKS, NB_LANES) = (5, 2) -- standalone body so that pipeline
// registers can be inserted to break the worst-case
// paths (measured combinational figures for this configuration:
// 484 LUTs / 5 RAMB36, clka WNS -0.13 ns @ 5 ns OOC on xc7z020-1 --
// see hw/lib/parmem/doc/RESULTS.md).
//
//   lane i (i = 0..1): EA_i = addr + i*stride, enabled by lane_en[i];
//   both enabled lanes share `wen` (dual load or dual store).
//
// CRT addressing, no divider: bank = EA mod 5, index = EA[DEPTH-1:0]
// (bijective since gcd(5, 2^DEPTH) = 1). The pair conflicts iff
// stride == 0 (mod 5) -- `conflict` is a pure function of the stride
// residue and the lane mask; it may assert together with oob*, the
// trap taking precedence. On conflict lane 0 is served (steering
// priority; if lane 0 is out of range the bank idles). Power-of-2
// strides never conflict -- and so do multiples of 3, unlike a 3-bank
// design.
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

module parmem5_2
  #(parameter DEPTH    = 10,  //log2 of words per bank; 5*2^DEPTH words total
    parameter WIDTH    = 32,
    parameter STRIDE_W = 12,  //signed stride width, in words; <= DEPTH+3
    parameter ADRREG   = 0,   //register the address phase (+1 cycle, fmax option)
    parameter OUTREGA  = 0,   //extra side-A output register (fmax option)
    parameter OUTREGB  = 0,   //extra side-B output register (fmax option)
    parameter NB       = WIDTH/8)  //byte lanes -- derived, do not override

   (//Side A: one dual strided load/store access pair
    input  logic                clka,
    input  logic                en,
    input  logic                wen,      //shared by the pair
    input  logic [1:0]          lane_en,  //per-lane enable
    input  logic [DEPTH+2:0]    addr,     //lane 0 linear address
    input  logic [STRIDE_W-1:0] stride,   //signed, in words
    input  logic [2*NB-1:0]     ben,      //per-lane byte mask (writes only)
    input  logic [2*WIDTH-1:0]  dia,      //lane write data
    output logic [2*WIDTH-1:0]  doa,      //lane read data

    output logic                freeze,   //REGISTERED: stall the core 1 cycle
    output logic                conflict, //observability only (see header)
    output logic [1:0]          oob,      //EA_i out of range

    //Side B: single linear-addressed port (network interface)
    input  logic                clkb,
    input  logic                enb,
    input  logic                web,
    input  logic [NB-1:0]       benb,     //byte mask (writes only)
    input  logic [DEPTH+2:0]    addrb,
    input  logic [WIDTH-1:0]    dib,
    output logic [WIDTH-1:0]    dob,
    output logic                oobb);

   localparam AW  = DEPTH + 3;            //linear address width
   localparam EAW = AW + 3;               //lane EA: sign + |stride| margin

   // mod-5 digit fold: base-4 digits with alternating signs (4 == -1
   // mod 5); |neg| <= 24 -> OFFSET = 25; first-fold value <= 49 (6 bits)
   localparam SRW    = 6;
   localparam OFFSET = 25;
   // 2^STRIDE_W mod 5 (two's-complement sign correction; 2^k mod 5
   // cycles 1, 2, 4, 3)
   //cycles from access issue to bank data valid on side A
   localparam int SER_D = ADRREG + 1 + OUTREGA;

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


   //================================================================
   // ADDRESS PHASE -- closed by the optional ADRREG pipeline register
   // (addra_bank / dia_bank / ena_bank / wea_bank / bank ids), before
   // the bank access. conflict and oob are computed in this section
   // and stay combinational regardless of ADRREG.
   //================================================================

   //----------------------------------------------------------------
   // Stride residue, sign-corrected (drives conflict and lane 1 bank)
   //----------------------------------------------------------------
   logic [2:0] smod, scorr;

   assign smod  = mod5({{(32 - STRIDE_W){1'b0}}, stride});
   assign scorr = stride[STRIDE_W-1] ? mod5_add(smod, 3'(5 - CM)) : smod;

   //----------------------------------------------------------------
   // Lane effective addresses and bank ids
   //----------------------------------------------------------------
   logic signed [EAW-1:0] ea1_full;
   logic [DEPTH-1:0]      idx0, idx1;
   logic [4:0]            bank0_oh;
   logic [2:0]            bank0, bank1;
   logic [1:0]            ce;
   logic                  same_word, ser_start, ser_phase;
   logic [1:0]            lane_en_eff;
   logic [SER_D:0]        ser_dly;
   logic                  ser_flush;

   assign ea1_full = EAW'($signed({1'b0, addr}))
                     + EAW'($signed(stride));
   assign idx0     = addr[DEPTH-1:0];
   assign idx1     = ea1_full[DEPTH-1:0];

   assign bank0_oh = mod5_oh({{(32 - AW){1'b0}}, addr});
   assign bank0    = f_enc(bank0_oh);
   assign bank1    = mod5_add(bank0, scorr);

   //----------------------------------------------------------------
   // Out-of-range: sign | (top bits >= 5) -- no carry chain after the
   // adder (full-width check before truncation: negative/overflowing
   // sums would alias in-range cells)
   //----------------------------------------------------------------
   // oob[0] uses the RAW lane mask, not lane_en_eff -- see parmem3_2.
   assign oob[0] = en & lane_en[0] & (addr[AW-1:DEPTH] >= 3'd5);
   assign oob[1] = en & lane_en_eff[1]
                   & (ea1_full[EAW-1]
                      | (ea1_full[EAW-2:DEPTH] >= (EAW - 1 - DEPTH)'(5)));

   assign ce = {2{en}} & lane_en_eff & ~oob;

   //----------------------------------------------------------------
   // same_word vs conflict. Both lanes land on one bank when the stride
   // residue is zero; a ZERO stride additionally puts them on the same
   // word (bank1 == bank0 and idx1 == idx0).
   //
   // On a READ that costs nothing and needs no serialization: the one
   // bank access is issued for lane 0, and the return path hands the
   // same word to both lanes because their bank selects are equal.
   // On a WRITE it does not: the lanes carry different byte masks and
   // different data, so a same-word store serializes like any other
   // conflict. See parmem3_2 for the full rationale.
   //----------------------------------------------------------------
   assign same_word = en & (stride == '0) & (lane_en == 2'b11);
   assign conflict  = en & (scorr == '0) & (lane_en == 2'b11)
                      & ~(same_word & ~wen);

   //----------------------------------------------------------------
   // Internal serialization. ser_phase is the second half of a
   // conflicting pair; it drives `freeze` straight out of its flop, so
   // nothing combinational runs from the stride into the core's clock
   // enable. While ser_phase is high the core is stalled and therefore
   // still presenting the same access, so only the lane mask is
   // overridden.
   //----------------------------------------------------------------
   assign ser_start   = conflict & ~ser_phase;
   assign lane_en_eff = ser_phase ? 2'b10 : lane_en;
   assign freeze      = ser_phase;

   always_ff @(posedge clka) begin
      ser_phase <= ser_start;
   end

   //----------------------------------------------------------------
   // Per-bank steering: raw-match ownership (EARLY cone: residues and
   // lane mask only); mux select = lane 0 match, lane 1 as default --
   // the stride residue never enters the address/data select cone
   //----------------------------------------------------------------
   logic [4:0]       ena_bank, wea_bank;
   logic [DEPTH-1:0] addra_bank [0:4];
   logic [WIDTH-1:0] dia_bank [0:4];
   logic [NB-1:0]    ben_bank [0:4];

   generate
      for (genvar b = 0; b < 5; b = b + 1) begin: gen_asteer
         logic [1:0] rawm, sel;

         assign rawm[0] = lane_en_eff[0] & bank0_oh[b];
         assign rawm[1] = lane_en_eff[1] & (bank1 == 3'(b));

         assign sel[0] = rawm[0];
         assign sel[1] = rawm[1] & ~rawm[0];

         assign ena_bank[b] = |(sel & ce);
         assign wea_bank[b] = ena_bank[b] & wen;

         assign addra_bank[b] = rawm[0] ? idx0 : idx1;
         assign dia_bank[b]   = rawm[0] ? dia[0 +: WIDTH]
                                        : dia[WIDTH +: WIDTH];
         assign ben_bank[b]   = rawm[0] ? ben[0 +: NB] : ben[NB +: NB];
      end
   endgenerate

   //----------------------------------------------------------------
   // Optional address-phase pipeline register (ADRREG = 1): breaks
   // the stride/addr worst-case paths before the bank access; +1
   // cycle on data. Bank ids are load-enabled by ce (select-hold
   // semantics, matching the return-path registers).
   //----------------------------------------------------------------
   logic [4:0]       ena_bank_q, wea_bank_q;
   logic [DEPTH-1:0] addra_bank_q [0:4];
   logic [WIDTH-1:0] dia_bank_q [0:4];
   logic [NB-1:0]    ben_bank_q [0:4];
   logic [1:0]       ce_q;
   logic [2:0]       bank0_q, bank1_q;

   generate
      if (ADRREG != 0) begin: gen_adrreg
         always_ff @(posedge clka) begin
            ena_bank_q <= ena_bank;
            wea_bank_q <= wea_bank;
            ce_q       <= ce;
            for (int b = 0; b < 5; b++) begin
               addra_bank_q[b] <= addra_bank[b];
               dia_bank_q[b]   <= dia_bank[b];
               ben_bank_q[b]   <= ben_bank[b];
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
         for (genvar b = 0; b < 5; b = b + 1) begin: gen_pass
            assign addra_bank_q[b] = addra_bank[b];
            assign dia_bank_q[b]   = dia_bank[b];
            assign ben_bank_q[b]   = ben_bank[b];
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

   // Serialized-pair flush -- see parmem3_2 for the full rationale. With
   // OUTREGA = 1 the bank output register is enable-gated, so lane 1's
   // word only reaches bankdoa on a further ENABLED edge, which the
   // resumed core does not necessarily provide. ser_flush re-enables the
   // banks for exactly that cycle; it carries no write enable.
   assign ser_flush = (OUTREGA != 0) ? ser_dly[SER_D-1] : 1'b0;

   generate
      for (genvar b = 0; b < 5; b = b + 1) begin: gen_bank
         dpmemrf #(.DEPTH(DEPTH), .WIDTH(WIDTH), .BYTE_WE(1),
                   .OUTREGA(OUTREGA), .OUTREGB(OUTREGB))
         bank_inst (.clka(clka), .ena(ena_bank_q[b] | ser_flush),
                    .wea({NB{wea_bank_q[b]}} & ben_bank_q[b]),
                    .addra(addra_bank_q[b]), .dia(dia_bank_q[b]),
                    .doa(bankdoa[b]),
                    .clkb(clkb), .enb(enb_bank[b]),
                    .web({NB{web_bank[b]}} & benb),
                    .addrb(idxb), .dib(dib),
                    .dob(bankdob[b]));
      end
   endgenerate

   //----------------------------------------------------------------
   // Return path: per-lane 5:1 bank mux, select = registered bank id
   // aligned with the bank read latency (1 + OUTREG cycles)
   //----------------------------------------------------------------
   logic [1:0][2:0] bank_r;
   logic [2:0]      bankb_r;

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

   //----------------------------------------------------------------
   // Serialized-pair replay. On a conflict both lanes share one bank,
   // so lane 1's access overwrites the bank output lane 0's word came
   // out on, one cycle later. Capture lane 0's word as it appears and
   // present it again on the cycle lane 1's word is valid, so the pair
   // still leaves together.
   //
   // The replay is folded INTO the bank mux rather than stacked after
   // it: the hold register is a sixth input of what was a 5:1 select,
   // which costs no extra logic level (a 5:1 already spans two LUT6).
   //----------------------------------------------------------------
   localparam logic [2:0] SEL_HOLD = 3'd5;   // first unused bank code

   logic [WIDTH-1:0] doa0_hold;
   logic [2:0]       sel0, sel1;
   logic [WIDTH-1:0] doa0_out, doa1_out;

   generate
      if (OUTREGA != 0) begin: gen_selra
         logic [1:0][2:0] bank_rr;
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
         assign sel0 = ser_dly[SER_D] ? SEL_HOLD : bank_rr[0];
         assign sel1 = bank_rr[1];
      end
      else begin: gen_selra
         assign sel0 = ser_dly[SER_D] ? SEL_HOLD : bank_r[0];
         assign sel1 = bank_r[1];
      end
   endgenerate

   always_comb begin
      case (sel0)
        3'd0:    doa0_out = bankdoa[0];
        3'd1:    doa0_out = bankdoa[1];
        3'd2:    doa0_out = bankdoa[2];
        3'd3:    doa0_out = bankdoa[3];
        3'd4:    doa0_out = bankdoa[4];
        default: doa0_out = doa0_hold;
      endcase
      case (sel1)
        3'd0:    doa1_out = bankdoa[0];
        3'd1:    doa1_out = bankdoa[1];
        3'd2:    doa1_out = bankdoa[2];
        3'd3:    doa1_out = bankdoa[3];
        default: doa1_out = bankdoa[4];
      endcase
   end

   // Captured from the mux output itself: at capture time sel0 still
   // points at lane 0's bank, so this is bankdoa[bank_r[0]] without a
   // second 5:1 select. The path through doa0_hold is broken by the
   // register, so the loop is sequential, not combinational.
   always_ff @(posedge clka) begin
      ser_dly <= {ser_dly[SER_D-1:0], ser_start};
      if (ser_dly[SER_D-1] == 1'b1) begin
         doa0_hold <= doa0_out;
      end
   end

   assign doa[0 +: WIDTH]     = doa0_out;
   assign doa[WIDTH +: WIDTH] = doa1_out;

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


endmodule // parmem5_2
