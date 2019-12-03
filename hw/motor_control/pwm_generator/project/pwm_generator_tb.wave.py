# -*- python -*-
"""Wavedisp file for module pwm_generator_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module pwm_generator_tb."""
    testbench = Hierarchy('pwm_generator_tb')
    inst = testbench.add(Hierarchy('pwm_generator_inst'))
    inst.include('pwm_generator.wave.py')
    return testbench
