# -*- python -*-
# To include in nrpmem_tb.wave.py:

from wavedisp.ast import *


def generator():
    blk = Block()
    blk.add(Disp('clk',    radix='binary'))
    blk.add(Disp('enable', radix='binary'))
    blk.add(Divider('Write port'))
    blk.add(Disp('wren',   radix='binary'))
    blk.add(Disp('wraddr', radix='hexadecimal'))
    blk.add(Disp('wrdata', radix='hexadecimal'))
    blk.add(Divider('Read ports'))
    blk.add(Disp('rdaddr', radix='hexadecimal'))
    blk.add(Disp('rddata', radix='hexadecimal'))
    return blk
