# Prime-Interleaved Parallel Memory on FPGA: an (M banks × L lanes) Scaling Study

Results document of the `hw/lib/parmem` component family:
`../parmem3_2`, `../parmem5_2`, `../parmem5_4`, `../parmem11_8`,
`../parmem17_16`. Reference model: `hw/vliw/study/crt_addressing.py`.

The design space was first explored with a parameterized
(M ∈ {3, 5, 7, 11, 13, 17} × L ≤ min(M, 16)) generic used as a
measurement instrument — it produced the techniques of §3 and the
calibration of §2. The five standalone components are its production
successors: they embody every accepted technique, add the `ADRREG`
pipelining option, and are the sole source of the §4 results.

## 1. Objective

Quantify area and timing of a prime-interleaved scratchpad serving a strided
group of L accesses per cycle (`EA_i = addr + i·stride`, one instruction) from
M prime banks, using divider-free CRT addressing:

- `bank(EA) = EA mod M` — digit-sum LUT tree (digit width `d` with
  `2^d ≡ ±1 mod M`; alternating "casting-out-elevens" fold for the −1 case);
- `index(EA) = EA mod 2^DEPTH` — the low address bits (bijective since
  `gcd(M, 2^DEPTH) = 1`).

With M prime and L ≤ M, all L lanes are pairwise conflict-free **iff
`stride ≢ 0 (mod M)`** — in particular every power-of-2 stride. The study
question: how far does this scale before the L×M steering dominates?

## 2. Method

- Out-of-context synthesis + place + route (no IOBUFs), Vivado 2025.1,
  non-project batch flow (`project/Makefile`).
- Target devices: **xc7z020clg484-1** (Zynq-7000, slowest 7-series
  speed grade — the original study fabric), **xc7k160tfbg484-2**
  (Kintex-7) and **xcku5p-ffvb676-2-e** (Kintex UltraScale+), all at
  the same constraints.
- Constraints: `clka`/`clkb` = **5.000 ns** (200 MHz target), declared
  asynchronous; **zero-value input/output delays** so the full internal path
  is charged against the period. Achievable fmax = 1 / (5 ns − WNS).
- Configuration: `OUTREGA = OUTREGB = 1` (BRAM output register, 2-cycle
  reads); `DEPTH = 10` (2^10 words/bank), `WIDTH = 32`, `STRIDE_W = 12`.
- Known OOC measurement artifacts, identical across configs: ≈ 1 ns of
  input/output port net charge on the worst path, and hold "violations"
  against ports with no clock tree. Reported slacks are therefore
  **pessimistic bounds**; the instrument is used for *relative* scaling.
- **Instrument calibration**: the generic at (3,2) matches an
  independently hand-written (M=3, L=2) baseline within noise — 312 vs
  ≈ 300 slice LUTs, worst-path slack −0.24 vs +0.03 ns with identical
  6-level path anatomy (≈ 5% area, one LUT-packing level;
  placement-seed sensitivity of the same order).
- Functional verification per configuration: exhaustive bijection fill/read,
  signed-stride group reads/writes, conflict rule, per-lane out-of-range
  (including the negative-sum truncation-alias trap), READ_FIRST, dual-clock
  NI port, both OUTREG settings; cross-checked against the Python golden
  model, plus a second DUT instance with the alternative residue
  implementation compared cycle-by-cycle during bring-up.

## 3. Design techniques and their measured effect

The RTL converged through synthesis-in-the-loop iterations; each
technique below was accepted or rejected on measurement, not argument.
All accepted techniques are present in every family component.

| # | Technique | Measured effect (M3L2 unless noted) |
|---|-----------|-------------------------------------|
| 1 | Value-bounded narrow arithmetic: all mod-tree math on `clog2(SMAX)`-bit vectors with elaboration-computed bounds (never 32-bit `int`) | **1780 → 344 cells (5.2×)** — the naive int version built 32-bit compare/subtract chains (172 CARRY4) |
| 2 | Second digit fold before the reduction (generalizing the hand-coded baseline) | **Rejected: +15 LUTs, +6 CARRY4** — its add/sub pairs cost more than the pruned reduction stages saved at generic width |
| 3 | Final reduction = constant `%` of the bounded value (6–9 bits) instead of a 5-stage conditional-subtract ladder | ladder was 4–5 sequential LUT levels in the bank-select cone; `%` is a 1–2 level LUT function at small M (at M = 17 the tools rebuilt carry arithmetic — visible but not dominant) |
| 4 | Early mux selects: first raw residue match among lanes 0..L−2, **last lane as default**; out-of-range suppression only on the enable/WE cone | removes the EA adders (and their carry chains) from the address/data mux select cone; provably equivalent whenever the bank is enabled |
| 5 | One-hot residue tree output `oh[b] = (s mod M == b)` (reduction and bank compare fused in one LUT); binary encodings derived off-cone | −2 levels on the address-pin cone; −0.34 → −0.13 ns at M3L2 |
| 6 | Per-lane residue as parallel constant multiple `(i·scorr) mod M` (one LUT from the 3–5-bit stride residue) instead of a chained `bank[i−1] + scorr` | the chain was **linear-depth**: 21–26 logic levels at L = 8/16; the parallel form is depth-constant in L (bit-identical at L = 2) |

