# -*- python -*-
"""Wavedisp file for dpmemrf_tb module."""

from wavedisp.ast import Hierarchy, Disp


def generator():
    """Generator for dpmemrf_tb module."""
    testbench = Hierarchy('dpmemrf_tb')
    testbench.add(Disp(['cpta', 'cptb']))
    inst = testbench.add(Hierarchy('dpmemrf'))
    inst.include('dpmemrf.wave.py')
    return testbench
