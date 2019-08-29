# -*- python -*-

from wavedisp.ast import *


def generator():
    hier = Hierarchy('/adderc_tb')
    inst = hier.add(Hierarchy('DUT'))
    inst.include('adderc.wave.py')
    hier.add(Disp('out_ref', radix='hexadecimal'))
    hier.add(Disp('cout_ref', radix='binary'))
    return hier
