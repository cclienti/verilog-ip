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
    blk.add(Disp("clk100"))
    blk.add(Disp("btn_reset"))
    blk.add(Disp("phy_clkin"))
    blk.add(Disp("phy_rstn"))
    blk.add(Disp("phy_rxd"))
    blk.add(Disp("phy_crs_dv"))
    blk.add(Disp("phy_txd"))
    blk.add(Disp("phy_txen"))
    blk.add(Disp("led"))

    if internals:
        internal = blk.add(Group("Internal"))
        internal.add(Disp(["clk_div", "refclk"]))
        internal.add(Disp(["btn_shift", "rst_cnt", "phy_rstn_q", "sreset"]))
        internal.add(Disp(["rxd_q", "crs_dv_q", "txd_q", "txen_q"]))
        internal.add(Disp(["ep_txd", "ep_txen"]))
        internal.add(Disp(["learn_valid", "learn_mac", "learn_ip"]))

    return blk
