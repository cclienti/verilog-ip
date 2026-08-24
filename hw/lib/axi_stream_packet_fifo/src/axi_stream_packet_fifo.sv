//-----------------------------------------------------------------------------
// Title         : AXI Stream Packet FIFO
//-----------------------------------------------------------------------------
// File          : axi_stream_packet_fifo.sv
// Author        : Christophe Clienti <cclienti@wavecruncher.net>
// Created       : 2026-08-24
// Last modified : 2026-08-24
//-----------------------------------------------------------------------------
// Description: Store-and-forward packet FIFO with commit/rollback. Frames
// are written speculatively; a clean tlast commits the frame, tuser on any
// beat dooms it and the write pointer rolls back at tlast, so the read
// side only ever produces complete, valid frames -- it has no tuser at
// all. An INFO_WIDTH side-band word (s_info, sampled on the committing
// beat) and the frame length in beats ride in a per-frame sclkfifolut
// pushed only at commit, and are presented stable on m_info/m_length for
// the whole frame, so the consumer knows the length from the first beat
// and can never pop out of step.
//
// Two overflow policies. DROP_ON_FULL=0 backpressures: nothing is ever
// lost, s_axi_tready is combinational on s_axi_tuser (a doomed beat needs
// no room and is always consumed), and every frame must fit in the FIFO:
// a larger one deadlocks the writer, permanently once no older committed
// frame is left for the reader to drain. DROP_ON_FULL=1 never
// backpressures (s_axi_tready is constant one, for line-rate sources like
// a MAC receiver): a frame that meets a full data or info FIFO is dropped
// whole -- committed frames are untouched -- which also disposes of frames
// larger than the FIFO.
//-----------------------------------------------------------------------------
// Copyright (c) 2026 by Christophe Clienti. This model is the confidential and
// proprietary property of Christophe Clienti and the possession or use of this
// file requires a written license from Christophe Clienti.
//------------------------------------------------------------------------------

