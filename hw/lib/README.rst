Verilog IP Core Library
=======================

This directory contains a collection of reusable, well-documented and verified Verilog IP cores for
digital design projects. Each subdirectory provides a specific function or building block, such as
arithmetic, memory, communication, or control. All modules include testbenches and simulation
environments.

Arithmetic
----------

+---------------------------------------------------------------+----------------------------------------------+
| Module                                                        | Description                                  |
+===============================================================+==============================================+
| `adderc <adderc/README.rst>`_                                 | Adder/Subtractor with Carry In/Out           |
+---------------------------------------------------------------+----------------------------------------------+
| `multiplier <multiplier/README.rst>`_                         | Pipelined Signed/Unsigned Multiplier         |
+---------------------------------------------------------------+----------------------------------------------+
| `smalldiv <smalldiv/README.rst>`_                             | Small Constant Divider                       |
+---------------------------------------------------------------+----------------------------------------------+
| `barrel <barrel/README.rst>`_                                 | Right Barrel Shifter with sign extension     |
+---------------------------------------------------------------+----------------------------------------------+

Memory
------

+---------------------------------------------------------------+----------------------------------------------+
| Module                                                        | Description                                  |
+===============================================================+==============================================+
| `asdpmem <asdpmem/README.rst>`_                               | Asynchronous Read Dual Port Memory (LUT)     |
+---------------------------------------------------------------+----------------------------------------------+
| `dpmemrf <dpmemrf/README.rst>`_                               | Dual Port Read First Memory                  |
+---------------------------------------------------------------+----------------------------------------------+
| `dpmemwf <dpmemwf/README.rst>`_                               | Dual Port Write First Memory                 |
+---------------------------------------------------------------+----------------------------------------------+
| `nrpmem <nrpmem/README.rst>`_                                 | N-Read-Port Memory (1 write, N async reads)  |
+---------------------------------------------------------------+----------------------------------------------+
| `vliwrf <vliwrf/README.rst>`_                                 | VLIW Multi-Port Register File                |
+---------------------------------------------------------------+----------------------------------------------+
| `shmemif <shmemif/README.rst>`_                               | Multiport Shared Memory Interface            |
+---------------------------------------------------------------+----------------------------------------------+

FIFO
----

+---------------------------------------------------------------+----------------------------------------------+
| Module                                                        | Description                                  |
+===============================================================+==============================================+
| `dclkfifolut <dclkfifolut/README.rst>`_                       | Dual Clock FIFO (LUT-based, Gray pointers)   |
+---------------------------------------------------------------+----------------------------------------------+
| `sclkfifolut <sclkfifolut/README.rst>`_                       | Single Clock FIFO (LUT-based)                |
+---------------------------------------------------------------+----------------------------------------------+
| `sclkfiforeg <sclkfiforeg/README.rst>`_                       | Single Register FIFO (depth=1)               |
+---------------------------------------------------------------+----------------------------------------------+

Encoding & Comparison
---------------------

+---------------------------------------------------------------+----------------------------------------------+
| Module                                                        | Description                                  |
+===============================================================+==============================================+
| `bin2gray <bin2gray/README.rst>`_                             | Combinational Binary to Gray Converter       |
+---------------------------------------------------------------+----------------------------------------------+
| `gray2bin <gray2bin/README.rst>`_                             | Combinational Gray to Binary Converter       |
+---------------------------------------------------------------+----------------------------------------------+
| `cmpgt <cmpgt/README.rst>`_                                   | Signed/Unsigned Greater Than Comparator      |
+---------------------------------------------------------------+----------------------------------------------+
| `cmplt <cmplt/README.rst>`_                                   | Signed/Unsigned Less Than Comparator         |
+---------------------------------------------------------------+----------------------------------------------+
| `rdselb <rdselb/README.rst>`_                                 | Byte Read Select with sign/zero extension    |
+---------------------------------------------------------------+----------------------------------------------+
| `rdselh <rdselh/README.rst>`_                                 | Half-Word Read Select with sign/zero extend  |
+---------------------------------------------------------------+----------------------------------------------+

Arbitration
-----------

+---------------------------------------------------------------+----------------------------------------------+
| Module                                                        | Description                                  |
+===============================================================+==============================================+
| `prra <prra/README.rst>`_                                     | Parallel Round-Robin Arbiter                 |
+---------------------------------------------------------------+----------------------------------------------+
| `prra_lut <prra_lut/README.rst>`_                             | Parallel Round-Robin Arbiter (LUT-based)     |
+---------------------------------------------------------------+----------------------------------------------+

Communication
-------------

+---------------------------------------------------------------+----------------------------------------------+
| Module                                                        | Description                                  |
+===============================================================+==============================================+
| `simple_uart <simple_uart/README.rst>`_                       | Simple UART (TX/RX, 8N1, parameterizable)    |
+---------------------------------------------------------------+----------------------------------------------+
| `rmii_mac_rx <rmii_mac_rx/README.rst>`_                       | Fast Ethernet RMII MAC Receiver (AXI stream) |
+---------------------------------------------------------------+----------------------------------------------+

Utilities
---------

+---------------------------------------------------------------+----------------------------------------------+
| Module                                                        | Description                                  |
+===============================================================+==============================================+
| `misc <misc/README.rst>`_                                     | Math functions and simulation assertions     |
+---------------------------------------------------------------+----------------------------------------------+
| `report <report/README.rst>`_                                 | Info/Warning/Error Report Module             |
+---------------------------------------------------------------+----------------------------------------------+

How to Use
----------

1. Browse the subdirectories for the IP core you need.
2. Read the corresponding ``README.rst`` for documentation, parameters, signals, and integration instructions.
3. Integrate the Verilog source files into your project as needed.
4. Use the provided Makefiles and testbenches to simulate and verify your design.

Simulation
----------

Each module has a ``project/`` directory with a ``Makefile``. For example, to simulate ``adderc``:

.. code-block:: bash

   cd adderc/project
   make sim    # Icarus Verilog simulation
   make trace  # Simulate and open GTKWave
   make lint   # Lint with Verilator

License
-------

All source files are licensed under the **CERN Open Hardware Licence Version 2 - Permissive (CERN-OHL-P-2.0)**.
See `LICENSE <../LICENSE>`_ for details.
