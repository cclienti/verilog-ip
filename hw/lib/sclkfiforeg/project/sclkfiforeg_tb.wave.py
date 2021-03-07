# -*- python -*-
"""Wavedisp file for module sclkfiforeg_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module sclkfiforeg_tb."""
    testbench = Hierarchy('sclkfiforeg_tb')
    inst = testbench.add(Hierarchy('sclkfiforeg'))
    inst.include('sclkfiforeg.wave.py')
    return testbench
