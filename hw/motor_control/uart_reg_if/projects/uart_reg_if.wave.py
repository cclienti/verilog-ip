# -*- python -*-
# To include in uart_reg_if_tb.wave.py:
"""Wavedisp file for module uart_reg_if."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module uart_reg_if."""
    blk = Block()
    blk.add(Disp('clock'))
    blk.add(Disp('srst'))
    blk.add(Disp('uart_rx_value'))
    blk.add(Disp('uart_rx_value_ready'))
    blk.add(Disp('uart_tx_value'))
    blk.add(Disp('uart_tx_value_write'))
    blk.add(Disp('uart_tx_value_done'))
    blk.add(Disp('value_in'))
    blk.add(Disp('value_out'))

    internal = blk.add(Group('Internal'))
    internal.add(Disp('state_reg', radix='unsigned'))
    internal.add(Disp('reg_array_idx', radix='unsigned'))
    internal.add(Disp('reg_array_sel', radix='unsigned'))
    internal.add(Disp('byte_counter', radix='unsigned'))
    internal.add(Disp('byte_counter_roll'))
    internal.add(Disp('reg_array_write'))

    return blk
