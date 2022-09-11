# -*- python -*-
"""Wavedisp file for module prra_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
   """Generator for module prra_tb."""
   testbench = Hierarchy('prra_tb')
   inst = testbench.add(Hierarchy('prra'))
   inst.include('prra.wave.py')
   testbench.add(Divider('Reference'))
   testbench.add(Disp('grant_check'))
   return testbench
