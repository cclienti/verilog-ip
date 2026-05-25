// matmul.cpp — Verilator testbench: 2×2 matrix multiply demo on hynoc_router_5p
//
// Topology: single 5-port router, all ports on the same clock.
//
//   Port 0 : master — broadcasts tasks, collects results
//   Port 1 : worker — computes C[0][0]
//   Port 2 : worker — computes C[0][1]
//   Port 3 : worker — computes C[1][0]
//   Port 4 : worker — computes C[1][1]
//
// Packet formats (33-bit flits: bit 32 = stop, bits 31:0 = payload):
//   Master → Worker k+1  : [route | tag | a0 | a1 | b0 | b1_last]
//   Worker k+1 → Master  : [route | tag | result_last]
//
// The routing flit (stop=0, proto=0, single hop) is consumed by the router;
// the egress sees only payload flits.
//
// Hop encoding (5-port, INDEX_WIDTH=4, single hop, bits [5:4]):
//   From ingress port src, hop value i selects physical egress (i+1+src) % 5.
//   Routing flit = hop_value << 4.

#include "Vhynoc_router_5p.h"
#include "verilated.h"

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <queue>
#include <vector>

static constexpr int NB_PORTS = 5;

// Hop value to route a single-hop packet from ingress src to physical egress dst.
// Relationship: physical_egress = (hop + 1 + src) % NB_PORTS
static uint32_t hop_value(int src, int dst)
{
    return (uint32_t)((dst - 1 - src + NB_PORTS * 1000) % NB_PORTS);
}

// 33-bit routing flit (stop=0, proto=0, single hop, index=0)
// Layout MSB→LSB: [32]=0, [31:28]=proto=0, [27:6]=0, [5:4]=hop, [3:0]=index=0
static uint64_t route_flit(int src, int dst) { return (uint64_t)hop_value(src, dst) << 4; }

static uint64_t data_flit(uint32_t val, bool last)
{
    return ((uint64_t)(last ? 1u : 0u) << 32) | val;
}

// Compact access to all per-port DUT signals.
struct DutPins
{
    uint64_t *i_data[NB_PORTS];
    uint8_t *i_write[NB_PORTS];
    uint8_t *i_full[NB_PORTS];
    uint8_t *i_srst[NB_PORTS];
    uint8_t *i_clk[NB_PORTS];
    uint64_t *e_data[NB_PORTS];
    uint8_t *e_write[NB_PORTS];
    uint8_t *e_level[NB_PORTS];
};

static void bind(Vhynoc_router_5p &d, DutPins &p)
{
#define BIND(k)                                                                                    \
    p.i_data[k] = &d.port##k##_ingress_data;                                                       \
    p.i_write[k] = &d.port##k##_ingress_write;                                                     \
    p.i_full[k] = &d.port##k##_ingress_full;                                                       \
    p.i_srst[k] = &d.port##k##_ingress_srst;                                                       \
    p.i_clk[k] = &d.port##k##_ingress_clk;                                                         \
    p.e_data[k] = &d.port##k##_egress_data;                                                        \
    p.e_write[k] = &d.port##k##_egress_write;                                                      \
    p.e_level[k] = &d.port##k##_egress_fifo_level;
    BIND(0) BIND(1) BIND(2) BIND(3) BIND(4)
#undef BIND
}

// Both clock edges, no output sampling (used during reset).
static void tick(Vhynoc_router_5p &d, DutPins &p)
{
    d.router_clk = 1;
    for(int k = 0; k < NB_PORTS; ++k)
        *p.i_clk[k] = 1;
    d.eval();
    d.router_clk = 0;
    for(int k = 0; k < NB_PORTS; ++k)
        *p.i_clk[k] = 0;
    d.eval();
}

