# -*- python -*-
"""Wavedisp file for module dpmemwf_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module dpmemwf_tb."""
    testbench = Hierarchy('dpmemwf_tb')
    testbench.add(Disp(['cpta', 'cptb']))
    inst = testbench.add(Hierarchy('dpmemwf'))
    inst.include('dpmemwf.wave.py')
    return testbench
