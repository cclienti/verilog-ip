# -*- python -*-
# To include in quad_encoder.wave.py:
"""Wavedisp file for module quad_encoder."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module quad_encoder."""
    blk = Block()
    blk.add(Disp('clock'))
    blk.add(Disp('srst'))
    blk.add(Disp('sampling'))
    blk.add(Disp('channel_a'))
    blk.add(Disp('channel_b'))
    blk.add(Disp('direction'))
    blk.add(Disp('pulse'))

    internal = blk.add(Group('Internal'))
    internal.add(Disp('sample'))
    internal.add(Disp(['channel_a_regs', 'channel_b_regs']))
    internal.add(Disp(['channel_a_filt', 'channel_b_filt']))
    internal.add(Disp(['channel_a_filt_reg', 'channel_b_filt_reg']))

    return blk
