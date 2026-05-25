// matmul_mesh.cpp — Distributed y = A·x on a 4×4 HyNoC mesh
//
// 16 hynoc_router_5p instances wired as a 4×4 2D mesh.
// Port convention per router: 0=Local  1=East  2=South  3=West  4=North
// XY routing (X first, then Y) guarantees deadlock freedom.
//
// Master at (0,0): sends each worker its row of A and the shared vector x,
// collects results.  A[16×4], x[4×1] → y[16×1].
//
// Inter-router links are latched after the rising edge and applied before the
// next rising edge, giving one cycle of propagation latency per hop.

#include "Vhynoc_router_5p.h"
#include "verilated.h"

#include <cassert>
#include <cstdio>
#include <cstdint>
#include <queue>
#include <vector>

static constexpr int R = 4;     // rows
static constexpr int C = 4;     // columns
static constexpr int N = R * C; // total nodes
static constexpr int K = 4;     // vector dimension
static constexpr int NP = 5;    // NB_PORTS

// ── Routing ──────────────────────────────────────────────────────────────────

// Opposite ingress port of a given egress direction
// East(1)↔West(3), South(2)↔North(4)
static int opp(int p)
{
    const int t[5] = {0, 3, 4, 1, 2};
    return t[p];
}

// Physical egress port: axis=0→X (col), axis=1→Y (row), dir=±1
static int dir2port(int axis, int dir)
{
    return (axis == 0) ? (dir > 0 ? 1 : 3) : (dir > 0 ? 2 : 4);
}

// XY hop-value sequence from (r0,c0) to (r1,c1) starting at local port 0.
// From ingress port j, hop i selects physical egress (i+1+j) % NP.
static std::vector<uint8_t> xy_hops(int r0, int c0, int r1, int c1)
{
    std::vector<uint8_t> hops;
    int j = 0; // current ingress port (start: local=0)

    auto push = [&](int axis, int delta) {
        if(!delta) {
            return;
        }
        int phys = dir2port(axis, delta);
        int steps = delta > 0 ? delta : -delta;
        for(int s = 0; s < steps; ++s) {
            hops.push_back((uint8_t)((phys - 1 - j + NP * 100) % NP));
            j = opp(phys);
        }
    };
    push(0, c1 - c0); // X first
    push(1, r1 - r0); // Y second
    // Final hop: deliver to local port (egress 0) at destination router
    hops.push_back((uint8_t)((0 - 1 - j + NP * 100) % NP));
    return hops;
}

// 33-bit routing flit: stop[32]=0, proto[31:28]=0,
// hop[k] at [5+2k:4+2k], index=[3:0]=H-1
static uint64_t make_route(int r0, int c0, int r1, int c1)
{
    auto h = xy_hops(r0, c0, r1, c1);
    assert(!h.empty());
    uint64_t f = (uint64_t)(h.size() - 1);
    // h[0] is the first hop (consumed first, at index H-1) → pack at position H-1-0
    for(int k = 0; k < (int)h.size(); ++k) {
        f |= (uint64_t)(h[k] & 3u) << (4 + 2 * ((int)h.size() - 1 - k));
    }
    return f;
}

static uint64_t dflit(uint32_t v, bool last) { return ((uint64_t)(last ? 1u : 0u) << 32) | v; }

// ── Inter-router link state ───────────────────────────────────────────────────
// Signals are latched after rising edge, applied before next rising edge.

struct Link
{
    uint64_t data = 0;
    uint8_t write = 0, level = 0;
};

// EW[r][c] : router(r,c).port1_egress  → router(r,c+1).port3_ingress
// WE[r][c] : router(r,c+1).port3_egress → router(r,c).port1_ingress
static Link EW[R][C - 1], WE[R][C - 1];
// SN[r][c] : router(r,c).port2_egress  → router(r+1,c).port4_ingress
// NS[r][c] : router(r+1,c).port4_egress → router(r,c).port2_ingress
static Link SN[R - 1][C], NS[R - 1][C];

