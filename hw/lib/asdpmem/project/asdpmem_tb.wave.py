# -*- python -*-

from wavedisp.ast import *


def generator():
    testbench = Hierarchy('asdpmem_tb')
    inst = testbench.add(Hierarchy('asdpmem'))
    inst.include('asdpmem.wave.py')
    return testbench
