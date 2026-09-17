# -*- python -*-
"""Wavedisp file for module axi_stream_udp_socket_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module axi_stream_udp_socket_tb."""
    testbench = Hierarchy("axi_stream_udp_socket_tb")
    testbench.add(Disp(["errors", "checks", "fcount", "hold_app"]))

    inst = testbench.add(Hierarchy("dut"))
    inst.include("axi_stream_udp_socket.wave.py", internals=True)

    return testbench
