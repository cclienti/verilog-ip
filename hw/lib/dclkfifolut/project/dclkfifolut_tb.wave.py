# -*- python -*-

from wavedisp.ast import Hierarchy, Disp, Divider


def generator():
    testbench = Hierarchy('/dclkfifolut_tb')
    inst = testbench.add(Hierarchy('DUT'))
    inst.include('dclkfifolut.wave.py')
    testbench.add(Divider('Reference'))
    testbench.add(Disp('rcheck_data'))

    return testbench
