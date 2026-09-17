# -*- python -*-
"""Wavedisp file for module rmii_eth_udp_endpoint_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module rmii_eth_udp_endpoint_tb."""
    testbench = Hierarchy("rmii_eth_udp_endpoint_tb")
    testbench.add(Disp(["errors", "checks", "cfcount", "rxen", "txen"]))

    inst = testbench.add(Hierarchy("dut"))
    inst.include("rmii_eth_udp_endpoint.wave.py", internals=True)

    return testbench
