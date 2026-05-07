# -*- python -*-

from wavedisp.ast import Hierarchy, Disp, Divider


def generator():
    testbench = Hierarchy('nrpmem_tb')

    testbench.add(Disp('clk',    radix='binary'))
    testbench.add(Disp('enable', radix='binary'))
    testbench.add(Divider('Write port'))
    testbench.add(Disp('wren',   radix='binary'))
    testbench.add(Disp('wraddr', radix='hexadecimal'))
    testbench.add(Disp('wrdata', radix='hexadecimal'))

    testbench.add(Divider('Combinational DUT (REGISTER_OUTPUTS=0)'))
    inst_comb = testbench.add(Hierarchy('dut_comb'))
    inst_comb.include('nrpmem.wave.py')

    testbench.add(Divider('Registered DUT (REGISTER_OUTPUTS=1)'))
    inst_reg = testbench.add(Hierarchy('dut_reg'))
    inst_reg.include('nrpmem.wave.py')

    return testbench
