N-Read-Port Memory
==================

Description
-----------

The ``nrpmem`` module implements a memory with one synchronous write port and ``NUMBER_READ_PORTS``
independent asynchronous read ports. It is built from ``NUMBER_READ_PORTS`` dual-port LUT-RAMs, all
sharing the same write port. Each RAM instance services one read port independently, allowing fully
parallel simultaneous reads at different addresses.

The write operation occurs on the rising edge of ``clk`` when both ``enable`` and ``wren`` are
asserted. Each read port provides its data combinationally (zero latency) when ``REGISTER_OUTPUTS``
is ``0``, or with one clock cycle latency gated by ``enable`` when ``REGISTER_OUTPUTS`` is ``1``.

Synthesis attributes are included to force LUT-based distributed RAM inference on both Xilinx
(``ram_style = "distributed"``) and Intel/Altera (``ramstyle = "logic"``) FPGA toolchains.

Parameters
----------

===================  ==============  =====================================================
Name                 Default value   Description
===================  ==============  =====================================================
MEM_WIDTH            32              Memory word width in bits
LOG2_MEM_DEPTH       6               Log2 of the number of words (depth = 2**LOG2_MEM_DEPTH)
NUMBER_READ_PORTS    8               Number of independent asynchronous read ports
REGISTER_OUTPUTS     0               If 1, register read outputs (adds one cycle latency)
===================  ==============  =====================================================

Signals
-------

=======  =============  ==========================================  ========================================
Name     I/O type       Range                                       Description
=======  =============  ==========================================  ========================================
clk      input logic    1                                           Clock
enable   input logic    1                                           Global enable (gates write and output reg)
wren     input logic    1                                           Write enable
wraddr   input logic    [LOG2_MEM_DEPTH-1:0]                        Write address
wrdata   input logic    [MEM_WIDTH-1:0]                             Write data
rdaddr   input logic    [NUMBER_READ_PORTS*LOG2_MEM_DEPTH-1:0]      Concatenated read addresses (port i at bits [(i+1)*LOG2_MEM_DEPTH-1 -: LOG2_MEM_DEPTH])
rddata   output logic   [NUMBER_READ_PORTS*MEM_WIDTH-1:0]           Concatenated read data (port i at bits [(i+1)*MEM_WIDTH-1 -: MEM_WIDTH])
=======  =============  ==========================================  ========================================

Example Instantiation
---------------------

.. code-block:: verilog

   nrpmem #(
     .MEM_WIDTH        (32),
     .LOG2_MEM_DEPTH   (6),
     .NUMBER_READ_PORTS(4),
     .REGISTER_OUTPUTS (0)
   ) u_nrpmem (
     .clk    (clk),
     .enable (enable),
     .wren   (wren),
     .wraddr (wraddr),
     .wrdata (wrdata),
     .rdaddr (rdaddr),
     .rddata (rddata)
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
