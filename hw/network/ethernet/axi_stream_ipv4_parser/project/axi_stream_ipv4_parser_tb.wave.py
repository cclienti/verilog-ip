# -*- python -*-
"""Wavedisp file for module axi_stream_ipv4_parser_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module axi_stream_ipv4_parser_tb."""
    testbench = Hierarchy("axi_stream_ipv4_parser_tb")

    inst = testbench.add(Hierarchy("axi_stream_ipv4_parser_inst"))
    inst.include("axi_stream_ipv4_parser.wave.py", internals=True)

    demux = testbench.add(Hierarchy("axi_stream_packet_demux_inst"))
    demux.add(Disp(["m_axi_tvalid", "m_axi_tlast", "m_axi_tready", "m_info"]))

    sweep = testbench.add(Group("Sweep p2"))
    sweep.add(Disp(["p2_s_tvalid", "p2_s_tlast", "p2_s_tdata", "p2_s_tready"]))
    sweep.add(Disp(["p2_m_tvalid", "p2_m_tlast", "p2_m_tdata", "p2_m_tready"]))
    sweep.add(Disp(["p2_sel", "p2_proto", "p2_length"]))

    return testbench
