# -*- python -*-
"""Wavedisp file for module axi_stream_eth_fcs_gen_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module axi_stream_eth_fcs_gen_tb."""
    testbench = Hierarchy("axi_stream_eth_fcs_gen_tb")
    inst = testbench.add(Hierarchy("axi_stream_eth_fcs_gen_inst"))
    inst.include("axi_stream_eth_fcs_gen.wave.py")
    return testbench
