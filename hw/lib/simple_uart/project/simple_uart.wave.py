# -*- python -*-
"""Wavedisp file for module simple_uart."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module simple_uart."""
    blk = Block()
    blk.add(Disp('clock'))
    blk.add(Disp('srst'))
    blk.add(Disp('rx_bit'))
    blk.add(Disp('tx_bit'))
    blk.add(Disp('rx_value'))
    blk.add(Disp('rx_value_ready'))
    blk.add(Disp('tx_value'))
    blk.add(Disp('tx_value_write'))
    return blk
