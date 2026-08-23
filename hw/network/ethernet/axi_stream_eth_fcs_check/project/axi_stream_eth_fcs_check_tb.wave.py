# -*- python -*-
"""Wavedisp file for module axi_stream_eth_fcs_check_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module axi_stream_eth_fcs_check_tb."""
    testbench = Hierarchy("axi_stream_eth_fcs_check_tb")

    inst = testbench.add(Hierarchy("axi_stream_eth_fcs_check_inst"))
    inst.include("axi_stream_eth_fcs_check.wave.py")

    loopback = testbench.add(Hierarchy("axi_stream_eth_fcs_check_lp_inst"))
    loopback.add(Disp(["s_axi_tvalid", "s_axi_tlast", "s_axi_tdata", "s_axi_tuser",
                       "m_axi_tvalid", "m_axi_tlast", "m_axi_tdata", "m_axi_tuser"]))

    return testbench
