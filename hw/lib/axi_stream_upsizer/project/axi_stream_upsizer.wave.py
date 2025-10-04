# -*- python -*-
# To include in axi_stream_upsizer_tb.wave.py:
"""Wavedisp file for module axi_stream_upsizer."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module axi_stream_upsizer."""
    blk = Block()
    blk.add(Disp("clock"))
    blk.add(Disp("sreset"))

    grp_in = Group("IN")
    blk.add(grp_in)
    grp_in.add(Disp("s_axi_tdata"))
    grp_in.add(Disp("s_axi_tuser"))
    grp_in.add(Disp("s_axi_tvalid"))
    grp_in.add(Disp("s_axi_tlast"))
    grp_in.add(Disp("s_axi_tready"))

    grp_out = Group("OUT")
    blk.add(grp_out)
    grp_out.add(Disp("m_axi_tdata"))
    grp_out.add(Disp("m_axi_tuser"))
    grp_out.add(Disp("m_axi_tvalid"))
    grp_out.add(Disp("m_axi_tlast"))
    grp_out.add(Disp("m_axi_tkeep"))
    grp_out.add(Disp("m_axi_tready"))
    return blk