static VerilatedContext *ctx;
static Vhynoc_router_5p *routers[R][C];

// ── Instrumentation ──────────────────────────────────────────────────────────
// Forward (master→worker): flit counts are routing+tag+K+K = 1+1+K+K per packet
static constexpr int FWDPKT = 1 + 1 + K + K; // 10 flits
// Return (worker→master): routing+tag+result = 3 flits
static constexpr int RETPKT = 3;

static uint64_t fwd_tx_cycle[R][C] = {}; // cycle routing flit entered router(0,0) ingress
static uint64_t fwd_rx_cycle[R][C] = {}; // cycle worker received last payload flit
static uint64_t ret_tx_cycle[R][C] = {}; // cycle worker sent routing flit
static uint64_t ret_rx_cycle[R][C] = {}; // cycle master received result flit
static bool ret_tx_fired[R][C] = {};     // guard: only record first flit

static uint64_t link_ew[R][C - 1] = {}; // E→W link busy cycles
static uint64_t link_we[R][C - 1] = {}; // W→E link busy cycles
static uint64_t link_sn[R - 1][C] = {}; // S→N link busy cycles
static uint64_t link_ns[R - 1][C] = {};

static void capture_links()
{
    for(int r = 0; r < R; ++r) {
        for(int c = 0; c < C - 1; ++c) {
            auto &a = *routers[r][c];
            auto &b = *routers[r][c + 1];
            EW[r][c] = {a.port1_egress_data, a.port1_egress_write, b.port3_ingress_fifo_level};
            WE[r][c] = {b.port3_egress_data, b.port3_egress_write, a.port1_ingress_fifo_level};
        }
    }
    for(int r = 0; r < R - 1; ++r) {
        for(int c = 0; c < C; ++c) {
            auto &a = *routers[r][c];
            auto &b = *routers[r + 1][c];
            SN[r][c] = {a.port2_egress_data, a.port2_egress_write, b.port4_ingress_fifo_level};
            NS[r][c] = {b.port4_egress_data, b.port4_egress_write, a.port2_ingress_fifo_level};
        }
    }
}

static void apply_links()
{
    // Default all inter-router inputs to idle
    for(int r = 0; r < R; ++r) {
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
            d.port0_egress_fifo_level = 0; // C++ node always has space
        }
    }
    for(int r = 0; r < R; ++r) {
        for(int c = 0; c < C - 1; ++c) {
            routers[r][c + 1]->port3_ingress_data = EW[r][c].data;
            routers[r][c + 1]->port3_ingress_write = EW[r][c].write;
            routers[r][c]->port1_egress_fifo_level = EW[r][c].level;
            routers[r][c]->port1_ingress_data = WE[r][c].data;
            routers[r][c]->port1_ingress_write = WE[r][c].write;
            routers[r][c + 1]->port3_egress_fifo_level = WE[r][c].level;
        }
    }
    for(int r = 0; r < R - 1; ++r) {
        for(int c = 0; c < C; ++c) {
            routers[r + 1][c]->port4_ingress_data = SN[r][c].data;
            routers[r + 1][c]->port4_ingress_write = SN[r][c].write;
            routers[r][c]->port2_egress_fifo_level = SN[r][c].level;
            routers[r][c]->port2_ingress_data = NS[r][c].data;
            routers[r][c]->port2_ingress_write = NS[r][c].write;
            routers[r + 1][c]->port4_egress_fifo_level = NS[r][c].level;
        }
    }
}

// Toggle router_clk and all portX_ingress_clk, evaluate every router.
static void clk_edge(uint8_t val)
{
    for(int r = 0; r < R; ++r) {
        for(int c = 0; c < C; ++c) {
            auto &d = *routers[r][c];
            d.router_clk = val;
            d.port0_ingress_clk = d.port1_ingress_clk = d.port2_ingress_clk = d.port3_ingress_clk =
                d.port4_ingress_clk = val;
            d.eval();
        }
    }
}

// ── Main ─────────────────────────────────────────────────────────────────────

