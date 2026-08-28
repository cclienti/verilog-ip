# -*- python -*-
"""Wavedisp file for module axi_stream_eth_parser_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module axi_stream_eth_parser_tb."""
    testbench = Hierarchy("axi_stream_eth_parser_tb")

    inst = testbench.add(Hierarchy("axi_stream_eth_parser_inst"))
    inst.include("axi_stream_eth_parser.wave.py", internals=True)

    demux = testbench.add(Hierarchy("axi_stream_packet_demux_inst"))
    demux.add(Disp(["s_axi_tvalid", "s_axi_tlast", "s_axi_tready", "s_sel"]))
    demux.add(Disp(["m_axi_tvalid", "m_axi_tlast", "m_axi_tdata", "m_axi_tready", "m_info"]))

    sweep = testbench.add(Group("Sweep p1"))
    sweep.add(Disp(["p1_s_tvalid", "p1_s_tlast", "p1_s_tdata", "p1_s_tready"]))
    sweep.add(Disp(["p1_m_tvalid", "p1_m_tlast", "p1_m_tdata", "p1_m_tready"]))
    sweep.add(Disp(["p1_sel", "p1_length"]))

    return testbench
