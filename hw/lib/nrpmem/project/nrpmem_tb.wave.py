"""Wavedisp file for module nrpmem_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Block
from wavedisp.ast import Disp
from wavedisp.ast import Divider


def generator():
    """Generator for module nrpmem_tb."""
    testbench = Hierarchy("nrpmem_tb")
    grp1 = testbench.add(Group("DUT_COMB"))
    inst = grp1.add(Hierarchy("dut_comb"))
    inst.include("nrpmem.wave.py")

    grp2 = testbench.add(Group("DUT_REG"))
    inst2 = grp2.add(Hierarchy("dut_reg"))
    inst2.include("nrpmem.wave.py")
    return testbench
