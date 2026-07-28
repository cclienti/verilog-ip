# Prime-Interleaved Parallel Memory on FPGA: an (M banks × L lanes) Scaling Study

Results document of the `hw/lib/parmem` component family:
`../parmem3_2`, `../parmem5_2`, `../parmem5_4`, `../parmem11_8`,
`../parmem17_16`. Reference model: `hw/vliw/study/crt_addressing.py`.

The study was conducted with a parameterized (M ∈ {3, 5, 7, 11, 13, 17}
× L ≤ min(M, 16)) generic used as a measurement instrument; it produced
the techniques of §3 and the sweep of §4, and was **retired** once the
five standalone components superseded it — they
carry the pipelining options the generic lacked, and their per-component
structure is the basis for further optimization (deeper internal
registering of `parmem11_8`/`parmem17_16`, per-modulus residue-tree
variants). §4 is the frozen record of the original instrument; §6 holds
the family's live figures. The hand-written baseline used for the
instrument calibration in §2 was `parmem3_2` (then named `parmem3`) in
its original (M=3, L=2) form.

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
  **xc7z020clg484-1** (slowest 7-series speed grade), non-project batch flow
  (`run.sh`, `project/Makefile`).
- Constraints: `clka`/`clkb` = **5.000 ns** (200 MHz target), declared
  asynchronous; **zero-value input/output delays** so the full internal path
  is charged against the period. Achievable fmax = 1 / (5 ns − WNS).
- Configuration: `OUTREGA = OUTREGB = 1` (BRAM output register, 2-cycle
  reads); `DEPTH = 10` (2^10 words/bank), `WIDTH = 32`, `STRIDE_W = 12`.
- Known OOC measurement artifacts, identical across configs: ≈ 1 ns of
  input/output port net charge on the worst path, and hold "violations"
  against ports with no clock tree. Reported slacks are therefore
  **pessimistic bounds**; the instrument is used for *relative* scaling.
- **Instrument calibration**: the generic at (3,2) matches the independently
  hand-written `parmem3` (original form) within noise — 312 vs ≈ 300 slice LUTs, worst-path
  slack −0.24 vs +0.03 ns with identical 6-level path anatomy (≈ 5% area,
  one LUT-packing level; placement-seed sensitivity of the same order).
- Functional verification per configuration: exhaustive bijection fill/read,
  signed-stride group reads/writes, conflict rule, per-lane out-of-range
  (including the negative-sum truncation-alias trap), READ_FIRST, dual-clock
  NI port, both OUTREG settings; cross-checked against the Python golden
  model, plus a second DUT instance with the alternative residue
  implementation compared cycle-by-cycle during bring-up.

## 3. Design techniques and their measured effect

The generic RTL converged through synthesis-in-the-loop iterations; each
technique below was accepted or rejected on measurement, not argument.

| # | Technique | Measured effect (B3L2 unless noted) |
|---|-----------|-------------------------------------|
| 1 | Value-bounded narrow arithmetic: all mod-tree math on `clog2(SMAX)`-bit vectors with elaboration-computed bounds (never 32-bit `int`) | **1780 → 344 cells (5.2×)** — the naive int version built 32-bit compare/subtract chains (172 CARRY4) |
| 2 | Second digit fold before the reduction (generalizing the hand-coded baseline) | **Rejected: +15 LUTs, +6 CARRY4** — its add/sub pairs cost more than the pruned reduction stages saved at generic width |
| 3 | Final reduction = constant `%` of the bounded value (6–9 bits) instead of a 5-stage conditional-subtract ladder | ladder was 4–5 sequential LUT levels in the bank-select cone; `%` is a 1–2 level LUT function at small M (at M = 17 the tools rebuilt carry arithmetic — visible but not dominant) |
| 4 | Early mux selects: first raw residue match among lanes 0..L−2, **last lane as default**; out-of-range suppression only on the enable/WE cone | removes the EA adders (and their carry chains) from the address/data mux select cone; provably equivalent whenever the bank is enabled |
| 5 | One-hot residue tree output `oh[b] = (s mod M == b)` (reduction and bank compare fused in one LUT); binary encodings derived off-cone | −2 levels on the address-pin cone; −0.34 → −0.13 ns at B3L2 |
| 6 | Per-lane residue as parallel constant multiple `(i·scorr) mod M` (one LUT from the 3–5-bit stride residue) instead of a chained `bank[i−1] + scorr` | the chain was **linear-depth**: 21–26 logic levels at L = 8/16; the parallel form is depth-constant in L (bit-identical at L = 2) |

