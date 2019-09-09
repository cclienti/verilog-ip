# -*- python -*-
"""Wavedisp file for module sclkfifolut_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module sclkfifolut_tb."""
    testbench = Hierarchy('sclkfifolut_tb')
    inst = testbench.add(Hierarchy('sclkfifolut'))
    inst.include('sclkfifolut.wave.py')
    return testbench
