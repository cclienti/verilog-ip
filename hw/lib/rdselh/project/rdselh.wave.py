# -*- python -*-
"""Wavedisp file for module rdselh."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module rdselh."""
    blk = Block()
    blk.add(Disp('is_signed'))
    blk.add(Disp('sel'))
    blk.add(Disp('in'))
    blk.add(Disp('out'))
    return blk
