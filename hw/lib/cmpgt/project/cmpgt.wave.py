# -*- python -*-
# To include in cmpgt_tb.wave.py:

from wavedisp.ast import *


def generator():
   blk = Block()
   blk.add(Disp('a'))
   blk.add(Disp('b'))
   blk.add(Disp('is_signed'))
   blk.add(Disp('out'))
   return blk
