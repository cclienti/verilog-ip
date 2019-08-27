# -*- python -*-

from wavedisp.ast import *


def generator():
    blk = Block()
    blk.add(Disp('bin', radix='hexadecimal'))
    blk.add(Disp('gray', radix='hexadecimal'))
    return blk
