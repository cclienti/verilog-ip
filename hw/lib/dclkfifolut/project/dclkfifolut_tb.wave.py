# -*- python -*-

from wavedisp.ast import *


def generator():
    hier = Hierarchy('/dclkfifolut_tb')
    inst = hier.add(Hierarchy('DUT'))
    inst.include('dclkfifolut.wave.py')

    return hier
