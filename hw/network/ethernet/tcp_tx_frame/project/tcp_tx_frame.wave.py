# -*- python -*-
"""Wavedisp file for module tcp_tx_frame."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(internals=False):
    """Generator for module tcp_tx_frame."""
    blk = Block()
    blk.add(Disp("clock"))
    blk.add(Disp("sreset"))

    req = blk.add(Group("Request"))
    req.add(Disp("start"))
    req.add(Disp("with_mss"))
    req.add(Disp("pl_len"))
    req.add(Disp("seq"))
    req.add(Disp("ack"))
    req.add(Disp("flags"))
    req.add(Disp("window"))
    req.add(Disp("mss"))

    payload = blk.add(Group("Payload read"))
    payload.add(Disp("pl_addr"))
    payload.add(Disp("pl_data"))

    out = blk.add(Group("AXI master"))
    out.add(Disp("m_axi_tvalid"))
    out.add(Disp("m_axi_tlast"))
    out.add(Disp("m_axi_tdata"))
    out.add(Disp("m_axi_tready"))
    out.add(Disp("busy"))

    if internals:
        internal = blk.add(Group("Internal"))
        internal.add(Disp("state"))
        internal.add(Disp("cnt"))
        internal.add(Disp("data_sum_q"))
        internal.add(Disp("tcp_hl"))

    return blk
