# -*- python -*-
"""Wavedisp file for module crc32."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module crc32."""
    blk = Block()
    blk.add(Disp("crc_in"))
    blk.add(Disp("data"))
    blk.add(Disp("crc_out"))
    return blk
