# -*- python -*-
"""Wavedisp file for module prra_lut_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module prra_lut_tb."""
    testbench = Hierarchy('prra_lut_tb')
    inst = testbench.add(Hierarchy('prra_lut'))
    inst.include('prra_lut.wave.py')
    return testbench
