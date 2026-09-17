# -*- python -*-
"""Wavedisp file for module rmii_eth_udp_endpoint."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(internals=False):
    """Generator for module rmii_eth_udp_endpoint."""
    blk = Block()
    blk.add(Disp("clock"))
    blk.add(Disp("sreset"))

    phy = blk.add(Group("PHY"))
    phy.add(Disp(["phy_rxd", "phy_crs_dv", "phy_txd", "phy_txen"]))

    ident = blk.add(Group("Identity"))
    ident.add(Disp(["local_mac", "local_ip", "listen_port"]))

    app = blk.add(Group("Application"))
    app.add(Disp(["m_app_tvalid", "m_app_tlast", "m_app_tdata", "m_app_tready"]))
    app.add(Disp(["m_app_peer_mac", "m_app_peer_ip", "m_app_peer_port"]))
    app.add(Disp(["s_app_tvalid", "s_app_tlast", "s_app_tdata", "s_app_tready"]))
    app.add(Disp(["s_app_dst_mac", "s_app_dst_ip", "s_app_dst_port"]))

    if internals:
        sock = blk.add(Hierarchy("axi_stream_udp_socket_inst"))
        sock.include("../../axi_stream_udp_socket/project/axi_stream_udp_socket.wave.py",
                     internals=True)

    return blk
