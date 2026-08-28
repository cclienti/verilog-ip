# -*- python -*-
"""Wavedisp file for module axi_stream_eth_parser."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(internals=False):
    """Generator for module axi_stream_eth_parser."""
    blk = Block()
    blk.add(Disp("clock"))
    blk.add(Disp("sreset"))
    blk.add(Disp("local_mac"))
    blk.add(Disp("promiscuous"))
    blk.add(Disp("s_axi_tvalid"))
    blk.add(Disp("s_axi_tlast"))
    blk.add(Disp("s_axi_tdata"))
    blk.add(Disp("s_axi_tuser"))
    blk.add(Disp("s_axi_tready"))
    blk.add(Disp("s_length"))
    blk.add(Disp("m_axi_tvalid"))
    blk.add(Disp("m_axi_tlast"))
    blk.add(Disp("m_axi_tdata"))
    blk.add(Disp("m_axi_tuser"))
    blk.add(Disp("m_axi_tready"))
    blk.add(Disp("m_sel"))
    blk.add(Disp("m_dst_mac"))
    blk.add(Disp("m_src_mac"))
    blk.add(Disp("m_ethertype"))
    blk.add(Disp("m_length"))

    if internals:
        internal = blk.add(Group("Internal"))
        internal.add(Disp("in_payload"))
        internal.add(Disp("hdr_cnt"))
        internal.add(Disp("hdr_last"))

    return blk
