# -*- python -*-
"""Wavedisp file for module rmii_eth_endpoint."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(internals=False):
    """Generator for module rmii_eth_endpoint."""
    blk = Block()
    blk.add(Disp("clock"))
    blk.add(Disp("sreset"))
    blk.add(Disp("local_mac"))
    blk.add(Disp("local_ip"))
    blk.add(Disp("phy_rxd"))
    blk.add(Disp("phy_crs_dv"))
    blk.add(Disp("phy_txd"))
    blk.add(Disp("phy_txen"))
    blk.add(Disp("learn_valid"))
    blk.add(Disp("learn_mac"))
    blk.add(Disp("learn_ip"))

    if internals:
        seams = blk.add(Group("Seams"))
        seams.add(Disp(["pf_tvalid", "pf_tlast", "pf_tdata", "pf_tready", "pf_length"]))
        seams.add(Disp(["ethp_sel", "ethp_src_mac"]))
        seams.add(Disp(["ethd_tvalid", "ethd_tlast", "ethd_tready"]))
        seams.add(Disp(["ipp_sel", "ipp_src_ip", "ipp_dst_ip", "ipp_length"]))
        seams.add(Disp(["arp_tvalid", "arp_tlast", "arp_tready"]))
        seams.add(Disp(["icmp_tvalid", "icmp_tlast", "icmp_tready"]))
        seams.add(Disp(["mux_tvalid", "mux_tlast", "mux_tdata", "mux_tready"]))
        seams.add(Disp(["gen_tvalid", "gen_tlast", "gen_tready"]))

    return blk
