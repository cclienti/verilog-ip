# -*- python -*-
"""Wavedisp file for module parmem3_2."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(nb_banks=3, internals=False, banks=False):
    """Generator for module parmem3_2.

    Ports only by default: a testbench instantiating several DUTs would
    otherwise open GTKWave with hundreds of traces and crawl.

    :param bool internals: add the CRT decode, steering and serialization
                           signals.
    :param bool banks: add each bank's dpmemrf hierarchy (nb_banks x 12
                       signals) -- only worth it when debugging a bank
                       access itself.
    """
    blk = Block()

    blk.add(Divider('side A -- dual strided access pair'))
    blk.add(Disp(['clka', 'en', 'wen', 'lane_en']))
    blk.add(Disp(['addr', 'stride', 'ben']))
    blk.add(Disp(['dia', 'doa']))

    blk.add(Divider('conflict handling'))
    blk.add(Disp(['conflict', 'freeze', 'oob']))

    blk.add(Divider('side B -- network interface'))
    blk.add(Disp(['clkb', 'enb', 'web', 'benb']))
    blk.add(Disp(['addrb', 'dib', 'dob', 'oobb']))

    if internals:
        blk.add(Divider('internals -- CRT decode and steering'))
        blk.add(Disp(['smod', 'scorr']))
        blk.add(Disp(['bank0', 'bank1', 'idx0', 'idx1']))
        blk.add(Disp(['ce', 'ena_bank', 'wea_bank']))

        blk.add(Divider('internals -- serialization'))
        blk.add(Disp(['same_word', 'ser_start', 'ser_phase', 'lane_en_eff']))
        blk.add(Disp(['ser_dly', 'ser_flush', 'doa0_hold']))
        blk.add(Disp(['sel0', 'sel1']))

    if banks:
        blk.add(Divider('internals -- banks'))
        for bank in range(nb_banks):
            group = blk.add(Group(f'bank_{bank}'))
            hier = group.add(Hierarchy(f'gen_bank[{bank}].bank_inst'))
            hier.include('../../../dpmemrf/project/dpmemrf.wave.py')

    return blk
