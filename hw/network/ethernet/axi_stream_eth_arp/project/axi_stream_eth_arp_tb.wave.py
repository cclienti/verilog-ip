# -*- python -*-
"""Wavedisp file for module axi_stream_eth_arp_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module axi_stream_eth_arp_tb."""
    testbench = Hierarchy("axi_stream_eth_arp_tb")

    inst = testbench.add(Hierarchy("axi_stream_eth_arp_inst"))
    inst.include("axi_stream_eth_arp.wave.py", internals=True)

    parser = testbench.add(Hierarchy("axi_stream_eth_parser_inst"))
    parser.add(Disp(["s_axi_tvalid", "s_axi_tlast", "s_axi_tready"]))
    parser.add(Disp(["m_axi_tvalid", "m_axi_tlast", "m_sel", "m_ethertype"]))

    demux = testbench.add(Hierarchy("axi_stream_packet_demux_inst"))
    demux.add(Disp(["m_axi_tvalid", "m_axi_tlast", "m_axi_tready"]))

    return testbench
