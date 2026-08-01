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
// family as parmem5_2 / parmem5_4 (per-lane enables, packed
// lane data) so the memories are interchangeable under a common L/S
// unit. Measured combinational figures: 295 LUTs / 3 RAMB36, timing MET
// @ 5 ns OOC even on xc7z020-1 -- see
// hw/lib/parmem/doc/RESULTS.md (M3L2).
//
//   lane i (i = 0..1): EA_i = addr + i*stride, enabled by lane_en[i];
//   both enabled lanes share `wen` (dual load or dual store).
//
// CRT addressing, no divider: bank = EA mod 3, index = EA[DEPTH-1:0]
// (bijective since gcd(3, 2^DEPTH) = 1). Power-of-2 strides never
// conflict.
//
// The pair needs one bank access per lane unless the two lanes fall on
// the same word, and the two cases are distinguished:
//
//   same_word = (stride == 0)                 -- one access serves both
//   conflict  = (stride != 0) && (stride % 3 == 0)
//
// On a READ same_word costs nothing: lane 0's access is issued, and the
// return path hands the same word to both lanes because bank1 == bank0
// and idx1 == idx0. A contiguous sub-word pair is exactly this case.
// On a WRITE the lanes carry different byte masks and data, so a
// same-word store serializes like any other conflict. `conflict` is a
// pure function of the stride residue, the lane mask and wen
// (deliberately not gated by oob*, keeping the EA1 adder out of its
// cone).
//
// CONFLICT SERIALIZATION IS INTERNAL. On conflict the memory serves
// lane 0, then re-issues for lane 1 on the next cycle, and asks the
// core to stall for exactly that cycle through `freeze` -- a REGISTERED
// output, so no combinational path runs from the stride through the
// residue tree into the core's global clock enable. Timing: at T the
// pair is issued and lane 0 served, at T+1 `freeze` is high and lane 1
// is served, at T+2 execution resumes. The core must hold its inputs
// while `freeze` is high (a total pipeline freeze does exactly that).
// Lane 0's word is captured on its way out and replayed alongside lane
// 1's, so both lanes still present together and a conflicting pair has
// the same apparent latency as a conflict-free one -- it merely costs
// the machine one extra cycle. `conflict` remains an output for
// observability only; nothing outside needs to act on it.
//
// Serialization is offered only by the L = 2 members of the family: a
// parmemB_L with more lanes would have to freeze the core for up to L
// cycles per conflict, a far less attractive trade.
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
// Byte granularity: each bank is WIDTH/8 independently write-enabled
// 8-bit dpmemrf instances rather than one WIDTH-bit memory with a
// byte-enable port. dpmemrf is shared with other IP and stays
// unchanged; the byte masks (`ben` per lane, `benb` on side B) live
// here. A load ignores them.
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

