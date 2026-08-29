# -*- python -*-
"""Wavedisp file for module zedboard_eth_endpoint."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(internals=False):
    """Generator for module zedboard_eth_endpoint."""
    blk = Block()
    blk.add(Disp("phy_refclk"))
    blk.add(Disp("btn_reset"))
    blk.add(Disp("phy_rxd"))
    blk.add(Disp("phy_crs_dv"))
    blk.add(Disp("phy_txd"))
    blk.add(Disp("phy_txen"))
    blk.add(Disp("led"))

    if internals:
        internal = blk.add(Group("Internal"))
        internal.add(Disp(["rst_shift", "sreset"]))
        internal.add(Disp(["learn_valid", "learn_mac", "learn_ip"]))

    return blk
