// large_matmul_4m.cpp — Tiled GeMV y=W·x on 4×4 HyNoC, 4 corner masters
//
// Same LLaMA 3 8B FFN dimensions as large_matmul, 4 corner masters each
// owning a 2×2 quadrant with no shared inter-quadrant links.
//
//   Master 0 (0,0): workers (0,1),(1,0),(1,1)  rows [0..3583]
//   Master 1 (0,3): workers (0,2),(1,3),(1,2)  rows [3584..7167]
//   Master 2 (3,0): workers (3,1),(2,0),(2,1)  rows [7168..10751]
//   Master 3 (3,3): workers (3,2),(2,3),(2,2)  rows [10752..14335]
//
// All 4 masters inject simultaneously; expected ~4× speedup over 1-master.
// Q8_0+BF16 packet format identical to large_matmul.
//
// Port convention: 0=Local 1=East 2=South 3=West 4=North

#include "Vhynoc_router_5p.h"
#include "verilated.h"

#include <cassert>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <queue>
#include <vector>

static constexpr int R = 4;
static constexpr int C = 4;
static constexpr int NM = 4;
static constexpr int NW = 3;
static constexpr int D_IN = 4096;
static constexpr int D_OUT = 14336;
static constexpr int Q_ROWS = D_OUT / NM;        // 3584 rows per quadrant
static constexpr int ROUNDS = Q_ROWS / (NW + 1); // 896 rounds per master
static constexpr int BLOCKS = D_IN / 32;         // 128 Q8_0 blocks
static constexpr int NP = 5;

static_assert(D_OUT % NM == 0);
static_assert(Q_ROWS % (NW + 1) == 0);
static_assert(D_IN % 32 == 0);
static_assert(D_IN % 2 == 0);

static constexpr int W_FLITS = BLOCKS * 9;
static constexpr int X_FLITS = D_IN / 2;
static constexpr int PAY_FLITS = 1 + W_FLITS + X_FLITS;

static const int MROW[NM] = {0, 0, 3, 3};
static const int MCOL[NM] = {0, 3, 0, 3};
static const int WROW[NM][NW] = {{0, 1, 1}, {0, 1, 1}, {3, 2, 2}, {3, 2, 2}};
static const int WCOL[NM][NW] = {{1, 0, 1}, {2, 3, 2}, {1, 0, 1}, {2, 3, 2}};

// ── Number format utilities ───────────────────────────────────────────────────

static uint16_t float_to_fp16(float f)
{
    uint32_t b;
    memcpy(&b, &f, 4);
    uint16_t sign = (uint16_t)((b >> 31) & 0x1u);
    int32_t exp = (int32_t)((b >> 23) & 0xFFu) - 127 + 15;
    uint16_t mant = (uint16_t)((b >> 13) & 0x3FFu);
    if(exp <= 0)
        return (uint16_t)(sign << 15);
    if(exp >= 31)
        return (uint16_t)((sign << 15) | 0x7C00u);
    return (uint16_t)((sign << 15) | ((uint16_t)exp << 10) | mant);
}

static float fp16_to_float(uint16_t h)
{
    uint16_t sign = (h >> 15) & 0x1u;
    uint16_t exp = (h >> 10) & 0x1Fu;
    uint16_t mant = h & 0x3FFu;
    uint32_t b;
    if(exp == 0)
        b = ((uint32_t)sign << 31) | ((uint32_t)mant << 13);
    else if(exp == 31)
        b = ((uint32_t)sign << 31) | 0x7F800000u | ((uint32_t)mant << 13);
    else
        b = ((uint32_t)sign << 31) | ((uint32_t)(exp - 15u + 127u) << 23) | ((uint32_t)mant << 13);
    float f;
    memcpy(&f, &b, 4);
    return f;
}

static uint16_t float_to_bf16(float f)
{
    uint32_t b;
    memcpy(&b, &f, 4);
    return (uint16_t)(b >> 16);
}

static float bf16_to_float(uint16_t bf)
{
    uint32_t b = (uint32_t)bf << 16;
    float f;
    memcpy(&f, &b, 4);
    return f;
}

// ── Routing ──────────────────────────────────────────────────────────────────

static int opp(int p)
{
    const int t[5] = {0, 3, 4, 1, 2};
    return t[p];
}

