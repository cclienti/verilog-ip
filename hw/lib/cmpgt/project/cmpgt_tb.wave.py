# -*- python -*-
# To include in cmpgt_tb.wave.py:

from wavedisp.ast import *


def generator():
    testbench = Hierarchy('cmpgt_tb')
    inst = testbench.add(Hierarchy('cmpgt'))
    inst.include('cmpgt.wave.py')
    testbench.add(Disp('out_ref'))
    return testbench
