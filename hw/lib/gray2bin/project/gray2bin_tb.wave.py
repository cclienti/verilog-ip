# -*- python -*-

from wavedisp.ast import *


def generator():
    hier = Hierarchy('/gray2bin_tb')
    inst = hier.add(Hierarchy('gray2bin_inst'))
    inst.include('gray2bin.wave.py')
    return hier
