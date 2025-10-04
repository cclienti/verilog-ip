# -*- python -*-
# To include in axi_stream_upsizer_tb.wave.py:
"""Wavedisp file for module axi_stream_upsizer_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module axi_stream_upsizer_tb."""
    testbench = Hierarchy("axi_stream_upsizer_tb")
    inst = testbench.add(Hierarchy("axi_stream_upsizer_inst"))
    inst.include("axi_stream_upsizer.wave.py")
    return testbench