static int dir2port(int axis, int dir)
{
    return (axis == 0) ? (dir > 0 ? 1 : 3) : (dir > 0 ? 2 : 4);
}

static std::vector<uint8_t> xy_hops(int r0, int c0, int r1, int c1)
{
    std::vector<uint8_t> hops;
    int j = 0;
    auto push = [&](int axis, int delta) {
        if(!delta)
            return;
        int phys = dir2port(axis, delta);
        int steps = delta > 0 ? delta : -delta;
        for(int s = 0; s < steps; ++s) {
            hops.push_back((uint8_t)((phys - 1 - j + NP * 100) % NP));
            j = opp(phys);
        }
    };
    push(0, c1 - c0);
    push(1, r1 - r0);
    hops.push_back((uint8_t)((0 - 1 - j + NP * 100) % NP));
    return hops;
}

static uint64_t make_route(int r0, int c0, int r1, int c1)
{
    auto h = xy_hops(r0, c0, r1, c1);
    assert(!h.empty());
    uint64_t f = (uint64_t)(h.size() - 1);
    for(int k = 0; k < (int)h.size(); ++k)
        f |= (uint64_t)(h[k] & 3u) << (4 + 2 * ((int)h.size() - 1 - k));
    return f;
}

static uint64_t dflit(uint32_t v, bool last) { return ((uint64_t)(last ? 1u : 0u) << 32) | v; }

// ── Inter-router link state ───────────────────────────────────────────────────

struct Link
{
    uint64_t data = 0;
    uint8_t write = 0, level = 0;
};
static Link EW[R][C - 1], WE[R][C - 1];
static Link SN[R - 1][C], NS[R - 1][C];

static VerilatedContext *ctx;
static Vhynoc_router_5p *routers[R][C];

static void capture_links()
{
    for(int r = 0; r < R; ++r)
        for(int c = 0; c < C - 1; ++c) {
            auto &a = *routers[r][c];
            auto &b = *routers[r][c + 1];
            EW[r][c] = {a.port1_egress_data, a.port1_egress_write, b.port3_ingress_fifo_level};
            WE[r][c] = {b.port3_egress_data, b.port3_egress_write, a.port1_ingress_fifo_level};
        }
    for(int r = 0; r < R - 1; ++r)
        for(int c = 0; c < C; ++c) {
            auto &a = *routers[r][c];
            auto &b = *routers[r + 1][c];
            SN[r][c] = {a.port2_egress_data, a.port2_egress_write, b.port4_ingress_fifo_level};
            NS[r][c] = {b.port4_egress_data, b.port4_egress_write, a.port2_ingress_fifo_level};
        }
}

static void apply_links()
{
    for(int r = 0; r < R; ++r)
        for(int c = 0; c < C; ++c) {
            auto &d = *routers[r][c];
            d.port1_ingress_write = 0;
            d.port1_ingress_data = 0;
            d.port1_egress_fifo_level = 0;
            d.port2_ingress_write = 0;
            d.port2_ingress_data = 0;
            d.port2_egress_fifo_level = 0;
            d.port3_ingress_write = 0;
            d.port3_ingress_data = 0;
            d.port3_egress_fifo_level = 0;
            d.port4_ingress_write = 0;
            d.port4_ingress_data = 0;
            d.port4_egress_fifo_level = 0;
            d.port0_egress_fifo_level = 0;
        }
    for(int r = 0; r < R; ++r)
        for(int c = 0; c < C - 1; ++c) {
            routers[r][c + 1]->port3_ingress_data = EW[r][c].data;
            routers[r][c + 1]->port3_ingress_write = EW[r][c].write;
            routers[r][c]->port1_egress_fifo_level = EW[r][c].level;
            routers[r][c]->port1_ingress_data = WE[r][c].data;
            routers[r][c]->port1_ingress_write = WE[r][c].write;
            routers[r][c + 1]->port3_egress_fifo_level = WE[r][c].level;
        }
    for(int r = 0; r < R - 1; ++r)
        for(int c = 0; c < C; ++c) {
            routers[r + 1][c]->port4_ingress_data = SN[r][c].data;
            routers[r + 1][c]->port4_ingress_write = SN[r][c].write;
            routers[r][c]->port2_egress_fifo_level = SN[r][c].level;
            routers[r][c]->port2_ingress_data = NS[r][c].data;
            routers[r][c]->port2_ingress_write = NS[r][c].write;
            routers[r + 1][c]->port4_egress_fifo_level = NS[r][c].level;
        }
}

