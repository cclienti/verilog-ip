# -*- python -*-
"""Wavedisp file for module axi_stream_tcp_socket."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(internals=False):
    """Generator for module axi_stream_tcp_socket."""
    blk = Block()
    blk.add(Disp("clock"))
    blk.add(Disp("sreset"))

    net = blk.add(Group("Network"))
    net.add(Disp(["s_axi_tvalid", "s_axi_tlast", "s_axi_tdata", "s_axi_tready"]))
    net.add(Disp(["m_axi_tvalid", "m_axi_tlast", "m_axi_tdata", "m_axi_tready"]))

    app = blk.add(Group("Application"))
    app.add(Disp(["m_app_tvalid", "m_app_tlast", "m_app_tdata", "m_app_tuser", "m_app_tready"]))
    app.add(Disp(["s_app_tvalid", "s_app_tlast", "s_app_tdata", "s_app_tuser", "s_app_tready"]))
    app.add(Disp(["connected", "peer_ip", "peer_port"]))

    if internals:
        rec = blk.add(Group("Record"))
        rec.add(Disp(["rcv_nxt", "snd_una", "snd_nxt", "wr_seq", "data_base", "snd_wnd", "eff_mss"]))
        sch = blk.add(Group("Scheduler"))
        sch.add(Disp(["sched_kind", "kind_q", "ctrl_sent", "tx_inflight", "tx_start", "tx_busy"]))
        ev = blk.add(Group("Events"))
        ev.add(Disp(["ev_syn_rx", "ev_ctl_acked", "ev_fin_rx", "ev_rst_rx", "ev_give_up", "ack_owed"]))
        fsm = blk.add(Hierarchy("fsm"))
        fsm.add(Disp("state"))

    return blk
