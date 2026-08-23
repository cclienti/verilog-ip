# -*- python -*-
"""Wavedisp file for module rmii_mac_rx_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module rmii_mac_rx_tb."""
    testbench = Hierarchy("rmii_mac_rx_tb")
    inst = testbench.add(Hierarchy("rmii_mac_rx_inst"))
    inst.include("rmii_mac_rx.wave.py")
    return testbench
