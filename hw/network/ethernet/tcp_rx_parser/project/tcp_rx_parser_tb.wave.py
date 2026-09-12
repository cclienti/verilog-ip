# -*- python -*-
"""Wavedisp file for module tcp_rx_parser_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module tcp_rx_parser_tb."""
    testbench = Hierarchy("tcp_rx_parser_tb")
    testbench.add(Disp(["errors", "checks", "cap_en", "pln", "done_seen", "ok_seen", "pl_doom"]))

    inst = testbench.add(Hierarchy("tcp_rx_parser_inst"))
    inst.include("tcp_rx_parser.wave.py", internals=True)

    return testbench
