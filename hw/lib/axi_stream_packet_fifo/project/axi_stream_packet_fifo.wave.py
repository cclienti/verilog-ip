# -*- python -*-
"""Wavedisp file for module axi_stream_packet_fifo."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module axi_stream_packet_fifo."""
    blk = Block()
    blk.add(Disp("clock"))
    blk.add(Disp("sreset"))
    blk.add(Disp("s_axi_tvalid"))
    blk.add(Disp("s_axi_tlast"))
    blk.add(Disp("s_axi_tdata"))
    blk.add(Disp("s_axi_tuser"))
    blk.add(Disp("s_axi_tready"))
    blk.add(Disp("s_info"))
    blk.add(Disp("m_axi_tvalid"))
    blk.add(Disp("m_axi_tlast"))
    blk.add(Disp("m_axi_tdata"))
    blk.add(Disp("m_axi_tready"))
    blk.add(Disp("m_info"))
    blk.add(Disp("m_length"))

    internal = blk.add(Group("Internal"))
    internal.add(Disp("wptr"))
    internal.add(Disp("cptr"))
    internal.add(Disp("rptr"))
    internal.add(Disp("doomed"))
    internal.add(Disp("iwptr"))
    internal.add(Disp("irptr"))

    return blk
