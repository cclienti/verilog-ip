# -*- python -*-
"""Wavedisp file for module parmem11_8_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module parmem11_8_tb.

    Pass internals=True / banks=True on the include below to dig in.
    """
    testbench = Hierarchy('parmem11_8_tb')

    testbench.add(Divider('stimulus'))
    testbench.add(Disp(['clka', 'clkb', 'errors']))
    testbench.add(Disp(['en', 'wen', 'lane_en', 'addr', 'stride']))
    testbench.add(Disp(['dia', 'doa', 'conflict', 'oob']))

    grp = testbench.add(Group('dut'))
    inst = grp.add(Hierarchy('parmem11_8_inst'))
    inst.include('parmem11_8.wave.py', internals=True)

    return testbench
