# -*- python -*-
"""Wavedisp file for module zedboard_udp_endpoint_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module zedboard_udp_endpoint_tb."""
    testbench = Hierarchy("zedboard_udp_endpoint_tb")

    inst = testbench.add(Hierarchy("zedboard_eth_endpoint_inst"))
    inst.include("zedboard_udp_endpoint.wave.py", internals=True)

    return testbench
