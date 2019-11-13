# -*- python -*-
# To include in uart_reg_if_tb.wave.py:
"""Wavedisp file for module uart_reg_if_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module uart_reg_if_tb."""
    testbench = Hierarchy('uart_reg_if_tb')
    inst = testbench.add(Hierarchy('uart_reg_if_inst'))
    inst.include('uart_reg_if.wave.py')
    return testbench
