# -*- python -*-
"""Wavedisp file for module multiplier."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module multiplier."""
    blk = Block()
    blk.add(Disp('clk'))
    blk.add(Disp('enable'))
    blk.add(Disp('is_signed'))
    blk.add(Disp('a'))
    blk.add(Disp('b'))
    blk.add(Disp('out'))
    return blk
