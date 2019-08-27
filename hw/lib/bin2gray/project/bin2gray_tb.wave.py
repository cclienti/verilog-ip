# -*- python -*-

from wavedisp.ast import *


def generator():
    hier = Hierarchy('/bin2gray_tb')
    inst = hier.add(Hierarchy('bin2gray_inst'))
    inst.include('bin2gray.wave.py')
    return hier
