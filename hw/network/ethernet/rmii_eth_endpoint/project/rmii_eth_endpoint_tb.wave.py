# -*- python -*-
"""Wavedisp file for module rmii_eth_endpoint_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module rmii_eth_endpoint_tb."""
    testbench = Hierarchy("rmii_eth_endpoint_tb")

    inst = testbench.add(Hierarchy("rmii_eth_endpoint_inst"))
    inst.include("rmii_eth_endpoint.wave.py", internals=True)

    sweep = testbench.add(Hierarchy("rmii_eth_endpoint_p1_inst"))
    sweep.include("rmii_eth_endpoint.wave.py")

    return testbench