## 4. Results

Post-route, xc7z020-1, 5 ns, OUTREG = 1 (2-cycle reads). `clka` = core side
(strided group), `clkb` = NI side (single linear port).

| Config | LUTs | FFs | F7 mux | RAMB36 | clka WNS (ns) | clkb WNS (ns) | Worst path | Levels | Route share | LUTs/(L·M) |
|--------|------|-----|--------|--------|---------------|---------------|------------|--------|-------------|------------|
| B3L2   | 312  | 15  | 0    | 3  | −0.244  | +0.007 | stride→WE     | 6  | 87 % | 52 |
| B5L2   | 492  | 149¹| 0    | 5  | −0.381  | −0.006 | stride→WE     | 6  | 87 % | 49 |
| B5L4   | 955  | 35  | 0    | 5  | −1.994  | −0.221 | stride→WE     | 9  | 65 % | 48 |
| B11L8  | 4 027 | 81 | 0    | 11 | −7.021  | −2.933 | addr→data mux | 12 | 86 % | 46 |
| B17L16 | 10 161| 187| 1 088| 17 | −17.210 | −6.060 | stride→data mux | 25 | 76 % | 37 |

¹ physical-optimization register replication (fanout fixing), not architectural state.

**Latency** (all configs): read data valid 1 + OUTREG cycles after the access,
identical for single, group, and NI accesses — banking adds bandwidth, not
latency. +1 cycle serialization only when `stride ≡ 0 (mod M)`.

## 5. Analysis

1. **Area follows a clean product law: LUTs ≈ 45–50 × L × M** across all five
   points (the mild droop at B17L16 reflects F7/F8 mux packing). The L:1
   steering muxes per bank and M:1 return muxes per lane dominate; the CRT
   trees themselves are ≈ 15–40 LUTs per address and never dominate.
2. **Timing collapses with L·M despite depth-constant residue logic**: worst
   paths are 76–87 % routing — wiring fanout and congestion of the L×M
   steering, not logic depth. Implied combinational fmax: ≈ 190 MHz (L=2),
   ≈ 143 MHz (L=4), ≈ 83 MHz (L=8), ≈ 45 MHz (L=16) — OOC-pessimistic bounds
   including ≈ 1 ns of port artifacts.
3. **Validity regions**: L = 2 is production-grade (both configs at
   artifact-level slack; the B3L2 instance is at parity with the hand-written
   baseline). L = 4 is marginal — closable at reduced clock or with one
   pipeline register in the steering. **L ≥ 8 is infeasible as a
   combinational single-cycle memory** on this fabric.
4. **Pipelining does not rescue the contract**: registering the steering
   would restore clock rate but makes conflict/out-of-range detection arrive
   after issue — requiring request queues, replay or credit flow control,
   i.e. a vector-machine memory subsystem with W+4/W+5 latency, on top of
   the same O(L·M) wiring (which registers do not shrink).
5. **Architectural consequence**: the combinational-feasibility boundary
   (L ≤ 2–4) coincides with the scalar-core boundary. Wide data parallelism
   is better served by a SIMD unit with a single aligned wide memory port
   (bandwidth from width — O(L)) and fixed-pattern register shuffles
   (`shuffle_{low|high}_{8|16|32}`) replacing the O(L·M) hardware
   rearrangement network with explicit, pipelinable instructions.

## 6. Fabric scaling (production components)

