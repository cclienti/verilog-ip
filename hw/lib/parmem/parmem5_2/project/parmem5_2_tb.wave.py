# -*- python -*-
"""Wavedisp file for module parmem5_2_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module parmem5_2_tb.

    Only the baseline DUT is opened with its internals; the variants get
    their ports, and the four sweep instances only the handful of signals
    that distinguish them. Pass internals=True / banks=True on an
    include below to dig into one of them.
    """
    testbench = Hierarchy('parmem5_2_tb')

    testbench.add(Divider('stimulus -- side A'))
    testbench.add(Disp(['clka', 'clkb', 'errors']))
    testbench.add(Disp(['en', 'wen', 'lane_en', 'addr', 'stride']))
    testbench.add(Disp(['ben', 'dia', 'doa']))
    testbench.add(Disp(['freeze', 'conflict', 'oob']))

    testbench.add(Divider('stimulus -- side B'))
    testbench.add(Disp(['enb', 'web', 'benb', 'addrb']))
    testbench.add(Disp(['dib', 'dob', 'oobb']))

    grp = testbench.add(Group('dut (ADRREG=0, OUTREGA=0)'))
    inst = grp.add(Hierarchy('parmem5_2_inst'))
    inst.include('parmem5_2.wave.py', internals=True)

    # The ADRREG=1 instance is driven from the delayed stimulus.
    testbench.add(Divider('stimulus -- ADRREG=1 variant, delayed one cycle'))
    testbench.add(Disp(['en_p', 'wen_p', 'lane_en_p', 'addr_p', 'stride_p']))
    testbench.add(Disp(['ben_p', 'dia_p', 'doa_p']))
    testbench.add(Disp(['freeze_p', 'conflict_p', 'oob_p']))

    grp = testbench.add(Group('dut_p (ADRREG=1)'))
    inst = grp.add(Hierarchy('parmem5_2_adr_inst'))
    inst.include('parmem5_2.wave.py')

    # Serialization sweep: SER_D = ADRREG + 1 + OUTREGA, so the replay
    # timing differs per instance. Only the signals that show it.
    testbench.add(Divider('serialization sweep'))
    testbench.add(Disp(['en_s', 'wen_s', 'lane_en_s', 'addr_s', 'stride_s']))
    # doa_s is an unpacked array, which iverilog does not dump; each
    # instance's own doa below carries the same data.
    testbench.add(Disp(['ben_s', 'dia_s', 'freeze_s']))
    for idx in range(4):
        adrreg, outrega = idx % 2, idx // 2
        grp = testbench.add(
            Group(f'sweep_{idx} (ADRREG={adrreg}, OUTREGA={outrega})'))
        inst = grp.add(Hierarchy(f'gen_sweep[{idx}].sweep_inst'))
        inst.add(Disp(['doa', 'freeze', 'ser_dly', 'ser_flush', 'doa0_hold']))

    return testbench
