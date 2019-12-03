# -*- python -*-
"""Wavedisp file for module pwm_generator."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module pwm_generator."""
    blk = Block()
    blk.add(Disp('clock'))
    blk.add(Disp('srst'))
    blk.add(Disp('pwm_ratio'))
    blk.add(Disp('pwm_max'))
    blk.add(Disp('pwm_output'))

    internal = blk.add(Group('Internal'))
    internal.add(Disp('ratio_counter'))
    return blk
