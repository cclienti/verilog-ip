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
    testbench.add(Disp('cpt'))
    inst = testbench.add(Hierarchy('rdselb'))
    inst.include('rdselb.wave.py')
    testbench.add(Disp('out_ref'))
    return testbench
