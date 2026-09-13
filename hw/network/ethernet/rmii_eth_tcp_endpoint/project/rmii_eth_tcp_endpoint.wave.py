# -*- python -*-
"""Wavedisp file for module rmii_eth_tcp_endpoint."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(internals=False):
    """Generator for module rmii_eth_tcp_endpoint."""
    blk = Block()
    blk.add(Disp("clock"))
    blk.add(Disp("sreset"))

    phy = blk.add(Group("PHY"))
    phy.add(Disp(["phy_rxd", "phy_crs_dv", "phy_txd", "phy_txen"]))

    ident = blk.add(Group("Identity"))
    ident.add(Disp(["local_mac", "local_ip", "listen_port"]))

    tcp = blk.add(Group("TCP status"))
    tcp.add(Disp(["tcp_connected", "tcp_peer_ip", "tcp_peer_port"]))

    if internals:
        sock = blk.add(Hierarchy("axi_stream_tcp_socket_inst"))
        sock.include("../../axi_stream_tcp_socket/project/axi_stream_tcp_socket.wave.py",
                     internals=True)

    return blk
