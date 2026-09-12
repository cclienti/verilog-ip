# -*- python -*-
"""Wavedisp file for module tcp_tx_frame_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module tcp_tx_frame_tb."""
    testbench = Hierarchy("tcp_tx_frame_tb")
    testbench.add(Disp(["errors", "checks", "cap_en", "capn", "cap_done"]))

    inst = testbench.add(Hierarchy("tcp_tx_frame_inst"))
    inst.include("tcp_tx_frame.wave.py", internals=True)

    return testbench
