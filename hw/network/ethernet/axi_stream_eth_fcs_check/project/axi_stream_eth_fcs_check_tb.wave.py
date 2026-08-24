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

    # Full RMII chain: only the seams, the modules have their own views
    chain = testbench.add(Group("Chain"))
    chain.add(Disp(["ch_s_tvalid", "ch_s_tlast", "ch_s_tdata", "ch_s_tuser", "ch_s_tready"]))
    chain.add(Disp(["txd", "txen"]))
    chain.add(Disp(["up_m_tvalid", "up_m_tlast", "up_m_tdata", "up_m_tuser", "up_m_tkeep"]))
    chain.add(Disp(["cc_m_tvalid", "cc_m_tlast", "cc_m_tdata", "cc_m_tuser"]))

    return testbench
