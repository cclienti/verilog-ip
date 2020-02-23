# -*- python -*-
# To include in hynoc_router_3p_tb.wave.py:
"""Wavedisp file for module hynoc_router_3p_tb."""

from wavedisp.ast import Hierarchy
from wavedisp.ast import Group
from wavedisp.ast import Disp


def generator():
    """Generator for module hynoc_router_3p_tb."""

    testbench = Hierarchy('hynoc_router_3p_tb')
    testbench.add(Disp('router_clk'))
    testbench.add(Disp('router_srst'))

    for local in range(4):
        grp = testbench.add(Group(f'Local {local}'))
        hier = grp.add(Hierarchy(f'GEN_LOCAL_XFCES[{local}].hynoc_local_interface_inst'))
        hier.add(Disp('local_clk'))
        hier.add(Disp('local_srst'))
        hier.add(Disp('local_ingress_write'))
        hier.add(Disp('local_ingress_data'))
        hier.add(Disp('local_ingress_full'))
        hier.add(Disp('local_ingress_fifo_level'))
        hier.add(Disp('local_egress_read'))
        hier.add(Disp('local_egress_data'))
        hier.add(Disp('local_egress_empty'))
        hier.add(Disp('local_egress_fifo_level'))

    return testbench
