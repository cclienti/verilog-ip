# -*- python -*-
# To include in asdpmem_tb.wave.py:

from wavedisp.ast import *


def generator():
   blk = Block()
   blk.add(Disp('clka'))
   blk.add(Disp('ena'))
   blk.add(Disp('wea'))
   blk.add(Disp('addra'))
   blk.add(Disp('dia'))
   blk.add(Disp('addrb'))
   blk.add(Disp('dob'))
   return blk
