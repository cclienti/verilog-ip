Open Source Digital Hardware IP Library
=======================================

**A showcase of reusable, high-quality Verilog/SystemVerilog IP cores and hardware modules.**

Welcome! This repository is a curated collection of open source digital hardware building blocks,
design examples, and subsystems. Whether you are a hardware designer, student, or enthusiast,
you'll find ready-to-use modules and inspiration for your next FPGA or ASIC project.

Project Highlights
------------------

- 🚀 **Reusable IP Cores:** Arithmetic, memory, communication, and control modules.
- 🛠️ **Subsystems & Examples:** Motor control, Network-on-Chip (NoC), and more.
- 📚 **Well-documented:** Each module includes a detailed README and usage guide.
- 🔬 **Fully Verified:** Each module comes with a testbench and simulation environment.
- 🌍 **Truly Open Hardware:** Licensed under the CERN-OHL-P v2 for maximum freedom and collaboration.

Available IP Cores
------------------

Arithmetic
~~~~~~~~~~

+--------------------------------------------------------------+----------------------------------------------+
| Module                                                       | Description                                  |
+==============================================================+==============================================+
| `adderc <hw/lib/adderc/README.rst>`_                         | Adder/Subtractor with Carry In/Out           |
+--------------------------------------------------------------+----------------------------------------------+
| `multiplier <hw/lib/multiplier/README.rst>`_                 | Signed/Unsigned Multiplier                   |
+--------------------------------------------------------------+----------------------------------------------+
| `smalldiv <hw/lib/smalldiv/README.rst>`_                     | Small Constant Divider                       |
+--------------------------------------------------------------+----------------------------------------------+
| `barrel <hw/lib/barrel/README.rst>`_                         | Barrel Shifter                               |
+--------------------------------------------------------------+----------------------------------------------+

Memory
~~~~~~

+--------------------------------------------------------------+----------------------------------------------+
| Module                                                       | Description                                  |
+==============================================================+==============================================+
| `asdpmem <hw/lib/asdpmem/README.rst>`_                       | Asynchronous Read Dual Port Memory           |
+--------------------------------------------------------------+----------------------------------------------+
| `dpmemrf <hw/lib/dpmemrf/README.rst>`_                       | Dual Port Read First Memory                  |
+--------------------------------------------------------------+----------------------------------------------+
| `dpmemwf <hw/lib/dpmemwf/README.rst>`_                       | Dual Port Write First Memory                 |
+--------------------------------------------------------------+----------------------------------------------+
| `nrpmem <hw/lib/nrpmem/README.rst>`_                         | N-Read-Port Memory (1 write, N async reads)  |
+--------------------------------------------------------------+----------------------------------------------+
| `vliwrf <hw/lib/vliwrf/README.rst>`_                         | VLIW Multi-Port Register File                |
+--------------------------------------------------------------+----------------------------------------------+
| `shmemif <hw/lib/shmemif/README.rst>`_                       | Multiport Shared Memory Interface            |
+--------------------------------------------------------------+----------------------------------------------+
+--------------------------------------------------------------+----------------------------------------------+

FIFO
~~~~

+--------------------------------------------------------------+----------------------------------------------+
| Module                                                       | Description                                  |
+==============================================================+==============================================+
| `dclkfifolut <hw/lib/dclkfifolut/README.rst>`_               | Dual Clock FIFO (LUT-based)                  |
+--------------------------------------------------------------+----------------------------------------------+
| `sclkfifolut <hw/lib/sclkfifolut/README.rst>`_               | Single Clock FIFO (LUT-based)                |
+--------------------------------------------------------------+----------------------------------------------+
| `sclkfiforeg <hw/lib/sclkfiforeg/README.rst>`_               | Single Register FIFO                         |
+--------------------------------------------------------------+----------------------------------------------+

Encoding & Comparison
~~~~~~~~~~~~~~~~~~~~~