## 4. Results

Post-route, 5 ns OOC, OUTREG = 1 (2-cycle reads); every row is a
standalone-component measurement, archived under the component's
`project/results/<device>-<config>/` directory. `ADRREG` is the
optional address-phase pipeline register (issue-cycle conflict/oob
contract preserved; side-A reads become 1 + ADRREG + OUTREGA cycles).

### xc7z020-1 (Zynq-7000, slowest speed grade)

| Component  | ADRREG | fmax [MHz] | LUTs | FFs [regs] | CARRY | F7 [muxes] | RAMB36 [tiles] |
|------------|--------|---------|--------|-------|-------|-------|----|
| parmem3_2  | 0 | 203     | 295    | 15    | 4   | 0     | 3  |
| parmem5_2  | 0 | 195     | 484    | 21    | 4   | 0     | 5  |
| parmem5_4  | 0 | 136     | 1 064  | 35    | 16  | 0     | 5  |
| parmem11_8 | 0 | 84      | 4 037  | 81    | 47  | 0     | 11 |
| parmem17_16| 0 | 45      | 10 497 | 187   | 198 | 1 088 | 17 |
| parmem3_2  | 1 | 204     | 254    | 153   | 13  | 0     | 3  |
| parmem5_2  | 1 | 187     | 401    | 249   | 19  | 0     | 5  |
| parmem5_4  | 1 | 150     | 986    | 271   | 16  | 0     | 5  |
| parmem11_8 | 1 | 103     | 4 525  | 605   | 47  | 0     | 11 |
| parmem17_16| 1 | 49      | 10 640 | 1 031 | 198 | 1 088 | 17 |

### xc7k160t-2 (Kintex-7)

| Component  | ADRREG | fmax [MHz] | LUTs | FFs [regs] | CARRY | F7 [muxes] | RAMB36 [tiles] |
|------------|--------|---------|--------|-------|-------|-------|----|
| parmem3_2  | 0 | 301     | 232    | 15    | 4   | 0     | 3  |
| parmem5_2  | 0 | 271     | 367    | 21    | 4   | 0     | 5  |
| parmem5_4  | 0 | **222** | 951    | 35    | 16  | 0     | 5  |
| parmem11_8 | 0 | 157     | 4 011  | 81    | 47  | 0     | 11 |
| parmem17_16| 0 | 80      | 10 501 | 187   | 198 | 1 088 | 17 |
| parmem3_2  | 1 | 338     | 251    | 153   | 13  | 0     | 3  |
| parmem5_2  | 1 | 301     | 376    | 249   | 19  | 0     | 5  |
| parmem5_4  | 1 | 221     | 882    | 271   | 16  | 0     | 5  |
| parmem11_8 | 1 | 188     | 4 474  | 605   | 47  | 0     | 11 |
| parmem17_16| 1 | 90      | 10 701 | 1 031 | 198 | 1 088 | 17 |

### xcku5p-2 (Kintex UltraScale+)

| Component  | ADRREG | fmax [MHz] | LUTs | FFs [regs] | CARRY | F7 [muxes] | RAMB36 [tiles] |
|------------|--------|---------|--------|-------|-------|-------|----|
| parmem3_2  | 0 | 397     | 226    | 15    | 2   | 0     | 3  |
| parmem5_2  | 0 | 353     | 344    | 21    | 2   | 0     | 5  |
| parmem5_4  | 0 | 284     | 926    | 35    | 8   | 0     | 5  |
| parmem11_8 | 0 | **218** | 3 756  | 81    | 25  | 0     | 11 |
| parmem17_16| 0 | 181     | 10 863 | 187   | 79  | 1 088 | 17 |
| parmem3_2  | 1 | **541** | 243    | 153   | 8   | 0     | 3  |
| parmem5_2  | 1 | 510     | 361    | 249   | 12  | 0     | 5  |
| parmem5_4  | 1 | 326     | 849    | 271   | 8   | 0     | 5  |
| parmem11_8 | 1 | 244     | 4 184  | 605   | 25  | 0     | 11 |
| parmem17_16| 1 | 192     | 11 459 | 1 031 | 79  | 1 088 | 17 |

Notes:

- fmax = 1 / (5 ns − WNS) from the post-route `clka` worst slack — an
  **OOC-pessimistic bound** (≈ 1 ns of port-net artifact is included in
  every path, so in-context values run higher); ≥ 200 MHz meets the
  core target. The underlying WNS values, worst-path anatomies and the
  uncritical `clkb` (NI side) figures are in the archived reports.
