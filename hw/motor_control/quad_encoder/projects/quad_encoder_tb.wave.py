# -*- python -*-
"""Wavedisp file for module quad_encoder_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module quad_encoder_tb."""
    testbench = Hierarchy('quad_encoder_tb')
    inst = testbench.add(Hierarchy('quad_encoder_inst'))
    inst.include('quad_encoder.wave.py')

    testbench.add(Disp('count'))
    testbench.add(Disp('count_ref'))

    return testbench
