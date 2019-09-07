# -*- python -*-
"""Wavedisp file for module multiplier_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module multiplier_tb."""
    testbench = Hierarchy('multiplier_tb')
    inst = testbench.add(Hierarchy('multiplier'))
    inst.include('multiplier.wave.py')
    testbench.add(Disp('out_ref'))
    return testbench
