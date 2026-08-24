# -*- python -*-
"""Wavedisp file for module axi_stream_packet_fifo_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module axi_stream_packet_fifo_tb."""
    testbench = Hierarchy("axi_stream_packet_fifo_tb")

    inst = testbench.add(Hierarchy("axi_stream_packet_fifo_mn_inst"))
    inst.include("axi_stream_packet_fifo.wave.py")

    for name in ("dr", "nw"):
        other = testbench.add(Hierarchy(f"axi_stream_packet_fifo_{name}_inst"))
        other.add(Disp(["s_axi_tvalid", "s_axi_tlast", "s_axi_tdata", "s_axi_tuser",
                        "s_axi_tready", "m_axi_tvalid", "m_axi_tlast", "m_axi_tdata",
                        "m_axi_tready", "m_length"]))

    return testbench
