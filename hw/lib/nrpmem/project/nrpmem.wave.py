"""Wavedisp file for module nrpmem."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module nrpmem."""
    blk = Block()
    blk.add(Disp("clk"))
    blk.add(Disp("enable"))
    blk.add(Disp("wraddr"))
    blk.add(Disp("wren"))
    blk.add(Disp("wrdata"))
    blk.add(Disp("rdaddr"))
    blk.add(Disp("rddata"))
    return blk
