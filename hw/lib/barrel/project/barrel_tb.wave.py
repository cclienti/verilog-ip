# -*- python -*-
# To include in barrel_tb.wave.py:

from wavedisp.ast import *


def generator():
    testbench = Hierarchy('barrel_tb')
    inst = testbench.add(Hierarchy('barrel'))
    inst.include('barrel.wave.py')
    return testbench
