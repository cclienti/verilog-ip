# -*- python -*-
"""Wavedisp file for module rdselb_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module rdselb_tb."""
    testbench = Hierarchy('rdselb_tb')
    inst = testbench.add(Hierarchy('rdselb'))
    inst.include('rdselb.wave.py')
    return testbench