- LUT counts are taken directly from `report_utilization` ("Slice
  LUTs" on 7-series, "CLB LUTs" on UltraScale+). FFs, F7 and RAMB36
  are identical on every device (architectural state; BRAM = M by
  construction); carries are CARRY4 on 7-series and CARRY8 on
  UltraScale+, roughly halving the count.
- The ADRREG=0 flops are the registered bank-id return selects (plus
  the OUTREG enable chains); ADRREG=1 adds the address-phase stage
  (bank enables/WE/addresses/write data/bank ids) — cheap everywhere,
  since the slices are already occupied by the steering LUTs. F7 muxes
  appear only at M = 17: the 17:1 return muxes pack as LUT6+F7.
- **Latency** (all configs): read data valid 1 + ADRREG + OUTREG
  cycles after the access, identical for single, group, and NI
  accesses — banking adds bandwidth, not latency. +1 cycle
  serialization only when `stride ≡ 0 (mod M)`.

## 5. Analysis

1. **Area follows a clean product law — LUTs grow proportionally to
   L × M** across the five components, on every fabric. The L:1
   steering muxes per bank and M:1 return muxes per lane dominate; the
   CRT trees themselves are ≈ 15–40 LUTs per address and never
   dominate. UltraScale+ is systematically ~10 % cheaper (LUT
   packing), and part of the M17L16 muxing moves into F7 primitives
   not counted as LUTs (a mild droop of its LUT total).
2. **Timing collapses with L·M despite depth-constant residue logic**:
   on 7-series the worst paths are 76–92 % routing — wiring fanout and
   congestion of the L×M steering, not logic depth (path anatomies in
   the archived timing reports).
3. **The combinational-feasibility boundary moves with fabric**: the
   single-cycle 200 MHz limit is L ≤ 2 on Zynq-7000, L ≤ 4 on
   Kintex-7 -2 (222 MHz), and **L ≤ 8 on Kintex UltraScale+**
   (218 MHz; 244 MHz with ADRREG). Path speedup per fabric step is
   ≈ 36 % (Z7020-1 → K7-2) and a further ≈ 25–30 % (K7-2 → KU5P-2).
   Even the BSP point (17, 16) comes within reach on UltraScale+
   (181 MHz combinational, 192 MHz with ADRREG, at 5 % of a KU5P vs
   20 % of a Zynq-7020); its failure mode changes character there —
   on 7-series it is the O(L·M) routing wall, while on UltraScale+
   the leader is ≈ 39 % logic through **CARRY8 chains rebuilt for the
   bounded `% 17` reduction**, so an explicit precomputed LUT table
   (8-bit bounded input, 5-bit output) is the identified next lever,
   worth roughly the remaining deficit.
4. **Pipelining and the contract**: `ADRREG` registers the steering
   *after* conflict/oob are derived from the ports, so the issue-cycle
   stall/trap contract is preserved and only data latency grows —
   pipelining the *detection* itself would instead require request
   queues/replay (a vector-machine memory subsystem). On slow fabric
   at L ≥ 8 the register recovers only 1.6–2.2 ns of a 7–17 ns
   deficit (it cannot shrink the O(L·M) wiring); on fast fabric it
   buys clock headroom (> 250 MHz targets) — the surviving leader is
   then the deliberately combinational port-to-port `stride→conflict`
   path. At L = 2 every Zynq row is at or above target (parmem3_2
   meets outright; parmem5_2 sits within the ≈ ±0.35 ns port-artifact
   band) — ADRREG is never required at that lane count.
5. **Architectural consequence**: the combinational-feasibility
   boundary coincides with the scalar-core boundary, and it is
   fabric-relative. Beyond it, wide data parallelism is better served
   by a SIMD unit with a single aligned wide memory port (bandwidth
   from width — O(L)) and fixed-pattern register shuffles
   (`shuffle_{low|high}_{8|16|32}`) replacing the O(L·M) hardware
   rearrangement network with explicit, pipelinable instructions.

Two technique effects were re-measured at the component level on
UltraScale+ and confirm the §3 table there too. Technique #1
(bounded-vector arithmetic) is what keeps the small-M residue trees
out of carry logic — a 32-bit `int` formulation of the mod-3 fold
measurably maps onto CARRY8 chains. Technique #5 (one-hot fused
residue output) is worth ≈ 0.3 ns of select-cone *routing* on the
UltraScale+ mapper — it is what puts the `parmem3_2` pipelined row at
the family-best **541 MHz** — at a cost of ~+50 LUTs on the Zynq
mapping only (per-bit replication of the fold tree). The residual
CARRY8s of the mod-3 fold could be eliminated entirely with a
modular-addition-tree formulation (pairwise `mod3_add` folding, pure
2-bit LUT nodes) — noted as an option, not pursued: every `parmem3_2`
row meets its target with margin.

## 6. Reproduction

Functional regression of any component, from its `src/` directory:

```sh
iverilog -g2012 -o tb parmem<M>_<L>.sv parmem<M>_<L>_tb.sv \
    ../../../dpmemrf/src/dpmemrf.v && vvp tb
```

Any §4 row, from the component's `project/` directory (results
archived under `project/results/<device>-<config>/`):

```sh
make vivado-gen-post-impl VIVADO_PART=<part> \
    VIVADO_SYNTH_OPTIONS="-flatten_hierarchy full -no_iobuf \
    -generic OUTREGA=1 -generic OUTREGB=1 -generic ADRREG=<0|1>"
```

with `<part>` ∈ xc7z020clg484-1, xc7k160tfbg484-2, xcku5p-ffvb676-2-e.
