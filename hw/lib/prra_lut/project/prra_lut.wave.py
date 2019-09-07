# -*- python -*-
"""Wavedisp file for module prra_lut."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module prra_lut."""
    blk = Block()
    blk.add(Disp('request'))
    blk.add(Disp('state'))
    return blk
