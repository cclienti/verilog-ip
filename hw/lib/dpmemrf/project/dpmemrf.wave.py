# -*- python -*-
"""Wavedisp file for dpmemrf module."""

from wavedisp.ast import Block
from wavedisp.ast import Disp


def generator():
    """Generator for dpmemrf module."""
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