int main(int argc, char **argv)
{
    VerilatedContext ctx;
    ctx.commandArgs(argc, argv);
    Vhynoc_router_5p dut{&ctx};
    DutPins p;
    bind(dut, p);

    // C = A * B
    const uint32_t A[2][2] = {{1, 2}, {3, 4}};
    const uint32_t B[2][2] = {{5, 6}, {7, 8}};
    // Expected: C = [[19,22],[43,50]]
    const uint32_t C_ref[4] = {19, 22, 43, 50};

    // Build master TX queue (port 0):
    // 4 packets sent sequentially, one per worker port (1-4).
    // Each packet: route + tag + a0 + a1 + b0 + b1_last  (6 flits; route consumed by router)
    std::queue<uint64_t> tx[NB_PORTS];
    for(int w = 0; w < 4; ++w) {
        int dst = w + 1;
        int row = w / 2, col = w % 2;
        tx[0].push(route_flit(0, dst));
        tx[0].push(data_flit((uint32_t)(w + 1), false)); // tag = worker port number
        tx[0].push(data_flit(A[row][0], false));
        tx[0].push(data_flit(A[row][1], false));
        tx[0].push(data_flit(B[0][col], false));
        tx[0].push(data_flit(B[1][col], true));
    }

    // Reset
    dut.router_srst = 1;
    for(int k = 0; k < NB_PORTS; ++k) {
        *p.i_srst[k] = 1;
        *p.i_write[k] = 0;
        *p.i_data[k] = 0;
        *p.e_level[k] = 0; // downstream always has space
    }
    for(int i = 0; i < 20; ++i)
        tick(dut, p);

    dut.router_srst = 0;
    for(int k = 0; k < NB_PORTS; ++k)
        *p.i_srst[k] = 0;
    for(int i = 0; i < 5; ++i)
        tick(dut, p); // stabilize after reset

    // Worker state
    std::vector<uint32_t> wpkt[4]; // flits received by each worker (port k+1)
    bool worker_done[4] = {};

    // Master receive state
    bool in_result = false;
    uint32_t pending_tag = 0;
    uint32_t C_result[4] = {};
    bool C_received[4] = {};
    int master_complete = 0;

    uint64_t cycle_count = 0;
    const int MAX_CYCLES = 2000;

    for(int cycle = 0; cycle < MAX_CYCLES && master_complete < 4; ++cycle) {
        ++cycle_count;

        // --- Drive TX inputs ---
        for(int k = 0; k < NB_PORTS; ++k) {
            if(!tx[k].empty() && !*p.i_full[k]) {
                *p.i_data[k] = tx[k].front();
                *p.i_write[k] = 1;
                tx[k].pop();
            } else {
                *p.i_write[k] = 0;
            }
        }

        // --- Rising edge ---
        dut.router_clk = 1;
        for(int k = 0; k < NB_PORTS; ++k)
            *p.i_clk[k] = 1;
        dut.eval();

        // --- Sample RX outputs (stable after rising edge) ---

        // Workers (ports 1-4): collect flits; on complete packet, compute and reply
        for(int k = 1; k <= 4; ++k) {
            if(!*p.e_write[k])
                continue;
            uint64_t flit = *p.e_data[k];
            bool stop = (flit >> 32) & 1u;
            wpkt[k - 1].push_back((uint32_t)(flit & 0xFFFFFFFFu));
            if(stop && !worker_done[k - 1]) {
                worker_done[k - 1] = true;
                // Packet received: [tag, a0, a1, b0, b1]
                uint32_t tag = wpkt[k - 1][0];
                uint32_t a0 = wpkt[k - 1][1];
                uint32_t a1 = wpkt[k - 1][2];
                uint32_t b0 = wpkt[k - 1][3];
                uint32_t b1 = wpkt[k - 1][4];
                uint32_t result = a0 * b0 + a1 * b1;
                tx[k].push(route_flit(k, 0));
                tx[k].push(data_flit(tag, false));
                tx[k].push(data_flit(result, true));
            }
        }

        // Master (port 0): parse 2-flit result packets [tag, result_last]
        if(*p.e_write[0]) {
            uint64_t flit = *p.e_data[0];
            bool stop = (flit >> 32) & 1u;
            uint32_t val = (uint32_t)(flit & 0xFFFFFFFFu);
            if(!in_result) {
                pending_tag = val;
                in_result = true;
            } else {
                assert(stop);
                int w = (int)pending_tag - 1;
                if(w >= 0 && w < 4 && !C_received[w]) {
                    C_result[w] = val;
                    C_received[w] = true;
                    ++master_complete;
                }
                in_result = false;
            }
        }

        // --- Falling edge ---
        dut.router_clk = 0;
        for(int k = 0; k < NB_PORTS; ++k)
            *p.i_clk[k] = 0;
        dut.eval();
    }

    dut.final();

    // Report
    printf("HyNoC 5-port router — 2x2 matrix multiply\n");
    printf("A = [[1,2],[3,4]]   B = [[5,6],[7,8]]\n\n");
    printf("%-10s  %8s  %8s  %s\n", "Element", "Expected", "Got", "Status");
    printf("%-10s  %8s  %8s  %s\n", "-------", "--------", "---", "------");

    const char *labels[4] = {"C[0][0]", "C[0][1]", "C[1][0]", "C[1][1]"};
    bool pass = true;
    for(int w = 0; w < 4; ++w) {
        bool ok = C_received[w] && (C_result[w] == C_ref[w]);
        printf("%-10s  %8u  %8u  %s\n", labels[w], C_ref[w], C_received[w] ? C_result[w] : 0u,
               ok ? "PASS" : "FAIL");
        if(!ok)
            pass = false;
    }

    printf("\nSimulation cycles: %llu\n", (unsigned long long)cycle_count);
    printf("%s\n", pass ? "\nALL PASS" : "\nSOME FAILURES");

    return pass ? 0 : 1;
}