+--------------------------------------------------------------+----------------------------------------------+
| Module                                                       | Description                                  |
+==============================================================+==============================================+
| `bin2gray <hw/lib/bin2gray/README.rst>`_                     | Asynchronous Binary to Gray Converter        |
+--------------------------------------------------------------+----------------------------------------------+
| `gray2bin <hw/lib/gray2bin/README.rst>`_                     | Asynchronous Gray to Binary Converter        |
+--------------------------------------------------------------+----------------------------------------------+
| `cmpgt <hw/lib/cmpgt/README.rst>`_                           | Signed/Unsigned Greater Than Comparator      |
+--------------------------------------------------------------+----------------------------------------------+
| `cmplt <hw/lib/cmplt/README.rst>`_                           | Signed/Unsigned Less Than Comparator         |
+--------------------------------------------------------------+----------------------------------------------+
| `rdselb <hw/lib/rdselb/README.rst>`_                         | Byte Read Select                             |
+--------------------------------------------------------------+----------------------------------------------+
| `rdselh <hw/lib/rdselh/README.rst>`_                         | Half-Word Read Select                        |
+--------------------------------------------------------------+----------------------------------------------+

Arbitration
~~~~~~~~~~~

+--------------------------------------------------------------+----------------------------------------------+
| Module                                                       | Description                                  |
+==============================================================+==============================================+
| `prra <hw/lib/prra/README.rst>`_                             | Parallel Round-Robin Arbiter                 |
+--------------------------------------------------------------+----------------------------------------------+
| `prra_lut <hw/lib/prra_lut/README.rst>`_                     | Parallel Round-Robin Arbiter (LUT-based)     |
+--------------------------------------------------------------+----------------------------------------------+

Communication
~~~~~~~~~~~~~

+--------------------------------------------------------------+----------------------------------------------+
| Module                                                       | Description                                  |
+==============================================================+==============================================+
| `simple_uart <hw/lib/simple_uart/README.rst>`_               | Simple UART (TX/RX)                          |
+--------------------------------------------------------------+----------------------------------------------+
| `rmii_mac_rx <hw/lib/rmii_mac_rx/README.rst>`_               | Fast Ethernet RMII MAC Receiver              |
+--------------------------------------------------------------+----------------------------------------------+

Utilities
~~~~~~~~~

+--------------------------------------------------------------+----------------------------------------------+
| Module                                                       | Description                                  |
+==============================================================+==============================================+
| `misc <hw/lib/misc/README.rst>`_                             | Miscellaneous utilities (math, assertions)   |
+--------------------------------------------------------------+----------------------------------------------+
| `report <hw/lib/report/README.rst>`_                         | Info/Warning/Error Report Module             |
+--------------------------------------------------------------+----------------------------------------------+

Motor Control Subsystem
-----------------------

A complete motor control subsystem for FPGA-based systems, targeting the DE0-Nano board.
See `hw/motor_control/README.rst <hw/motor_control/README.rst>`_ for details.

+--------------------------------------------------------------------+----------------------------------------------+
| Module                                                             | Description                                  |
+====================================================================+==============================================+
| `pwm_generator <hw/motor_control/pwm_generator/README.rst>`_      | Parameterizable PWM Signal Generator         |
+--------------------------------------------------------------------+----------------------------------------------+
| `quad_encoder <hw/motor_control/quad_encoder/README.rst>`_        | Quadrature Encoder Interface                 |
+--------------------------------------------------------------------+----------------------------------------------+
| `uart_reg_if <hw/motor_control/uart_reg_if/README.rst>`_          | UART-based Register Interface                |
+--------------------------------------------------------------------+----------------------------------------------+
| `de0_nano <hw/motor_control/de0_nano/README.rst>`_                | DE0-Nano Example Integration Project         |
+--------------------------------------------------------------------+----------------------------------------------+

Network-on-Chip (HyNoC)
------------------------

**HyNoC** is a High-performance Network-on-Chip (NoC) dedicated to High Performance Computing,
featuring static and dynamic source routing, wormhole switching, and distributed arbitration.
See `hw/network/hynoc/README.rst <hw/network/hynoc/README.rst>`_ for full documentation.

Directory Structure
-------------------

.. code-block:: text

   hw/
   ├── boards/         Board-specific top-levels and constraints
   ├── lib/            Reusable Verilog IP cores
   ├── Makefiles/      Shared build and simulation scripts
   ├── motor_control/  Motor control subsystem and DE0-Nano example
   └── network/        Network-on-Chip (HyNoC)