`timescale 1 ns / 100 ps

module axi_stream_packet_fifo #(
    parameter int DATA_WIDTH   = 8,
    parameter int LOG2_DEPTH   = 11, // data FIFO depth in beats, log2
    parameter int LOG2_FRAMES  = 5,  // committed frames capacity, log2
    parameter int INFO_WIDTH   = 1,  // side-band word width
    parameter bit DROP_ON_FULL = 0   // 1: never stall, drop the losing frame
)(
    input logic                    clock,
    input logic                    sreset,

    // AXI Stream input, tuser dooms the frame
    input logic [DATA_WIDTH-1:0]   s_axi_tdata,
    input logic                    s_axi_tuser,
    input logic                    s_axi_tvalid,
    input logic                    s_axi_tlast,
    output logic                   s_axi_tready,
    input logic [INFO_WIDTH-1:0]   s_info,      // sampled on the committing beat

    // AXI Stream output, complete valid frames only
    output logic [DATA_WIDTH-1:0]  m_axi_tdata,
    output logic                   m_axi_tvalid,
    output logic                   m_axi_tlast,
    input logic                    m_axi_tready,
    output logic [INFO_WIDTH-1:0]  m_info,      // stable for the whole frame
    output logic [LOG2_DEPTH:0]    m_length     // frame length in beats
);

    localparam int PTR_W = LOG2_DEPTH + 1;

    //-------------------------------------------
    // Pointers
    //-------------------------------------------
    // One bit wider than the address so full and empty stay distinct.
    // The readable region is [rptr, cptr); [cptr, wptr) is the frame
    // in flight, reclaimed in one cycle by a rollback.
    logic [PTR_W-1:0] wptr;
    logic [PTR_W-1:0] cptr;
    logic [PTR_W-1:0] rptr;
    logic             doomed;

    //-------------------------------------------
    // Write side
    //-------------------------------------------
    logic fifo_room;
    logic info_full;
    logic info_room;
    logic store_ok;
    logic s_accept;
    logic discard;
    logic store;
    logic commit_now;
    logic consume;

    logic [PTR_W-1:0] frame_len;

    assign fifo_room = (wptr - rptr) != PTR_W'(2**LOG2_DEPTH);
    assign info_room = !info_full;
    assign store_ok  = fifo_room && info_room;

    generate
        if (DROP_ON_FULL != 0) begin : gen_drop_ready
            assign s_axi_tready = 1'b1;
        end
        else begin : gen_stall_ready
            // A doomed beat is consumed without storage, so it never
            // has to wait for room
            assign s_axi_tready = s_axi_tuser || doomed || store_ok;
        end
    endgenerate

    assign s_accept   = s_axi_tvalid && s_axi_tready;
    assign discard    = s_axi_tuser || doomed || !store_ok;
    assign store      = s_accept && !discard;
    assign commit_now = store && s_axi_tlast;
    assign frame_len  = (wptr + PTR_W'(1)) - cptr;

    always_ff @(posedge clock) begin
        if (sreset) begin
            wptr   <= '0;
            cptr   <= '0;
            doomed <= 1'b0;
        end
        else if (s_accept) begin
            if (discard) begin
                if (s_axi_tlast) begin
                    wptr   <= cptr; // roll the dead frame back
                    doomed <= 1'b0;
                end
                else begin
                    doomed <= 1'b1;
                end
            end
            else begin
                wptr <= wptr + PTR_W'(1);
                if (commit_now) begin
                    cptr <= wptr + PTR_W'(1); // commit the frame
                end
            end
        end
    end

    //-------------------------------------------
    // Per-frame info FIFO: {s_info, length}, pushed only at commit so
    // it never needs a rollback of its own
    //-------------------------------------------
    sclkfifolut
    #(
        .LOG2_FIFO_DEPTH (LOG2_FRAMES),
        .FIFO_WIDTH      (INFO_WIDTH + PTR_W),
        .OUTPUT_REG      (0) // head visible combinationally, per frame
    )
    sclkfifolut_inst
    (
        .clk    (clock),
        .srst   (sreset),
        .level  (),
        .ren    (consume && m_axi_tlast),
        .rdata  ({m_info, m_length}),
        .rempty (),
        .wen    (commit_now),
        .wdata  ({s_info, frame_len}),
        .wfull  (info_full)
    );

    //-------------------------------------------
    // Data RAM: written at wptr, read first-word-fall-through
    //-------------------------------------------
    logic [DATA_WIDTH:0]   ram_rdata;
    logic [LOG2_DEPTH-1:0] ram_raddr;
    logic                  ram_ren;

    // The read port only loads when the output can move: held under
    // backpressure (which freezes doa instead of re-reading it) and
    // reading otherwise, so the BRAM does not toggle while stalled
    assign ram_ren = !m_axi_tvalid || m_axi_tready;

    dpmemrf
    #(
        .DEPTH   (LOG2_DEPTH),
        .WIDTH   (DATA_WIDTH + 1),
        .BYTE_WE (0),
        .OUTREGA (0),
        .OUTREGB (0)
    )
    dpmemrf_inst
    (
        .clka  (clock),
        .ena   (ram_ren),
        .wea   (1'b0),
        .addra (ram_raddr),
        .dia   ({(DATA_WIDTH+1){1'b0}}),
        .doa   (ram_rdata),
        .clkb  (clock),
        .enb   (1'b1),
        .web   (store),
        .addrb (wptr[LOG2_DEPTH-1:0]),
        .dib   ({s_axi_tlast, s_axi_tdata}),
        .dob   ()
    );

    //-------------------------------------------
    // Read side
    //-------------------------------------------
    // The RAM is addressed with the pointer the reader will hold next
    // cycle, so its output is always mem[rptr]: the word falls through
    // when a frame commits and holds under backpressure. The valid
    // register lags the commit by one cycle, which is exactly when the
    // RAM has loaded the committed slot.
    logic [PTR_W-1:0] rptr_next;

    assign consume   = m_axi_tvalid && m_axi_tready;
    assign rptr_next = consume ? rptr + PTR_W'(1) : rptr;
    assign ram_raddr = rptr_next[LOG2_DEPTH-1:0];

    always_ff @(posedge clock) begin
        if (sreset) begin
            rptr         <= '0;
            m_axi_tvalid <= 1'b0;
        end
        else begin
            rptr         <= rptr_next;
            m_axi_tvalid <= (rptr_next != cptr);
        end
    end

    assign {m_axi_tlast, m_axi_tdata} = ram_rdata;

endmodule
