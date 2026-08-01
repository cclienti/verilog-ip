# -*- python -*-
"""Wavedisp file for module parmem17_16."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(nb_banks=17, internals=False, banks=False):
    """Generator for module parmem17_16.

    Ports only by default -- with 17 banks the sub-hierarchies alone are
    204 traces, which makes GTKWave crawl.

    :param bool internals: add the CRT decode and steering signals.
    :param bool banks: add each bank's dpmemrf hierarchy.
    """
    blk = Block()

    blk.add(Divider('side A -- strided access group'))
    blk.add(Disp(['clka', 'en', 'wen', 'lane_en']))
    blk.add(Disp(['addr', 'stride']))
    blk.add(Disp(['dia', 'doa']))

    blk.add(Divider('conflict reporting'))
    # No byte write enables and no internal serialization on this member:
    # it reports `conflict` and the caller serializes (../README.rst).
    blk.add(Disp(['conflict', 'oob']))

    blk.add(Divider('side B -- network interface'))
    blk.add(Disp(['clkb', 'enb', 'web']))
    blk.add(Disp(['addrb', 'dib', 'dob', 'oobb']))

    if internals:
        blk.add(Divider('internals -- CRT decode and steering'))
        blk.add(Disp(['smod', 'scorr']))
        blk.add(Disp(['ce', 'ena_bank', 'wea_bank']))

    if banks:
        blk.add(Divider('internals -- banks'))
        for bank in range(nb_banks):
            group = blk.add(Group(f'bank_{bank}'))
            hier = group.add(Hierarchy(f'gen_bank[{bank}].bank_inst'))
            hier.include('../../../dpmemrf/project/dpmemrf.wave.py')

    return blk
