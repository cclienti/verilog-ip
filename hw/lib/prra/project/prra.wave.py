# -*- python -*-
"""Wavedisp file for module prra."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(nb_ports=4):
   """Generator for module prra."""
   blk = Block()
   blk.add(Disp('clk'))
   blk.add(Disp('srst'))
   blk.add(Disp('request'))
   blk.add(Disp('state'))
   blk.add(Disp('grant'))

   internals = blk.add(Group('Internals'))

   for idx in range(nb_ports):
       group = internals.add(Group(f'prra_lut_inst_{idx}'))
       hier = group.add(Hierarchy(f'lut_gen[{idx}].prra_lut_inst'))
       hier.include('../../prra_lut/project/prra_lut.wave.py')

   return blk
