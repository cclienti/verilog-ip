# -*- python -*-
"""Wavedisp file for module rmii_mac_tx."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module rmii_mac_tx."""
    blk = Block()
    blk.add(Disp("clock"))
    blk.add(Disp("srst"))
    blk.add(Disp("axi_tvalid"))
    blk.add(Disp("axi_tlast"))
    blk.add(Disp("axi_tdata"))
    blk.add(Disp("axi_tuser"))
    blk.add(Disp("axi_tready"))
    blk.add(Disp("txd"))
    blk.add(Disp("txen"))

    internal = blk.add(Group("Internal"))
    internal.add(Disp("state"))
    internal.add(Disp("count"))

    return blk
