# -*- python -*-
"""Wavedisp file for module simple_uart_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module simple_uart_tb."""
    testbench = Hierarchy('simple_uart_tb')

    inst = testbench.add(Group('DUT')).add(Hierarchy('simple_uart_inst'))
    inst.include('simple_uart.wave.py')

    internal = testbench.add(Group("Test internals"))
    internal.add(Disp('send_baud_clock'))
    internal.add(Disp('send_state'))
    internal.add(Disp('receive_sampling'))
    internal.add(Disp('receive_state'))

    return testbench
