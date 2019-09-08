# -*- python -*-
"""Wavedisp file for module rdselh_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module rdselh_tb."""
    testbench = Hierarchy('rdselh_tb')
    testbench.add(Disp('cpt'))
    inst = testbench.add(Hierarchy('rdselh'))
    inst.include('rdselh.wave.py')
    testbench.add(Disp('out_ref'))
    return testbench