The standalone production components (`parmem3_2`, `parmem5_2`, `parmem5_4` —
same RTL techniques, plus an optional `ADRREG` address-phase pipeline
register that preserves the issue-cycle conflict/oob contract) were re-run
on three fabrics at the same 5 ns OOC yardstick (OUTREG = 1; post-route;
archives under each component's `project/results/`):

| Component  | ADRREG | xc7z020-1 | xc7k160t-2 | xcku5p-2 |
|------------|--------|-----------|------------|----------|
| parmem3_2  | 1 | +0.027 (257 LUTs) | +1.692 (249) | +2.863 (239) |
| parmem5_2  | 1 | −0.536¹ (512¹) | +1.681 (376) | +3.040 (361) |
| parmem5_4  | 0 | −1.994² (955²) | **+0.504** (951) | +1.482 (926) |
| parmem5_4  | 1 | — | +0.469 (882) | +1.930 (849) |
| parmem11_8 | 0 | −7.021² (4 027²) | — | **+0.421** (3 756) |
| parmem11_8 | 1 | — | −0.326 (4 474) | +0.905 (4 184) |
| parmem17_16| 0 | −17.210² (10 161²) | — | −0.531 (10 863) |
| parmem17_16| 1 | — | −6.060 (10 701) | −0.219 (11 459) |

¹ measured without ADRREG (combinational address phase).
² original study-generic figure (§4); re-measurement with the standalone
bodies pending.

Findings:

1. **The L·M area law is fabric-independent** (~240 / ~360 / ~930 /
   ~4 000 / ~11 000 LUTs on every part) — the cost model of §5 carries
   across process generations.
2. **The combinational-feasibility boundary moves with fabric**: the
   single-cycle limit is L ≤ 2 on Zynq-7000, L ≤ 4 on Kintex-7 -2
   (+0.50), and **L ≤ 8 on Kintex UltraScale+** (+0.42 ≈ 218 MHz OOC
   bound; +0.91 ≈ 244 MHz with ADRREG). The architectural argument of
   §5.5 is therefore fabric-relative — but its structure survives:
   every fabric has a lane count where banking prices out and a SIMD
   unit with an aligned wide port takes over.
3. Even the BSP point (17, 16) comes within reach on UltraScale+:
   −0.53 combinational (≈ 181 MHz), −0.22 with ADRREG (≈ 192 MHz), at
   5 % of a KU5P vs 19 % of a Zynq-7020. Its failure mode changes
   character across fabrics: on 7-series it is 76–92 % routing (the
   O(L·M) wall, which the pipeline register cannot shrink — −6.1 on
   K7-2 even with ADRREG), while on UltraScale+ the leader is ≈ 39 %
   logic through **CARRY8 chains that the synthesizer rebuilt for the
   bounded `% 17` reduction** — replacing that final reduction with an
   explicit precomputed LUT table (8-bit bounded input, 5-bit output)
   is the identified next lever, worth roughly the remaining deficit.
4. Path speedup per fabric step: ≈ 36 % (Z7020-1 → K7-2) and a further
   ≈ 25–30 % (K7-2 → KU5P-2).
5. Once the stride→WE cone is registered (or fast enough), the surviving
   leader is the port-to-port `stride→conflict` path, which `ADRREG`
   deliberately leaves combinational — on fast fabric the register buys
   clock headroom (> 250 MHz targets), not 5 ns closure.

## 7. Reproduction

The §4 sweep was produced by the retired study generic and is kept as a
frozen record (the standalone components reproduce its five
configurations with equal or better figures — §6).

Functional regression of any component, from its `src/` directory:

```sh
iverilog -g2012 -o tb parmem<M>_<L>.sv parmem<M>_<L>_tb.sv \
    ../../../dpmemrf/src/dpmemrf.v && vvp tb
```

Fabric-scaling points (§6): in each component's `project/` directory
(results archived under `project/results/<part>-<config>/`):

```sh
make vivado-gen-post-impl VIVADO_PART=<part> \
    VIVADO_SYNTH_OPTIONS="-flatten_hierarchy full -no_iobuf \
    -generic OUTREGA=1 -generic OUTREGB=1 -generic ADRREG=<0|1>"
```

with `<part>` ∈ xc7z020clg484-1, xc7k160tfbg484-2, xcku5p-ffvb676-2-e.
