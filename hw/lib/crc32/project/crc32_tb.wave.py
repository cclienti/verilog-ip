# -*- python -*-
"""Wavedisp file for module crc32_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module crc32_tb."""
    testbench = Hierarchy("crc32_tb")
    for g in range(4):
        inst = testbench.add(Hierarchy(f"gen_width[{g}].crc32_inst"))
        inst.include("crc32.wave.py")
    inst = testbench.add(Hierarchy("crc32c_inst"))
    inst.include("crc32.wave.py")
    return testbench
