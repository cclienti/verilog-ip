# -*- python -*-
"""Wavedisp file for module tcp_rx_parser."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(internals=False):
    """Generator for module tcp_rx_parser."""
    blk = Block()
    blk.add(Disp("clock"))
    blk.add(Disp("sreset"))

    sin = blk.add(Group("Segment in"))
    sin.add(Disp("s_axi_tvalid"))
    sin.add(Disp("s_axi_tlast"))
    sin.add(Disp("s_axi_tdata"))
    sin.add(Disp("s_axi_tuser"))
    sin.add(Disp("s_axi_tready"))
    sin.add(Disp("s_src_ip"))
    sin.add(Disp("s_dst_ip"))
    sin.add(Disp("s_length"))

    pl = blk.add(Group("Payload out"))
    pl.add(Disp("m_pl_tvalid"))
    pl.add(Disp("m_pl_tlast"))
    pl.add(Disp("m_pl_tdata"))
    pl.add(Disp("m_pl_tuser"))
    pl.add(Disp("m_pl_tready"))

    dec = blk.add(Group("Decoded"))
    dec.add(Disp("seq_num"))
    dec.add(Disp("ack_num"))
    dec.add(Disp("flags"))
    dec.add(Disp("window"))
    dec.add(Disp("mss"))
    dec.add(Disp("payload_len"))
    dec.add(Disp("hdr_valid"))
    dec.add(Disp("seg_done"))
    dec.add(Disp("seg_ok"))

    if internals:
        internal = blk.add(Group("Internal"))
        internal.add(Disp("state"))
        internal.add(Disp("cnt"))
        internal.add(Disp("hl_q"))
        internal.add(Disp("sum_q"))
        internal.add(Disp("opt_state"))

    return blk
