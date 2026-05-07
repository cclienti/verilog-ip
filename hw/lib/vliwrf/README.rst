VLIW Multi-Port Register File
==============================

Description
-----------

The ``vliwrf`` module implements a multi-port register file intended for VLIW (Very Long
Instruction Word) processors and multi-issue datapaths. It provides ``NUM_WRITE_PORTS``
independent write ports and ``NUM_READ_PORTS`` independent read ports.

In processor terms, each **write port corresponds to one functional unit** (e.g. ALU, load/store
unit, multiplier). Each functional unit can only write to its **own private window** of
``2**LOG2_NB_REGS_PER_WR_PORT`` registers — it cannot write into another unit's register window.
This partitioning is a deliberate VLIW design choice: the compiler statically assigns result
registers to functional units, eliminating write-port arbitration hardware entirely.

**Read ports, by contrast, are fully general**: any read port can access any register across
the entire register file, regardless of which functional unit owns that register window. In a
VLIW processor this means every issue slot can freely pick its source operands from the results
of any previous functional unit — exactly the flexibility required for a wide-issue machine.

Architecture
~~~~~~~~~~~~

The register file is built from ``NUM_WRITE_PORTS`` internal ``nrpmem`` banks, one per
functional unit. Each bank stores the private register window of one write port and exposes
``NUM_READ_PORTS`` read ports. All banks are read in parallel on every cycle; the MSBs of
each read address act as a **bank-select** that steers the correct bank's output to the
requesting read port, giving transparent access to the full register space.

**Register address layout** (``RD_ADDR_WIDTH = LOG2_NB_REGS_PER_WR_PORT + log2(NUM_WRITE_PORTS)``
bits per read port):

.. code-block:: text

   [RD_ADDR_WIDTH-1 : LOG2_NB_REGS_PER_WR_PORT]  →  bank select  (which functional unit wrote it)
   [LOG2_NB_REGS_PER_WR_PORT-1 : 0]              →  register offset within that unit's window

Write addresses use only the lower ``LOG2_NB_REGS_PER_WR_PORT`` bits — a functional unit
always writes within its own window and does not need (or have) a bank-select field.

**Total register file capacity:** ``NUM_WRITE_PORTS × 2**LOG2_NB_REGS_PER_WR_PORT`` registers.

Write operations occur on the rising edge of ``clk`` when both ``enable`` and the corresponding
``wren`` bit are asserted. Read data is combinational (zero latency) when ``REGISTER_OUTPUTS``
is ``0``, or registered with one clock cycle latency when ``REGISTER_OUTPUTS`` is ``1``.

Parameters
----------

============================  ==============  ===========================================================
Name                          Default value   Description
============================  ==============  ===========================================================
MEM_WIDTH                     32              Register word width in bits (must be a power of 2)
LOG2_NB_REGS_PER_WR_PORT      5               Log2 of registers per write-port bank (depth = 2**value)
NUM_WRITE_PORTS               4               Number of independent write ports (power of 2, ≥ 2)
NUM_READ_PORTS                8               Number of independent read ports
REGISTER_OUTPUTS              1               If 1, register read outputs (one clock cycle latency)
============================  ==============  ===========================================================

Signals
-------

=======  =============  ==========================================================  ===============================================================
Name     I/O type       Range                                                       Description
=======  =============  ==========================================================  ===============================================================
clk      input logic    1                                                           Clock
enable   input logic    1                                                           Global enable (gates writes and output registers)
wren     input logic    [NUM_WRITE_PORTS-1:0]                                       Per-port write enable (one bit per write port)
wraddr   input logic    [NUM_WRITE_PORTS*LOG2_NB_REGS_PER_WR_PORT-1:0]              Concatenated write addresses (port i at bits [i*W+:W])
wrdata   input logic    [NUM_WRITE_PORTS*MEM_WIDTH-1:0]                             Concatenated write data (port i at bits [i*MEM_WIDTH+:MEM_WIDTH])
rdaddr   input logic    [NUM_READ_PORTS*RD_ADDR_WIDTH-1:0]                          Concatenated read addresses (port i at bits [i*RD_ADDR_WIDTH+:RD_ADDR_WIDTH])
rddata   output logic   [NUM_READ_PORTS*MEM_WIDTH-1:0]                              Concatenated read data (port i at bits [i*MEM_WIDTH+:MEM_WIDTH])
=======  =============  ==========================================================  ===============================================================

Where ``RD_ADDR_WIDTH = LOG2_NB_REGS_PER_WR_PORT + log2(NUM_WRITE_PORTS)``.

Example Instantiation
---------------------

.. code-block:: verilog

   // 4 write ports, 8 read ports, 32 registers per bank (5-bit offset),
   // 32-bit words, registered outputs.
   // Total capacity: 4 × 32 = 128 registers.
   // Read address width: 5 + 2 = 7 bits.

   vliwrf #(
     .MEM_WIDTH               (32),
     .LOG2_NB_REGS_PER_WR_PORT(5),
     .NUM_WRITE_PORTS         (4),
     .NUM_READ_PORTS          (8),
     .REGISTER_OUTPUTS        (1)
   ) u_vliwrf (
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
   make sim           # Icarus Verilog RTL simulation
   make trace         # Simulate and open GTKWave
   make lint          # Lint with Verilator
   make vcd-post-syn  # Post-synthesis simulation (requires Vivado netlist)
   make trace-post-syn  # Post-synthesis simulation + GTKWave

Post-Synthesis Simulation
~~~~~~~~~~~~~~~~~~~~~~~~~

A dedicated post-synthesis testbench (``src/vliwrf_tb_postsyn.sv``) is provided for gate-level
simulation using the Vivado-generated netlist. The Xilinx ``glbl`` module is compiled alongside
the netlist to properly drive the global set/reset (``GSR``) signal required by Xilinx FPGA
primitives (``FDRE``, ``RAM32M``, etc.).

To generate the netlist, run Vivado synthesis first:

.. code-block:: bash

   cd project
   make vivado_syn    # Runs Vivado synthesis, produces vivado-post-syn/vliwrf_syn.v

Then run the post-synthesis simulation:

.. code-block:: bash

   make vcd-post-syn

License
-------

This module is licensed under the **CERN Open Hardware Licence Version 2 - Permissive (CERN-OHL-P-2.0)**.
See `LICENSE <../../LICENSE>`_ for details.
