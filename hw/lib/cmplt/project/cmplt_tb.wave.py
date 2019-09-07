# -*- python -*-
# To include in cmplt_tb.wave.py:

from wavedisp.ast import *


def generator():
    testbench = Hierarchy('cmplt_tb')
    inst = testbench.add(Hierarchy('cmplt'))
    inst.include('cmplt.wave.py')
    testbench.add(Disp('out_ref'))
    return testbench
