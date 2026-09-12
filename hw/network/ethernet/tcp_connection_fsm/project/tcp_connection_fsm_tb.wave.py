# -*- python -*-
"""Wavedisp file for module tcp_connection_fsm_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module tcp_connection_fsm_tb."""
    testbench = Hierarchy("tcp_connection_fsm_tb")
    testbench.add(Disp(["in_vec", "out_vec", "errors", "checks"]))

    inst = testbench.add(Hierarchy("tcp_connection_fsm_inst"))
    inst.include("tcp_connection_fsm.wave.py", internals=True)

    return testbench
