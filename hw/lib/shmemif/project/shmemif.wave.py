# -*- python -*-
"""Wavedisp file for module shmemif."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(nb_ports=4):
    """Generator for module shmemif."""
    blk = Block()
    blk.add(Disp('clk'))
    blk.add(Disp('srst'))
    blk.add(Disp('shmem_request'))
    blk.add(Disp('shmem_wren'))
    blk.add(Disp('shmem_addr'))
    blk.add(Disp('shmem_datain'))
    blk.add(Disp('shmem_dataout'))
    blk.add(Disp('shmem_done'))
    blk.add(Disp('mem_wren'))
    blk.add(Disp('mem_addr'))
    blk.add(Disp('mem_datain'))
    blk.add(Disp('mem_dataout'))

    blk.add(Divider('internals'))

    for idx in range(nb_ports):
        group = blk.add(Group(f'prra_lut_inst_{idx}'))
        hier = group.add(Hierarchy(f'lut_gen[{idx}].prra_lut_inst'))
        hier.include('../../prra_lut/project/prra_lut.wave.py')

    return blk
