# -*- python -*-
"""Wavedisp file for module parmem5_4."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator(nb_banks=5, internals=False, banks=False):
    """Generator for module parmem5_4.

    Ports only by default -- with 5 banks the sub-hierarchies alone are
    60 traces, which makes GTKWave crawl.

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
        # idx, ea_full, smul, addra_bank, dia_bank, bankdoa and bankdob
        # are unpacked arrays: iverilog does not dump them, so declaring
        # them here would add nothing at all.
        blk.add(Divider('internals -- side A CRT decode'))
        blk.add(Disp(['sx', 'smod', 'scorr']))
        blk.add(Disp(['bank', 'bank0_oh', 'ce']))

        blk.add(Divider('internals -- side A bank control'))
        blk.add(Disp(['ena_bank', 'wea_bank']))
        # Registered when ADRREG=1, a combinational pass-through of the
        # two above otherwise.
        blk.add(Disp(['ena_bank_q', 'wea_bank_q', 'ce_q', 'bank_q']))
        # Bank id held on the return path, to steer doa.
        blk.add(Disp(['bank_r']))

        blk.add(Divider('internals -- side B CRT decode'))
        blk.add(Disp(['bankb', 'bankb_oh', 'idxb', 'ceb']))
        blk.add(Disp(['enb_bank', 'web_bank', 'bankb_r']))

    if banks:
        blk.add(Divider('internals -- banks'))
        for bank in range(nb_banks):
            group = blk.add(Group(f'bank_{bank}'))
            hier = group.add(Hierarchy(f'gen_bank[{bank}].bank_inst'))
            hier.include('../../../dpmemrf/project/dpmemrf.wave.py')

    return blk
