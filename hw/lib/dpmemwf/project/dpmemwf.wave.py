# -*- python -*-
"""Wavedisp file for module dpmemwf."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module dpmemwf."""
    blk = Block()
    blk.add(Disp('clka'))
    blk.add(Disp('ena'))
    blk.add(Disp('wea'))
    blk.add(Disp('addra'))
    blk.add(Disp('dia'))
    blk.add(Disp('doa'))
    blk.add(Disp('clkb'))
    blk.add(Disp('enb'))
    blk.add(Disp('web'))
    blk.add(Disp('addrb'))
    blk.add(Disp('dib'))
    blk.add(Disp('dob'))
    return blk
