# -*- python -*-
"""Wavedisp file for module axi_stream_eth_fcs_check."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module axi_stream_eth_fcs_check."""
    blk = Block()
    blk.add(Disp("clock"))
    blk.add(Disp("sreset"))
    blk.add(Disp("s_axi_tvalid"))
    blk.add(Disp("s_axi_tlast"))
    blk.add(Disp("s_axi_tdata"))
    blk.add(Disp("s_axi_tuser"))
    blk.add(Disp("s_axi_tready"))
    blk.add(Disp("m_axi_tvalid"))
    blk.add(Disp("m_axi_tlast"))
    blk.add(Disp("m_axi_tdata"))
    blk.add(Disp("m_axi_tuser"))
    blk.add(Disp("m_axi_tready"))

    internal = blk.add(Group("Internal"))
    internal.add(Disp("fill"))
    internal.add(Disp("crc"))
    internal.add(Disp("fcs_ok"))
    internal.add(Disp("frame_err"))

    return blk