static void clk_edge(uint8_t val)
{
    for(int r = 0; r < R; ++r)
        for(int c = 0; c < C; ++c) {
            auto &d = *routers[r][c];
            d.router_clk = val;
            d.port0_ingress_clk = d.port1_ingress_clk = d.port2_ingress_clk = d.port3_ingress_clk =
                d.port4_ingress_clk = val;
            d.eval();
        }
}

// ── Problem data (static — too large for stack at LLaMA scale) ───────────────

static int8_t W[D_OUT][D_IN];
static float y_ref[D_OUT];
static float y[D_OUT];
static bool y_rx[D_OUT];

// ── Main ─────────────────────────────────────────────────────────────────────

int main(int argc, char **argv)
{
    ctx = new VerilatedContext;
    ctx->commandArgs(argc, argv);

    char name[16];
    for(int r = 0; r < R; ++r)
        for(int c = 0; c < C; ++c) {
            snprintf(name, sizeof(name), "r%d%d", r, c);
            routers[r][c] = new Vhynoc_router_5p(ctx, name);
        }

    // Build node-to-master lookup
    int node_to_master[R][C];
    bool node_is_master[R][C];
    memset(node_to_master, -1, sizeof(node_to_master));
    memset(node_is_master, 0, sizeof(node_is_master));
    for(int m = 0; m < NM; ++m) {
        node_is_master[MROW[m]][MCOL[m]] = true;
        node_to_master[MROW[m]][MCOL[m]] = m;
        for(int p = 0; p < NW; ++p)
            node_to_master[WROW[m][p]][WCOL[m][p]] = m;
    }

    // Weights, activations, reference
    float x[D_IN];
    for(int i = 0; i < D_OUT; ++i)
        for(int k = 0; k < D_IN; ++k)
            W[i][k] = (int8_t)((i % 8 + 1) * (k % 4 + 1));
    for(int k = 0; k < D_IN; ++k)
        x[k] = (float)(k % 4 + 1);
    memset(y_ref, 0, sizeof(y_ref));
    for(int i = 0; i < D_OUT; ++i)
        for(int k = 0; k < D_IN; ++k)
            y_ref[i] += (float)W[i][k] * x[k];

    const uint16_t SCALE_FP16 = float_to_fp16(1.0f);

    // Build TX queues for all 4 masters simultaneously
    std::queue<uint64_t> tx[R][C];
    for(int m = 0; m < NM; ++m) {
        int mr = MROW[m], mc = MCOL[m];
        for(int t = 0; t < ROUNDS; ++t) {
            for(int p = 0; p < NW; ++p) {
                int row = m * Q_ROWS + t * (NW + 1) + p + 1;
                int dr = WROW[m][p], dc = WCOL[m][p];
                tx[mr][mc].push(make_route(mr, mc, dr, dc));
                tx[mr][mc].push(dflit((uint32_t)row, false));
                for(int b = 0; b < BLOCKS; ++b) {
                    tx[mr][mc].push(dflit((uint32_t)SCALE_FP16, false));
                    for(int j = 0; j < 8; ++j) {
                        uint32_t wf = 0;
                        for(int mm = 0; mm < 4; ++mm)
                            wf |= ((uint32_t)(uint8_t)W[row][b * 32 + j * 4 + mm]) << (mm * 8);
                        tx[mr][mc].push(dflit(wf, false));
                    }
                }
                for(int k = 0; k < D_IN / 2; ++k) {
                    uint32_t xf = ((uint32_t)float_to_bf16(x[2 * k + 1]) << 16) |
                                  (uint32_t)float_to_bf16(x[2 * k]);
                    tx[mr][mc].push(dflit(xf, k == D_IN / 2 - 1));
                }
            }
        }
    }

    // Reset
    for(int r = 0; r < R; ++r)
        for(int c = 0; c < C; ++c) {
            auto &d = *routers[r][c];
            d.router_srst = 1;
            d.port0_ingress_srst = d.port1_ingress_srst = d.port2_ingress_srst =
                d.port3_ingress_srst = d.port4_ingress_srst = 1;
            d.port0_ingress_write = 0;
            d.port0_ingress_data = 0;
            d.port0_egress_fifo_level = 0;
        }
    for(int i = 0; i < 20; ++i) {
        clk_edge(1);
        clk_edge(0);
    }
    for(int r = 0; r < R; ++r)
        for(int c = 0; c < C; ++c) {
            auto &d = *routers[r][c];
            d.router_srst = 0;
            d.port0_ingress_srst = d.port1_ingress_srst = d.port2_ingress_srst =
                d.port3_ingress_srst = d.port4_ingress_srst = 0;
        }
    for(int i = 0; i < 5; ++i) {
        apply_links();
        clk_edge(1);
        capture_links();
        clk_edge(0);
    }

    // Compute local rows for all 4 masters (row m*Q_ROWS + t*(NW+1) per round t)
    memset(y, 0, sizeof(y));
    memset(y_rx, 0, sizeof(y_rx));
    for(int m = 0; m < NM; ++m) {
        for(int t = 0; t < ROUNDS; ++t) {
            int row = m * Q_ROWS + t * (NW + 1);
            for(int k = 0; k < D_IN; ++k)
                y[row] += (float)W[row][k] * x[k];
            y_rx[row] = true;
        }
    }
    int results = NM * ROUNDS; // 3584 local rows already done

    // Worker packet accumulation buffers
    std::vector<uint32_t> wpkt[R][C];

    // Per-master RX state
    bool in_result[NM] = {};
    uint32_t ptag[NM] = {};

    // Link utilization counters
    uint64_t link_ew[R][C - 1] = {}, link_we[R][C - 1] = {};
    uint64_t link_sn[R - 1][C] = {}, link_ns[R - 1][C] = {};

    const uint64_t MAX_CYCLES = 50000000ULL;
    uint64_t cycles = 0;

    for(; cycles < MAX_CYCLES && results < D_OUT; ++cycles) {
        apply_links();

        // Drive TX for all nodes (only masters have non-empty pre-built queues;
        // workers push result packets dynamically)
        for(int r = 0; r < R; ++r)
            for(int c = 0; c < C; ++c) {
                auto &d = *routers[r][c];
                if(!tx[r][c].empty() && !d.port0_ingress_full) {
                    d.port0_ingress_data = tx[r][c].front();
                    d.port0_ingress_write = 1;
                    tx[r][c].pop();
                } else {
                    d.port0_ingress_write = 0;
                }
            }

        clk_edge(1);

        // Sample RX from all nodes
        for(int r = 0; r < R; ++r)
            for(int c = 0; c < C; ++c) {
                auto &d = *routers[r][c];
                if(!d.port0_egress_write)
                    continue;
                uint64_t flit = d.port0_egress_data;
                bool stop = (flit >> 32) & 1u;
                uint32_t val = (uint32_t)(flit & 0xFFFFFFFFu);

                if(node_is_master[r][c]) {
                    // Result packet: [tag][fp32_result(last)]
                    int m = node_to_master[r][c];
                    if(!in_result[m]) {
                        ptag[m] = val;
                        in_result[m] = true;
                    } else {
                        assert(stop);
                        int row = (int)ptag[m];
                        if(row >= 0 && row < D_OUT && !y_rx[row]) {
                            float res;
                            memcpy(&res, &val, 4);
                            y[row] = res;
                            y_rx[row] = true;
                            ++results;
                        }
                        in_result[m] = false;
                    }
                } else {
                    // Forward packet: [tag][W_FLITS flits][X_FLITS flits]
                    wpkt[r][c].push_back(val);
                    if(stop) {
                        uint32_t row = wpkt[r][c][0];

                        // Decode BF16 activations
                        float x_local[D_IN];
                        const int xs = 1 + W_FLITS;
                        for(int k = 0; k < D_IN / 2; ++k) {
                            uint32_t xf = wpkt[r][c][xs + k];
                            x_local[2 * k] = bf16_to_float((uint16_t)(xf & 0xFFFF));
                            x_local[2 * k + 1] = bf16_to_float((uint16_t)(xf >> 16));
                        }

                        // Q8_0 dot product in FP32
                        float dot = 0.0f;
                        for(int b = 0; b < BLOCKS; ++b) {
                            float scale = fp16_to_float((uint16_t)(wpkt[r][c][1 + b * 9] & 0xFFFF));
                            float partial = 0.0f;
                            for(int j = 0; j < 8; ++j) {
                                uint32_t wf = wpkt[r][c][1 + b * 9 + 1 + j];
                                for(int mm = 0; mm < 4; ++mm) {
                                    int8_t q = (int8_t)((wf >> (mm * 8)) & 0xFF);
                                    partial += (float)q * x_local[b * 32 + j * 4 + mm];
                                }
                            }
                            dot += scale * partial;
                        }

                        // Send FP32 result back to owning master
                        uint32_t rbits;
                        memcpy(&rbits, &dot, 4);
                        int mi = node_to_master[r][c];
                        tx[r][c].push(make_route(r, c, MROW[mi], MCOL[mi]));
                        tx[r][c].push(dflit(row, false));
                        tx[r][c].push(dflit(rbits, true));
                        wpkt[r][c].clear();
                    }
                }
            }

        capture_links();
        for(int r = 0; r < R; ++r)
            for(int c = 0; c < C - 1; ++c) {
                link_ew[r][c] += EW[r][c].write;
                link_we[r][c] += WE[r][c].write;
            }
        for(int r = 0; r < R - 1; ++r)
            for(int c = 0; c < C; ++c) {
                link_sn[r][c] += SN[r][c].write;
                link_ns[r][c] += NS[r][c].write;
            }
        clk_edge(0);
    }

    for(int r = 0; r < R; ++r)
        for(int c = 0; c < C; ++c) {
            routers[r][c]->final();
            delete routers[r][c];
        }
    delete ctx;

    // ── Results ───────────────────────────────────────────────────────────────
    printf("HyNoC 4×4 mesh — LLaMA 3 8B FFN up-projection: y = W·x (4 corner masters)\n");
    printf("W[%d×%d] Q8_0, x[%d] BF16, %d masters × %d workers, %d rounds/master\n", D_OUT, D_IN,
           D_IN, NM, NW, ROUNDS);
    printf("Quadrant: %d rows/master, forward packet: %d payload flits\n", Q_ROWS, PAY_FLITS);
    printf("Total simulation cycles: %llu\n\n", (unsigned long long)cycles);

    int pass_count = 0, fail_count = 0;
    for(int i = 0; i < D_OUT; ++i) {
        bool ok = y_rx[i] && (y[i] == y_ref[i]);
        if(ok)
            ++pass_count;
        else {
            ++fail_count;
            printf("FAIL row %d: expected %.1f got %.1f\n", i, y_ref[i], y_rx[i] ? y[i] : 0.0f);
        }
    }
    printf("Correctness: %d/%d PASS%s\n\n", pass_count, D_OUT,
           fail_count ? " — SOME FAILURES" : " — ALL PASS");

    // ── Link utilization ──────────────────────────────────────────────────────
    printf("── Link utilization (%llu cycles) ──\n", (unsigned long long)cycles);
    printf("Direction  Grid      Busy-cyc  Util%%\n");
    uint64_t total_busy = 0, total_cap = 0;
    for(int r = 0; r < R; ++r)
        for(int c = 0; c < C - 1; ++c) {
            printf("E→W        [%d][%d→%d]  %8llu  %5.1f%%\n", r, c, c + 1,
                   (unsigned long long)link_ew[r][c], 100.0 * link_ew[r][c] / cycles);
            printf("W→E        [%d][%d←%d]  %8llu  %5.1f%%\n", r, c, c + 1,
                   (unsigned long long)link_we[r][c], 100.0 * link_we[r][c] / cycles);
            total_busy += link_ew[r][c] + link_we[r][c];
            total_cap += 2 * cycles;
        }
    for(int r = 0; r < R - 1; ++r)
        for(int c = 0; c < C; ++c) {
            printf("S→N        [%d→%d][%d]  %8llu  %5.1f%%\n", r, r + 1, c,
                   (unsigned long long)link_sn[r][c], 100.0 * link_sn[r][c] / cycles);
            printf("N→S        [%d←%d][%d]  %8llu  %5.1f%%\n", r, r + 1, c,
                   (unsigned long long)link_ns[r][c], 100.0 * link_ns[r][c] / cycles);
            total_busy += link_sn[r][c] + link_ns[r][c];
            total_cap += 2 * cycles;
        }
    printf("Overall network link utilization: %.1f%%\n", 100.0 * total_busy / total_cap);

    return fail_count ? 1 : 0;
}
