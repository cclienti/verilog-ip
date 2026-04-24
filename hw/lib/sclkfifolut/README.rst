Single Clock FIFO (LUT-based)
==============================

Description
-----------

The ``sclkfifolut`` module implements a single-clock FIFO using FPGA LUT memory, with
parameterizable depth and data width. It provides status signals for FIFO level, empty, and full
conditions, making it suitable for buffering data within a single clock domain.

Parameters
----------

================  ==============  ========================================
Name              Default value   Description
================  ==============  ========================================
LOG2_FIFO_DEPTH   5               Depth of the FIFO as a power of two
FIFO_WIDTH        32              Width of the FIFO data
================  ==============  ========================================

Signals
-------

========  ===========  ====================  ========================================
Name      I/O type     Range                 Description
========  ===========  ====================  ========================================
clk       input wire   1                     Clock
srst      input wire   1                     Synchronous reset
level     output reg   [LOG2_FIFO_DEPTH:0]   Number of words currently in the FIFO
ren       input wire   1                     Read enable
rdata     output reg   [FIFO_WIDTH-1:0]      Data output
rempty    output reg   1                     FIFO empty flag
wen       input wire   1                     Write enable
wdata     input wire   [FIFO_WIDTH-1:0]      Data input
wfull     output reg   1                     FIFO full flag
========  ===========  ====================  ========================================

Example Instantiation
---------------------

.. code-block:: verilog

   sclkfifolut #(
     .LOG2_FIFO_DEPTH(5),
     .FIFO_WIDTH(32)
   ) u_sclkfifolut (
     .clk(clk),
     .srst(srst),
     .level(level),
     .ren(ren),
     .rdata(rdata),
     .rempty(rempty),
     .wen(wen),
     .wdata(wdata),
     .wfull(wfull)
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
