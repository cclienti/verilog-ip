# -*- python -*-
# To include in barrel_tb.wave.py:

from wavedisp.ast import *


def generator():
   blk = Block()
   blk.add(Disp('clk'))
   blk.add(Disp('enable'))
   blk.add(Disp('is_signed'))
   blk.add(Disp('shift'))
   blk.add(Disp('in'))
   blk.add(Disp('ex'))
   blk.add(Disp('out'))
   return blk
