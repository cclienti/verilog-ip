"""Wavedisp file for module vliwrf_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group


def generator(num_write_ports=4, num_read_ports=8):
    """Generator for module vliwrf_tb."""
    testbench = Hierarchy("vliwrf_tb")

    grp1 = testbench.add(Group("DUT_COMB"))
    inst_comb = grp1.add(Hierarchy("dut_comb"))
    inst_comb.include("vliwrf.wave.py")

    grp2 = testbench.add(Group("DUT_REG"))
    inst_reg = grp2.add(Hierarchy("dut_reg"))
    inst_reg.include("vliwrf.wave.py")

    return testbench
