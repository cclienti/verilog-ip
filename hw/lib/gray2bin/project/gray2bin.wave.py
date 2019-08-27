from wavedisp.ast import *


def generator():
    blk = Block()
    blk.add(Disp('gray', radix='hexadecimal'))
    blk.add(Disp('bin', radix='hexadecimal'))
    return blk
