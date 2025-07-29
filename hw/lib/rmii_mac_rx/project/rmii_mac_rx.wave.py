# -*- python -*-
"""Wavedisp file for module rmii_mac_rx."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module rmii_mac_rx."""
    blk = Block()
    blk.add(Disp("clock"))
    blk.add(Disp("srst"))
    blk.add(Disp("rxd"))
    blk.add(Disp("rxen"))
    blk.add(Disp("axi_tvalid"))
    blk.add(Disp("axi_tlast"))
    blk.add(Disp("axi_tdata"))
    blk.add(Disp("axi_tuser"))
    blk.add(Disp("axi_tready"))

    internal = blk.add(Group("Internal"))
    internal.add(Disp("sfd_detected"))
    internal.add(Disp("rxen_rising"))
    internal.add(Disp("rxen_falling"))
    internal.add(Disp("state"))

    return blk