Getting Started
---------------

1. **Browse the hardware modules:**
   Explore the `hw/` directory and check each submodule's README for features and integration tips.

2. **Integrate in your project:**
   Copy the Verilog/SystemVerilog files you need and follow the usage instructions.

3. **Simulate and build:**
   Use the provided Makefiles and testbenches to verify and synthesize your design.

Simulation
----------

Each IP core and subsystem has a `project/` directory containing a `Makefile` that wraps the simulation tools.
The following simulators are supported: **Icarus Verilog**, **Verilator**, and **ModelSim/Questa**.

**Waveform Display with wavedisp**

Waveforms are managed using `wavedisp <https://github.com/cclienti/wavedisp>`_, a Python package
that provides a portable way to describe and display waveforms across different HDL simulators and
waveform viewers. It generates TCL scripts for **GTKWave**, **ModelSim** and **RivieraPro**, and a
command file for **Surfer**, from a unique waveform description written in Python.

Each module provides a ``<testbench>.wave.py`` file describing the waveform layout. The
``make trace`` and ``make trace-surfer`` targets generate the corresponding script and open the
viewer with the right waveform configuration.

``wavedisp`` is automatically installed in a local Python virtual environment (``hw/.venv``) on
the first use of ``make trace`` or ``make wavedisp``. No manual installation is required.

**Icarus Verilog**

To run a simulation and generate a waveform file:

.. code-block:: bash

   cd hw/lib/adderc/project
   make sim

The dump is written in **FST**, which GTKWave and Surfer both read. Testbenches do not name
their dump file: ``hw/Makefiles/dumper.v`` is elaborated beside the testbench as a second root
module and takes the name and the scope from the makefile.

The format comes from the ``IVERILOG_DUMPER`` environment variable, which ``iverilog.mk``
exports and from which it also derives the file extension, so the two can never disagree. Set
it to ``lxt2`` or ``vcd`` to get ``<testbench>.lxt2`` or ``<testbench>.vcd`` instead. Only the
bare format names work; the tuned variants such as ``fst-space`` exist as ``vvp`` extended
arguments only and are silently ignored here.

Running ``vvp ./<testbench>`` by hand outside ``make`` writes VCD unless your shell exports
``IVERILOG_DUMPER`` too. Adding ``export IVERILOG_DUMPER=fst`` to your shell rc makes the
direct route behave like the ``make`` one.

To run the simulation and open the waveform directly in GTKWave:

.. code-block:: bash

   cd hw/lib/adderc/project
   make trace

To open it in Surfer instead:

.. code-block:: bash

   cd hw/lib/adderc/project
   make trace-surfer

Surfer has no scripting language, so ``wavedisp`` generates a ``<testbench>.sucl`` file: a flat
list of the commands Surfer's own prompt accepts, replayed once the dump is loaded.

To run the simulation and check for errors:

.. code-block:: bash

   cd hw/lib/adderc/project
   make check

**Post-synthesis simulation**

Once ``make vivado-gen-post-syn`` has produced a netlist, ``make sim-post-syn`` simulates it with
the same testbench used for the RTL, and ``make trace-post-syn`` opens the result. The executable
and the dump are named ``<testbench>_postsyn``, so neither overwrites its RTL counterpart.

The testbench is compiled with ``-DPOST_SYNTH`` for that run, which lets it bracket the few places
where the two flows differ:

- the netlist takes no parameter override, synthesis having frozen them;
- the Xilinx flip-flops hold their output until ``glbl.GSR`` falls, 100 ns in, so the reset
  sequence has to wait for it;
- any probe reaching inside the DUT no longer resolves, ``-flatten_hierarchy full`` having
  dissolved the hierarchy it named.

Delays need no rescaling: each file keeps its own ``timescale``, so the netlist imposes its
1 ps precision without the testbench changing units. See ``hw/lib/shmemif/src/shmemif_tb.v`` for a
testbench that serves both flows.