module parmem3_2
  #(parameter DEPTH    = 10,  //log2 of words per bank; 3*2^DEPTH words total
    parameter WIDTH    = 32,
    parameter STRIDE_W = 12,  //signed stride width, in words; <= DEPTH+2
    parameter ADRREG   = 0,   //register the address phase (+1 cycle, fmax option)
    parameter OUTREGA  = 0,   //extra side-A output register (fmax option)
    parameter OUTREGB  = 0,   //extra side-B output register (fmax option)
    parameter NB       = WIDTH/8)  //byte slices per bank -- derived, do not override

   (//Side A: one dual strided load/store access pair
    input  logic                clka,
    input  logic                en,
    input  logic                wen,      //shared by the pair (0 = load)
    input  logic [1:0]          lane_en,  //per-lane enable
    input  logic [DEPTH+1:0]    addr,     //lane 0 linear address
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
    input  logic [DEPTH+1:0]    addrb,
    input  logic [WIDTH-1:0]    dib,
    output logic [WIDTH-1:0]    dob,
    output logic                oobb);

   localparam AW = DEPTH + 2;        //linear address width, 3*2^DEPTH < 2^AW
   localparam CM = (STRIDE_W % 2 == 0) ? 1 : 2;  // 2^STRIDE_W mod 3

   //cycles from access issue to bank data valid on side A
   localparam int SER_D = ADRREG + 1 + OUTREGA;

   initial begin
      assert (STRIDE_W <= AW)
        else $fatal(1, "STRIDE_W must be <= DEPTH + 2");
      assert (WIDTH % 8 == 0)
        else $fatal(1, "WIDTH must be a multiple of 8 (byte-sliced banks)");
   end


   // mod-3 digit fold: sixteen base-4 digits, plain sum (4 == +1 mod 3,
   // casting out threes); first-fold value <= 16*3 = 48 (6 bits)
   localparam SRW = 6;

   //----------------------------------------------------------------
   // mod-3 helpers (all arithmetic on narrow bounded vectors -- the
   // 32-bit int formulation was measured to map onto CARRY8 chains on
   // UltraScale+)
   //----------------------------------------------------------------
   function automatic logic [1:0] mod3(input logic [31:0] a);
      logic [SRW-1:0] s;
      begin
         s = '0;
         for (int i = 0; i < 16; i++) begin
            s += SRW'((a >> (2 * i)) & 2'b11);
         end
         // bounded value (s <= 48): constant modulo = small LUT function
         return 2'(s % SRW'(3));
      end
   endfunction

   // one-hot variant: reduction and bank compare fused per output bit
   function automatic logic [2:0] mod3_oh(input logic [31:0] a);
      logic [1:0] r;
      logic [2:0] oh;
      begin
         r = mod3(a);
         for (int b = 0; b < 3; b++) begin
            oh[b] = (r == 2'(b));
         end
         return oh;
      end
   endfunction

   function automatic logic [1:0] f_enc(input logic [2:0] oh);
      logic [1:0] r;
      begin
         r = '0;
         for (int b = 0; b < 3; b++) begin
            if (oh[b]) begin
               r |= 2'(b);
            end
         end
         return r;
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
   logic [2:0]         bank0_oh;
   logic [1:0]         bank0, bank1;
   logic [1:0]         ce;
   logic               same_word, ser_start, ser_phase;
   logic [1:0]         lane_en_eff;

   assign ea1_full = $signed({1'b0, addr})
                     + (AW + 1)'($signed(stride));
   assign idx0 = addr[DEPTH-1:0];
   assign idx1 = ea1_full[DEPTH-1:0];

   // lane 0's bank as a one-hot straight out of the tree (select
   // cone); the binary form (residue chain, return select) derives
   // from it off-cone
   assign bank0_oh = mod3_oh({{(32 - AW){1'b0}}, addr});
   assign bank0    = f_enc(bank0_oh);
   assign bank1    = mod3_add(bank0, scorr);

   //----------------------------------------------------------------
   // Out-of-range: full-width test as a pure check on the sum -- no
   // second carry chain after the adder: negative <=> sign bit;
   // >= 3*2^DEPTH <=> both top bits of the in-range field set
   // (3*2^DEPTH = "11" << DEPTH)
   //----------------------------------------------------------------
   assign oob[0] = en & lane_en_eff[0] & (addr[AW-1:AW-2] == 2'b11);
   assign oob[1] = en & lane_en_eff[1]
                   & (ea1_full[AW] | (ea1_full[AW-1] & ea1_full[AW-2]));

   assign ce = {2{en}} & lane_en_eff & ~oob;

   //----------------------------------------------------------------
   // same_word vs conflict. Both lanes land on one bank when the stride
   // residue is zero; a ZERO stride additionally puts them on the same
   // word (bank1 == bank0 and idx1 == idx0).
   //
   // On a READ that costs nothing and needs no serialization: the one
   // bank access is issued for lane 0, and the return path hands the
   // same word to both lanes because their bank selects are equal. This
   // is what makes a contiguous sub-word pair (byte stride < 4, so word
   // stride 0) a single-cycle access -- the LS unit extracts a
   // different element per lane from the shared word.
   //
   // On a WRITE it does NOT: the two lanes carry different byte masks
   // and different data, and one access presents only one of each, so a
   // same-word store serializes like any other conflict. Merging the
   // two lanes' bytes into one access was tried and dropped -- it is
   // the only mergeable case in the whole ISA, and packing the pair in
   // the ALU ahead of a plain store costs the compiler nothing.
   //----------------------------------------------------------------
   assign same_word = en & (stride == '0) & (lane_en == 2'b11);
   assign conflict  = en & (scorr == 2'd0) & (lane_en == 2'b11)
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
   // the EA1 adder and oob logic never enter the address/data select
   // cone
   //----------------------------------------------------------------
   logic [2:0]       ena_bank, wea_bank;
   logic [DEPTH-1:0] addra_bank [0:2];
   logic [WIDTH-1:0] dia_bank [0:2];
   logic [NB-1:0]    ben_bank [0:2];

   generate
      for (genvar b = 0; b < 3; b = b + 1) begin: gen_asteer
         logic [1:0] rawm, sel;

         assign rawm[0] = lane_en_eff[0] & bank0_oh[b];
         assign rawm[1] = lane_en_eff[1] & (bank1 == b[1:0]);

         assign sel[0] = rawm[0];
         assign sel[1] = rawm[1] & ~rawm[0];

         assign ena_bank[b] = |(sel & ce);
         assign wea_bank[b] = ena_bank[b] & wen;

         assign addra_bank[b] = rawm[0] ? idx0 : idx1;
         assign dia_bank[b]   = rawm[0] ? dia[0 +: WIDTH] : dia[WIDTH +: WIDTH];
         assign ben_bank[b]   = rawm[0] ? ben[0 +: NB]   : ben[NB +: NB];
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
   logic [NB-1:0]    ben_bank_q [0:2];
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
         for (genvar b = 0; b < 3; b = b + 1) begin: gen_pass
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
   logic [2:0]       bankb_oh;
   logic [1:0]       bankb;
   logic [DEPTH-1:0] idxb;
   logic             ceb;
   logic [2:0]       enb_bank, web_bank;

   assign bankb_oh = mod3_oh({{(32 - AW){1'b0}}, addrb});
   assign bankb    = f_enc(bankb_oh);
   assign idxb     = addrb[DEPTH-1:0];
   assign oobb     = enb & (addrb[AW-1:AW-2] == 2'b11);
   assign ceb      = enb & ~oobb;

   generate
      for (genvar b = 0; b < 3; b = b + 1) begin: gen_bsteer
         assign enb_bank[b] = ceb & bankb_oh[b];
         assign web_bank[b] = enb_bank[b] & web;
      end
   endgenerate

   //----------------------------------------------------------------
   // Banks: true dual port, dual clock, READ_FIRST both sides
   //----------------------------------------------------------------
   logic [WIDTH-1:0] bankdoa [0:2];
   logic [WIDTH-1:0] bankdob [0:2];

   // Each bank is NB independently write-enabled 8-bit memories: the
   // byte mask is the per-slice write enable, so dpmemrf keeps its
   // single-bit `wea`/`web` and needs no byte-enable port.
   generate
      for (genvar b = 0; b < 3; b = b + 1) begin: gen_bank
         for (genvar k = 0; k < NB; k = k + 1) begin: gen_slice
            dpmemrf #(.DEPTH(DEPTH), .WIDTH(8),
                      .OUTREGA(OUTREGA), .OUTREGB(OUTREGB))
            slice_inst (.clka(clka), .ena(ena_bank_q[b]),
                        .wea(wea_bank_q[b] & ben_bank_q[b][k]),
                        .addra(addra_bank_q[b]),
                        .dia(dia_bank_q[b][8*k +: 8]),
                        .doa(bankdoa[b][8*k +: 8]),
                        .clkb(clkb), .enb(enb_bank[b]),
                        .web(web_bank[b] & benb[k]),
                        .addrb(idxb), .dib(dib[8*k +: 8]),
                        .dob(bankdob[b][8*k +: 8]));
         end
      end
   endgenerate

   //----------------------------------------------------------------
   // Return path: per-lane 3:1 bank mux, select = registered bank id
   // aligned with the bank read latency (1 + OUTREG cycles)
   //----------------------------------------------------------------
   logic [1:0][1:0]  bank_r;
   logic [1:0]       bankb_r;

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
   // ser_dly[n-1] is ser_start delayed n cycles; SER_D is the issue ->
   // data-valid distance, so the capture is at SER_D and the replay one
   // cycle after it.
   //
   // The replay is folded INTO the bank mux rather than stacked after
   // it: the hold register is a fourth input of what was a 3:1 select,
   // and a 4:1 mux still fits one LUT6. Stacking a 2:1 on top of the
   // 3:1 was measured to add a logic level on the bank-output -> doa
   // path and to violate 5 ns on xc7z020-1.
   //----------------------------------------------------------------
   localparam logic [1:0] SEL_HOLD = 2'd3;   // the unused bank code

   logic [SER_D:0]   ser_dly;
   logic [WIDTH-1:0] doa0_hold;
   logic [1:0]       sel0, sel1;
   logic [WIDTH-1:0] doa0_out, doa1_out;

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
        2'd0:    doa0_out = bankdoa[0];
        2'd1:    doa0_out = bankdoa[1];
        2'd2:    doa0_out = bankdoa[2];
        default: doa0_out = doa0_hold;
      endcase
      case (sel1)
        2'd0:    doa1_out = bankdoa[0];
        2'd1:    doa1_out = bankdoa[1];
        default: doa1_out = bankdoa[2];
      endcase
   end

   // Captured from the mux output itself: at capture time sel0 still
   // points at lane 0's bank, so this is bankdoa[bank_r[0]] without a
   // second 3:1 select. The path through doa0_hold is broken by the
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


endmodule // parmem3_2
