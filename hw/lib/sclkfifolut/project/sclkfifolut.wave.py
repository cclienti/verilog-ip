# -*- python -*-
"""Wavedisp file for module sclkfifolut."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module sclkfifolut."""
    blk = Block()
    blk.add(Disp('clk'))
    blk.add(Disp('srst'))
    blk.add(Disp('level'))
    blk.add(Disp('ren'))
    blk.add(Disp('rdata'))
    blk.add(Disp('rempty'))
    blk.add(Disp('wen'))
    blk.add(Disp('wdata'))
    blk.add(Disp('wfull'))
    return blk
