Fast Ethernet RMII MAC Receiver
================================

Description
-----------

The ``rmii_mac_rx`` module implements a Fast Ethernet RMII MAC receiver. It receives data from a
PHY using the 2-bit RMII interface and outputs Ethernet frames as AXI stream data, with preamble
and SFD stripped (only the payload is sent). Frame boundaries and errors are signaled using AXI
stream sideband signals.

Parameters
----------

None. This module has no parameters.

Signals
-------

============  ============  ========  ===========================================
Name          I/O type      Range     Description
============  ============  ========  ===========================================
clock         input wire    1         System clock (50 MHz)
srst          input wire    1         Synchronous reset, active high
rxd           input wire    [1:0]     2-bit data from PHY (RMII)
rxen          input wire    1         PHY data valid
axi_tvalid    output wire   1         AXI stream data valid
axi_tlast     output wire   1         Last byte of the Ethernet frame
axi_tdata     output wire   [1:0]     AXI stream data
axi_tuser     output wire   1         Frame error indicator
axi_tready    input wire    1         AXI stream ready
============  ============  ========  ===========================================

Example Instantiation
---------------------

.. code-block:: verilog

   rmii_mac_rx u_rmii_mac_rx (
     .clock(clock),
     .srst(srst),
     .rxd(rxd),
     .rxen(rxen),
     .axi_tvalid(axi_tvalid),
     .axi_tlast(axi_tlast),
     .axi_tdata(axi_tdata),
     .axi_tuser(axi_tuser),
     .axi_tready(axi_tready)
   );

Simulation
----------

.. code-block:: bash

   cd project
   make sim    # Icarus Verilog simulation
   make trace  # Simulate and open GTKWave
   make lint   # Lint with Verilator

License
-------

This module is licensed under the **CERN Open Hardware Licence Version 2 - Permissive (CERN-OHL-P-2.0)**.
See `LICENSE <../../LICENSE>`_ for details.
