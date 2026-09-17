# -*- python -*-
"""Wavedisp file for module axi_stream_udp_socket."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(internals=False):
    """Generator for module axi_stream_udp_socket."""
    blk = Block()
    blk.add(Disp("clock"))
    blk.add(Disp("sreset"))

    net = blk.add(Group("Network"))
    net.add(Disp(["s_axi_tvalid", "s_axi_tlast", "s_axi_tdata", "s_axi_tuser", "s_axi_tready"]))
    net.add(Disp(["s_src_ip", "s_dst_ip", "s_length", "s_src_mac"]))
    net.add(Disp(["m_axi_tvalid", "m_axi_tlast", "m_axi_tdata", "m_axi_tready"]))

    app = blk.add(Group("Application"))
    app.add(Disp(["m_app_tvalid", "m_app_tlast", "m_app_tdata", "m_app_tready"]))
    app.add(Disp(["m_app_peer_mac", "m_app_peer_ip", "m_app_peer_port"]))
    app.add(Disp(["s_app_tvalid", "s_app_tlast", "s_app_tdata", "s_app_tready"]))
    app.add(Disp(["s_app_dst_mac", "s_app_dst_ip", "s_app_dst_port"]))

    if internals:
        rx = blk.add(Group("Receive walker"))
        rx.add(Disp(["rx_state", "rx_cnt", "rx_len_bad_q", "rx_csum_zero_q", "rx_accept_q"]))
        rx.add(Disp(["rx_fold_q", "rx_checksum_ok", "rxf_s_tvalid", "rxf_s_tuser", "rxf_s_tready"]))
        rx.add(Disp(["rxf_level", "rxf_frames", "rx_free", "rx_frame_free"]))
        tx = blk.add(Group("Transmit"))
        tx.add(Disp(["tx_byte_cnt_q", "tx_fold_q", "tx_checksum", "txf_s_tready"]))
        tx.add(Disp(["tx_state", "tx_hcnt", "txf_m_tvalid", "txf_m_tready", "txf_m_length"]))

    return blk