int main(int argc, char **argv)
{
    ctx = new VerilatedContext;
    ctx->commandArgs(argc, argv);

    char name[16];
    for(int r = 0; r < R; ++r) {
        for(int c = 0; c < C; ++c) {
            snprintf(name, sizeof(name), "r%d%d", r, c);
            routers[r][c] = new Vhynoc_router_5p(ctx, name);
        }
    }

    // Problem data: y = A·x,  A[i][k]=(i+1)*(k+1),  x[k]=k+1
    uint32_t A[N][K], x[K], y_ref[N];
    for(int i = 0; i < N; ++i) {
        for(int k = 0; k < K; ++k) {
            A[i][k] = (uint32_t)((i + 1) * (k + 1));
        }
    }
    for(int k = 0; k < K; ++k) {
        x[k] = (uint32_t)(k + 1);
    }
    for(int i = 0; i < N; ++i) {
        y_ref[i] = 0;
        for(int k = 0; k < K; ++k) {
            y_ref[i] += A[i][k] * x[k];
        }
    }

    // Master TX queue (port 0 of router[0][0]).
    // Packet per worker i (i=1..15): route + tag + A[i][0..3] + x[0..3]
    // Node (0,0) computes y[0] locally; no network packet needed.
    std::queue<uint64_t> tx[R][C];
    for(int i = 1; i < N; ++i) {
        int dr = i / C, dc = i % C;
        tx[0][0].push(make_route(0, 0, dr, dc));
        tx[0][0].push(dflit((uint32_t)i, false)); // tag = node index
        for(int k = 0; k < K; ++k) {
            tx[0][0].push(dflit(A[i][k], false));
        }
        for(int k = 0; k < K; ++k) {
            tx[0][0].push(dflit(x[k], k == K - 1)); // stop on x[K-1]
        }
    }

    // Reset
    for(int r = 0; r < R; ++r) {
        for(int c = 0; c < C; ++c) {
            auto &d = *routers[r][c];
            d.router_srst = 1;
            d.port0_ingress_srst = d.port1_ingress_srst = d.port2_ingress_srst =
                d.port3_ingress_srst = d.port4_ingress_srst = 1;
            d.port0_ingress_write = 0;
            d.port0_ingress_data = 0;
            d.port0_egress_fifo_level = 0;
        }
    }
    for(int i = 0; i < 20; ++i) {
        clk_edge(1);
        clk_edge(0);
    }

    for(int r = 0; r < R; ++r) {
        for(int c = 0; c < C; ++c) {
            auto &d = *routers[r][c];
            d.router_srst = 0;
            d.port0_ingress_srst = d.port1_ingress_srst = d.port2_ingress_srst =
                d.port3_ingress_srst = d.port4_ingress_srst = 0;
        }
    }
    for(int i = 0; i < 5; ++i) {
        apply_links();
        clk_edge(1);
        capture_links();
        clk_edge(0);
    }

    // TX flit counter for master — used to detect routing-flit positions
    int tx00_pops = 0;

    // Worker RX state
    std::vector<uint32_t> wpkt[R][C];
    bool worker_done[R][C] = {};

    // Master RX state
    uint32_t y[N] = {};
    bool y_rx[N] = {};
    y[0] = y_ref[0];
    y_rx[0] = true; // master computes y[0] locally
    int results = 1;

    bool in_result = false;
    uint32_t ptag = 0;

    const int MAX_CYCLES = 10000;
    uint64_t cycles = 0;

    for(int cyc = 0; cyc < MAX_CYCLES && results < N; ++cyc) {
        ++cycles;
        apply_links();

        // Drive local-port TX
        for(int r = 0; r < R; ++r) {
            for(int c = 0; c < C; ++c) {
                auto &d = *routers[r][c];
                if(!tx[r][c].empty() && !d.port0_ingress_full) {
                    d.port0_ingress_data = tx[r][c].front();
                    d.port0_ingress_write = 1;
                    tx[r][c].pop();
                    // Instrumentation: record TX start for routing flits
                    if(r == 0 && c == 0) {
                        if(tx00_pops % FWDPKT == 0) {
                            int idx = tx00_pops / FWDPKT + 1;
                            if(idx < N) {
                                fwd_tx_cycle[idx / C][idx % C] = cycles;
                            }
                        }
                        ++tx00_pops;
                    } else if(!ret_tx_fired[r][c]) {
                        ret_tx_fired[r][c] = true;
                        ret_tx_cycle[r][c] = cycles;
                    }
                } else {
                    d.port0_ingress_write = 0;
                }
            }
        }

        clk_edge(1); // rising edge

        // Sample local-port RX
        for(int r = 0; r < R; ++r) {
            for(int c = 0; c < C; ++c) {
                auto &d = *routers[r][c];
                if(!d.port0_egress_write) {
                    continue;
                }
                uint64_t flit = d.port0_egress_data;
                bool stop = (flit >> 32) & 1u;
                uint32_t val = (uint32_t)(flit & 0xFFFFFFFFu);

                if(r == 0 && c == 0) {
                    // Master: parse 2-flit result packets [tag, result_last]
                    if(!in_result) {
                        ptag = val;
                        in_result = true;
                    } else {
                        assert(stop);
                        int i = (int)ptag;
                        if(i > 0 && i < N && !y_rx[i]) {
                            y[i] = val;
                            y_rx[i] = true;
                            ++results;
                            ret_rx_cycle[i / C][i % C] = cycles;
                        }
                        in_result = false;
                    }
                } else {
                    // Worker: collect packet flits, compute on stop
                    wpkt[r][c].push_back(val);
                    if(stop && !worker_done[r][c]) {
                        worker_done[r][c] = true;
                        fwd_rx_cycle[r][c] = cycles;
                        // Packet layout: [tag, a0..aK-1, x0..xK-1]  (K+K+1 flits)
                        uint32_t tag = wpkt[r][c][0];
                        uint32_t dot = 0;
                        for(int k = 0; k < K; ++k) {
                            dot += wpkt[r][c][1 + k] * wpkt[r][c][1 + K + k];
                        }
                        tx[r][c].push(make_route(r, c, 0, 0));
                        tx[r][c].push(dflit(tag, false));
                        tx[r][c].push(dflit(dot, true));
                    }
                }
            }
        }

        capture_links();
        // Link utilization counters (sampled after rising edge)
        for(int r = 0; r < R; ++r) {
            for(int c = 0; c < C - 1; ++c) {
                link_ew[r][c] += EW[r][c].write;
                link_we[r][c] += WE[r][c].write;
            }
        }
        for(int r = 0; r < R - 1; ++r) {
            for(int c = 0; c < C; ++c) {
                link_sn[r][c] += SN[r][c].write;
                link_ns[r][c] += NS[r][c].write;
            }
        }
        clk_edge(0); // falling edge
    }

    for(int r = 0; r < R; ++r) {
        for(int c = 0; c < C; ++c) {
            routers[r][c]->final();
            delete routers[r][c];
        }
    }
    delete ctx;

    // ── Correctness ───────────────────────────────────────────────────────────
    printf("HyNoC 4x4 mesh — y = A·x  (A[%d×%d], x=[1..%d])\n", N, K, K);
    printf("Total simulation cycles: %llu\n\n", (unsigned long long)cycles);

    bool pass = true;
    printf("%-8s  %8s  %8s  %s\n", "Node", "Expected", "Got", "Status");
    for(int i = 0; i < N; ++i) {
        int r = i / C, c = i % C;
        bool ok = y_rx[i] && y[i] == y_ref[i];
        printf("(%d,%d)    %8u  %8u  %s\n", r, c, y_ref[i], y_rx[i] ? y[i] : 0u,
               ok ? "PASS" : "FAIL");
        if(!ok) {
            pass = false;
        }
    }
    printf("\n%s\n", pass ? "ALL PASS" : "SOME FAILURES");

    // ── Forward latency (master→worker) ───────────────────────────────────────
    // P = K+K+1 payload flits (tag + row + x), H = r+c+1 router hops.
    // Paper formula (dual-clock, PIPELINE=0): L = (T_FIFO+2+T_PRRA)*H + P-1
    //   with T_FIFO=3, T_PRRA=1 → L = 6H + P-1.
    // Simulation adds 1 cycle per inter-router link (H-1 links): L_sim = 7H+P-2.
    const int P_fwd = 1 + K + K; // 9 payload flits visible at egress
    printf("\n── Forward latency: master(0,0) → worker (P=%d payload flits) ──\n", P_fwd);
    printf("%-8s  %4s  %8s  %8s  %8s  %10s  %8s\n", "Node", "H", "TX-cyc", "RX-cyc", "Latency",
           "Formula", "Delta");
    for(int i = 1; i < N; ++i) {
        int r = i / C, c = i % C;
        int H = r + c + 1;
        int lat = (int)(fwd_rx_cycle[r][c] - fwd_tx_cycle[r][c]);
        int formula = 6 * H + P_fwd - 1; // paper formula (no link overhead)
        printf("(%d,%d)    %4d  %8llu  %8llu  %8d  %10d  %8d\n", r, c, H,
               (unsigned long long)fwd_tx_cycle[r][c], (unsigned long long)fwd_rx_cycle[r][c], lat,
               formula, lat - formula);
    }

    // ── Return latency (worker→master) ────────────────────────────────────────
    const int P_ret = 1 + 1; // 2 payload flits (tag + result)
    printf("\n── Return latency: worker → master(0,0) (P=%d payload flits) ──\n", P_ret);
    printf("%-8s  %4s  %8s  %8s  %8s  %10s  %8s\n", "Node", "H", "TX-cyc", "RX-cyc", "Latency",
           "Formula", "Delta");
    for(int i = 1; i < N; ++i) {
        int r = i / C, c = i % C;
        int H = r + c + 1;
        int lat = (int)(ret_rx_cycle[r][c] - ret_tx_cycle[r][c]);
        int formula = 6 * H + P_ret - 1;
        printf("(%d,%d)    %4d  %8llu  %8llu  %8d  %10d  %8d\n", r, c, H,
               (unsigned long long)ret_tx_cycle[r][c], (unsigned long long)ret_rx_cycle[r][c], lat,
               formula, lat - formula);
    }

    // ── Link utilization ──────────────────────────────────────────────────────
    printf("\n── Link utilization (%llu total cycles) ──\n", (unsigned long long)cycles);
    printf("Direction  Grid      Busy-cyc  Util%%\n");
    uint64_t total_link_busy = 0, total_link_cap = 0;
    for(int r = 0; r < R; ++r) {
        for(int c = 0; c < C - 1; ++c) {
            printf("E→W        [%d][%d→%d]  %8llu  %5.1f%%\n", r, c, c + 1,
                   (unsigned long long)link_ew[r][c], 100.0 * link_ew[r][c] / cycles);
            printf("W→E        [%d][%d←%d]  %8llu  %5.1f%%\n", r, c, c + 1,
                   (unsigned long long)link_we[r][c], 100.0 * link_we[r][c] / cycles);
            total_link_busy += link_ew[r][c] + link_we[r][c];
            total_link_cap += 2 * cycles;
        }
    }
    for(int r = 0; r < R - 1; ++r) {
        for(int c = 0; c < C; ++c) {
            printf("S→N        [%d→%d][%d]  %8llu  %5.1f%%\n", r, r + 1, c,
                   (unsigned long long)link_sn[r][c], 100.0 * link_sn[r][c] / cycles);
            printf("N→S        [%d←%d][%d]  %8llu  %5.1f%%\n", r, r + 1, c,
                   (unsigned long long)link_ns[r][c], 100.0 * link_ns[r][c] / cycles);
            total_link_busy += link_sn[r][c] + link_ns[r][c];
            total_link_cap += 2 * cycles;
        }
    }
    printf("Overall network link utilization: %.1f%%\n", 100.0 * total_link_busy / total_link_cap);

    return pass ? 0 : 1;
}