A project preferring to keep the two apart drops a ``<testbench>_postsyn.sv`` beside the RTL
testbench and it is picked up instead, as ``hw/lib/vliwrf`` does.

**Verilator**

To lint the design:

.. code-block:: bash

   cd hw/lib/adderc/project
   make lint

To build the design with Verilator:

.. code-block:: bash

   cd hw/lib/adderc/project
   make verilates

**ModelSim/Questa**

To compile and simulate in console mode:

.. code-block:: bash

   cd hw/lib/adderc/project
   make msim-sim

To compile and simulate with the GUI and waveforms:

.. code-block:: bash

   cd hw/lib/adderc/project
   make msim-simgui

To only compile/elaborate the design:

.. code-block:: bash

   cd hw/lib/adderc/project
   make msim-build

**Available Targets Summary**

+--------------------+---------------------------------------------------+
| Target             | Description                                       |
+====================+===================================================+
| ``sim``            | Simulate with Icarus Verilog, generate FST dump   |
+--------------------+---------------------------------------------------+
| ``trace``          | Simulate with Icarus Verilog and open GTKWave     |
+--------------------+---------------------------------------------------+
| ``trace-surfer``   | Simulate with Icarus Verilog and open Surfer      |
+--------------------+---------------------------------------------------+
| ``check``          | Simulate and check for errors                     |
+--------------------+---------------------------------------------------+
| ``sim-post-syn``   | Simulate the Vivado post-synthesis netlist        |
+--------------------+---------------------------------------------------+
| ``trace-post-syn`` | Post-synthesis simulation, then open GTKWave      |
+--------------------+---------------------------------------------------+
| ``lint``           | Lint the design with Verilator                    |
+--------------------+---------------------------------------------------+
| ``verilates``      | Build the design with Verilator                   |
+--------------------+---------------------------------------------------+
| ``msim-sim``       | Simulate with ModelSim in console mode            |
+--------------------+---------------------------------------------------+
| ``msim-simgui``    | Simulate with ModelSim in GUI mode with waveforms |
+--------------------+---------------------------------------------------+
| ``msim-build``     | Compile/elaborate the design with ModelSim        |
+--------------------+---------------------------------------------------+
| ``clean``          | Remove generated files                            |
+--------------------+---------------------------------------------------+
| ``distclean``      | Remove all generated and project files            |
+--------------------+---------------------------------------------------+

**Note:** Replace ``hw/lib/adderc`` with the path to the module you want to simulate.
All modules follow the same Makefile structure.

Requirements
------------

To run simulations on Linux, you need to install the following tools:

**Debian/Ubuntu**

.. code-block:: bash

   # Icarus Verilog and GTKWave
   sudo apt install iverilog gtkwave

   # Verilator
   sudo apt install verilator

   # Python venv support (required for wavedisp auto-install)
   sudo apt install python3-venv

   # ModelSim/Questa (not available in official repositories)
   # Download and install from https://www.intel.com/content/www/us/en/software/programmable/quartus-prime/model-sim.html

**Fedora**

.. code-block:: bash

   # Icarus Verilog and GTKWave
   sudo dnf install iverilog gtkwave

   # Verilator
   sudo dnf install verilator

   # Python venv support (required for wavedisp auto-install)
   sudo apt install python3-venv

   # ModelSim/Questa (not available in official repositories)
   # Download and install from https://www.intel.com/content/www/us/en/software/programmable/quartus-prime/model-sim.html

**Note:** ModelSim/Questa is a commercial tool from Intel/Altera and is not available in
official Linux package repositories. A free (Starter) edition is available for download
from the Intel FPGA software portal.

Contributing & Contact
----------------------

Contributions, suggestions, and collaborations are welcome!
If you're interested in using these designs commercially, or want to discuss custom hardware
development, please `contact me via GitHub <https://github.com/cclienti>`_.

License
-------

All HDL (Verilog/SystemVerilog) source files are licensed under the
**CERN Open Hardware Licence Version 2 - Permissive (CERN-OHL-P-2.0)**.
See `hw/LICENSE <./hw/LICENSE>`_ for details.

---

*Star this repository ⭐ to support open hardware and follow for more digital design content!*
