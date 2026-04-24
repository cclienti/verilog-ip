Single Register FIFO
=====================

Description
-----------

The ``sclkfiforeg`` module implements a single-register FIFO (depth = 1) with ready/valid handshake
and parameterizable data width. It provides empty and full status signals, making it useful for
simple buffering or pipelining between modules in a single clock domain.

Parameters
----------

======  ==============  ===========================
Name    Default value   Description
======  ==============  ===========================
WIDTH   32              Data width
======  ==============  ===========================

Signals
-------

========  ===========  ============  ============================
Name      I/O type     Range         Description
========  ===========  ============  ============================
clk       input wire   1             Clock
srst      input wire   1             Synchronous reset
ren       input wire   1             Read enable
rdata     output reg   [WIDTH-1:0]   Data output
rempty    output reg   1             FIFO empty flag
wen       input wire   1             Write enable
wdata     input wire   [WIDTH-1:0]   Data input
wfull     output reg   1             FIFO full flag
========  ===========  ============  ============================

Example Instantiation
---------------------

.. code-block:: verilog

   sclkfiforeg #(
     .WIDTH(32)
   ) u_sclkfiforeg (
     .clk(clk),
     .srst(srst),
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
