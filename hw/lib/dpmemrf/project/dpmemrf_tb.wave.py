# -*- python -*-
"""Wavedisp file for dpmemrf_tb module."""

from wavedisp.ast import Hierarchy, Disp


def generator():
    """Generator for dpmemrf_tb module."""
    testbench = Hierarchy('dpmemrf_tb')
    testbench.add(Disp(['clka', 'clkb', 'errors']))
    for instance in ('u_plain', 'u_reg', 'u_be'):
        inst = testbench.add(Hierarchy(instance))
        inst.include('dpmemrf.wave.py')
    return testbench
