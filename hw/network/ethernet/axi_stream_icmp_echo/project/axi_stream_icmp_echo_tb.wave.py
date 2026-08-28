# -*- python -*-
"""Wavedisp file for module axi_stream_icmp_echo_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module axi_stream_icmp_echo_tb."""
    testbench = Hierarchy("axi_stream_icmp_echo_tb")

    inst = testbench.add(Hierarchy("axi_stream_icmp_echo_inst"))
    inst.include("axi_stream_icmp_echo.wave.py", internals=True)

    parser = testbench.add(Hierarchy("axi_stream_ipv4_parser_inst"))
    parser.add(Disp(["s_axi_tvalid", "s_axi_tlast", "s_axi_tready"]))
    parser.add(Disp(["m_axi_tvalid", "m_axi_tlast", "m_sel", "m_length"]))

    sweep = testbench.add(Group("Sweep p1"))
    sweep.add(Disp(["p1_s_tvalid", "p1_s_tlast", "p1_s_tdata", "p1_s_tready", "p1_s_length"]))
    sweep.add(Disp(["p1_m_tvalid", "p1_m_tlast", "p1_m_tdata", "p1_m_tready"]))

    return testbench
