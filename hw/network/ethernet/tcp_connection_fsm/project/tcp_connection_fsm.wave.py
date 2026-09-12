# -*- python -*-
"""Wavedisp file for module tcp_connection_fsm."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(internals=False):
    """Generator for module tcp_connection_fsm."""
    blk = Block()
    blk.add(Disp("clock"))
    blk.add(Disp("sreset"))

    levels = blk.add(Group("Levels in"))
    levels.add(Disp("listen"))
    levels.add(Disp("clear_done"))
    levels.add(Disp("close_ready"))

    events = blk.add(Group("Events"))
    events.add(Disp("syn_rx"))
    events.add(Disp("ctl_acked"))
    events.add(Disp("fin_rx"))
    events.add(Disp("rst_rx"))
    events.add(Disp("give_up"))

    outputs = blk.add(Group("Levels out"))
    outputs.add(Disp("clear"))
    outputs.add(Disp("listening"))
    outputs.add(Disp("syn_ack_pending"))
    outputs.add(Disp("connected"))
    outputs.add(Disp("rx_open"))
    outputs.add(Disp("tx_open"))
    outputs.add(Disp("fin_pending"))

    if internals:
        internal = blk.add(Group("Internal"))
        internal.add(Disp("state"))
        internal.add(Disp("next_state"))

    return blk
