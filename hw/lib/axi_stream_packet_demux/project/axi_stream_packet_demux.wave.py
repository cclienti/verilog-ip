# -*- python -*-
"""Wavedisp file for module axi_stream_packet_demux."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(internals=False):
    """Generator for module axi_stream_packet_demux."""
    blk = Block()
    blk.add(Disp("clock"))
    blk.add(Disp("sreset"))
    blk.add(Disp("s_axi_tvalid"))
    blk.add(Disp("s_axi_tlast"))
    blk.add(Disp("s_axi_tdata"))
    blk.add(Disp("s_axi_tuser"))
    blk.add(Disp("s_axi_tready"))
    blk.add(Disp("s_sel"))
    blk.add(Disp("s_info"))
    blk.add(Disp("m_axi_tvalid"))
    blk.add(Disp("m_axi_tlast"))
    blk.add(Disp("m_axi_tdata"))
    blk.add(Disp("m_axi_tuser"))
    blk.add(Disp("m_axi_tready"))
    blk.add(Disp("m_info"))

    if internals:
        internal = blk.add(Group("Internal"))
        internal.add(Disp("in_frame"))
        internal.add(Disp("sel_q"))

    return blk
