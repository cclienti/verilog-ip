# -*- python -*-
"""Wavedisp file for module axi_stream_eth_fcs_gen_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module axi_stream_eth_fcs_gen_tb."""
    testbench = Hierarchy("axi_stream_eth_fcs_gen_tb")
    inst = testbench.add(Hierarchy("axi_stream_eth_fcs_gen_inst"))
    inst.include("axi_stream_eth_fcs_gen.wave.py")

    # MIN_FRAME_BYTES sweep instances: the stream seams only
    for name in ("p0", "p8"):
        sweep = testbench.add(Group(f"MIN {name[1:]}"))
        sweep.add(Disp([f"{name}_s_tvalid", f"{name}_s_tlast", f"{name}_s_tdata",
                        f"{name}_s_tready"]))
        sweep.add(Disp([f"{name}_m_tvalid", f"{name}_m_tlast", f"{name}_m_tdata",
                        f"{name}_m_tuser", f"{name}_m_tready"]))

    return testbench
