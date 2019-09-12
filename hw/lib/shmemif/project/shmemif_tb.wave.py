# -*- python -*-
"""Wavedisp file for module shmemif_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(nb_ports=4):
    """Generator for module shmemif_tb."""
    testbench = Hierarchy('shmemif_tb')
    inst = testbench.add(Hierarchy('DUT'))
    inst.include('shmemif.wave.py', nb_ports=nb_ports)
    return testbench
