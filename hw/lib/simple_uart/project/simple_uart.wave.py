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
    blk.add(Disp('tx_value_done'))

    internal = blk.add(Group('Internal'))

    rx_group = internal.add(Group('RX'))
    rx_group = rx_group.add(Hierarchy('simple_uart_rx_inst'))
    rx_group.add(Disp('state_reg'))
    rx_group.add(Disp('baud_counter', radix='unsigned'))
    rx_group.add(Disp('baud_counter_reset'))
    rx_group.add(Disp('baud_counter_half'))
    rx_group.add(Disp('baud_counter_max'))
    rx_group.add(Disp('bits_counter', radix='unsigned'))
    rx_group.add(Disp('bits_counter_incr'))
    rx_group.add(Disp('bits_counter_reset'))
    rx_group.add(Disp('bits_counter_max'))
    rx_group.add(Disp('rx_shift_reg'))
    rx_group.add(Disp('rx_shift'))

    tx_group = internal.add(Group('TX'))
    tx_group = tx_group.add(Hierarchy('simple_uart_tx_inst'))
    tx_group.add(Disp('state_reg'))
    tx_group.add(Disp('baud_counter', radix='unsigned'))
    tx_group.add(Disp('baud_counter_reset'))
    tx_group.add(Disp('baud_counter_max'))
    tx_group.add(Disp('bits_counter', radix='unsigned'))
    tx_group.add(Disp('bits_counter_incr'))
    tx_group.add(Disp('bits_counter_reset'))
    tx_group.add(Disp('bits_counter_max'))
    tx_group.add(Disp('tx_shift_reg'))
    tx_group.add(Disp('tx_shift'))

    return blk
