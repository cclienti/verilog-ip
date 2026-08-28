# -*- python -*-
"""Wavedisp file for module axi_stream_icmp_echo."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(internals=False):
    """Generator for module axi_stream_icmp_echo."""
    blk = Block()
    blk.add(Disp("clock"))
    blk.add(Disp("sreset"))
    blk.add(Disp("local_mac"))
    blk.add(Disp("local_ip"))
    blk.add(Disp("s_axi_tvalid"))
    blk.add(Disp("s_axi_tlast"))
    blk.add(Disp("s_axi_tdata"))
    blk.add(Disp("s_axi_tuser"))
    blk.add(Disp("s_axi_tready"))
    blk.add(Disp("s_src_ip"))
    blk.add(Disp("s_dst_ip"))
    blk.add(Disp("s_length"))
    blk.add(Disp("s_src_mac"))
    blk.add(Disp("m_axi_tvalid"))
    blk.add(Disp("m_axi_tlast"))
    blk.add(Disp("m_axi_tdata"))
    blk.add(Disp("m_axi_tuser"))
    blk.add(Disp("m_axi_tready"))

    if internals:
        internal = blk.add(Group("Internal"))
        internal.add(Disp("state"))
        internal.add(Disp("rx_cnt"))
        internal.add(Disp("tx_cnt"))
        internal.add(Disp("data_idx"))
        internal.add(Disp("drop_q"))
        internal.add(Disp("frame_ok"))

    return blk
