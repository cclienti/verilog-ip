# -*- python -*-
"""Wavedisp file for module parmem17_16_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module parmem17_16_tb.

    Two DUTs: the baseline and the ADRREG=1 variant, which the bench
    drives from the `_p` copies of the stimulus so its extra cycle lines
    up. Only the baseline is opened with its internals -- pass
    internals=True / banks=True on the other include to dig into it.
    """
    testbench = Hierarchy('parmem17_16_tb')

    testbench.add(Divider('stimulus -- side A'))
    testbench.add(Disp(['clka', 'clkb', 'errors']))
    testbench.add(Disp(['en', 'wen', 'lane_en', 'addr', 'stride']))
    testbench.add(Disp(['dia', 'doa', 'conflict', 'oob']))

    testbench.add(Divider('stimulus -- side B'))
    testbench.add(Disp(['enb', 'web', 'addrb']))
    testbench.add(Disp(['dib', 'dob', 'oobb']))

    grp = testbench.add(Group('dut (ADRREG=0)'))
    inst = grp.add(Hierarchy('parmem17_16_inst'))
    inst.include('parmem17_16.wave.py', internals=True)

    # The ADRREG=1 instance is driven from the delayed stimulus, so these
    # are its inputs -- not the ones above.
    testbench.add(Divider('stimulus -- ADRREG=1 variant, delayed one cycle'))
    testbench.add(Disp(['en_p', 'wen_p', 'lane_en_p', 'addr_p', 'stride_p']))
    testbench.add(Disp(['dia_p', 'doa_p', 'conflict_p', 'oob_p']))

    grp = testbench.add(Group('dut_p (ADRREG=1)'))
    inst = grp.add(Hierarchy('parmem17_16_adr_inst'))
    inst.include('parmem17_16.wave.py')

    return testbench
