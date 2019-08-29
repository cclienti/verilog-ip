# -*- python -*-

from wavedisp.ast import *


def generator():
    blk = Block()
    blk.add(Disp(['clk', 'srst', 'enable'], radix='binary'))
    blk.add(Disp(['sub_nadd', 'cin'], radix='binary'))
    blk.add(Disp(['a', 'b'], radix='hexadecimal'))
    blk.add(Disp('out', radix='hexadecimal'))
    blk.add(Disp('cout', radix='binary'))
    return blk
