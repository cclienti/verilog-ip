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
| `parmem <hw/lib/parmem/README.rst>`_                         | Prime-Interleaved Parallel Memory Family     |
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

AXI Stream
~~~~~~~~~~

+--------------------------------------------------------------+----------------------------------------------+
| Module                                                       | Description                                  |
+==============================================================+==============================================+
| `axi_stream_upsizer <hw/lib/axi_stream_upsizer/README.rst>`_ | Widen an AXI stream                          |
+--------------------------------------------------------------+----------------------------------------------+
| `axi_stream_downsizer                                        | Narrow an AXI stream                         |
| <hw/lib/axi_stream_downsizer/README.rst>`_                   |                                              |
+--------------------------------------------------------------+----------------------------------------------+
| `axi_stream_packet_fifo                                      | Packet FIFO with commit/rollback             |
| <hw/lib/axi_stream_packet_fifo/README.rst>`_                 |                                              |
+--------------------------------------------------------------+----------------------------------------------+
| `axi_stream_reg_slice                                        | Register slice (skid buffer)                 |
| <hw/lib/axi_stream_reg_slice/README.rst>`_                   |                                              |
+--------------------------------------------------------------+----------------------------------------------+
| `axi_stream_packet_mux                                       | Frame-atomic round-robin merge               |
| <hw/lib/axi_stream_packet_mux/README.rst>`_                  |                                              |
+--------------------------------------------------------------+----------------------------------------------+
| `axi_stream_packet_demux                                     | Frame-atomic route with side-band select     |
| <hw/lib/axi_stream_packet_demux/README.rst>`_                |                                              |
+--------------------------------------------------------------+----------------------------------------------+

Utilities
~~~~~~~~~

+--------------------------------------------------------------+----------------------------------------------+
| Module                                                       | Description                                  |
+==============================================================+==============================================+
| `crc32 <hw/lib/crc32/README.rst>`_                           | CRC-32 combinational step                    |
+--------------------------------------------------------------+----------------------------------------------+
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

Fast Ethernet (RMII)
--------------------

Building blocks for a Fast Ethernet endpoint on an RMII PHY: MAC receiver and transmitter,
FCS generator and checker.
See `hw/network/ethernet/README.rst <hw/network/ethernet/README.rst>`_ for the module list.

Directory Structure
-------------------

.. code-block:: text

   hw/
   ├── boards/         Board-specific top-levels and constraints
   ├── lib/            Reusable Verilog IP cores
   ├── Makefiles/      Shared build and simulation scripts
   ├── motor_control/  Motor control subsystem and DE0-Nano example
   └── network/        Networking (HyNoC, Fast Ethernet)

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
``make trace.gtkwave`` and ``make trace.surfer`` targets generate the corresponding script and open the
viewer with the right waveform configuration.

``wavedisp`` is automatically installed in a local Python virtual environment (``hw/.venv``) on
the first use of ``make trace.gtkwave`` or ``make waves.wavedisp``. No manual installation is required.

**Icarus Verilog**

To run a simulation and generate a waveform file:

.. code-block:: bash

   cd hw/lib/adderc/project
   make sim.iverilog

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
   make trace.gtkwave

To open it in Surfer instead:

.. code-block:: bash

   cd hw/lib/adderc/project
   make trace.surfer

Surfer has no scripting language, so ``wavedisp`` generates a ``<testbench>.sucl`` file: a flat
list of the commands Surfer's own prompt accepts, replayed once the dump is loaded.

To run the simulation and check for errors:

.. code-block:: bash

   cd hw/lib/adderc/project
   make check.iverilog

**Post-synthesis simulation**

Once ``make synth.vivado`` has produced a netlist, ``make sim-post-syn.iverilog`` simulates it with
the same testbench used for the RTL, and ``make trace-post-syn.gtkwave`` or
``make trace-post-syn.surfer`` opens the result. The executable and the dump are named
``<testbench>_postsyn``, so neither overwrites its RTL counterpart.

Sharing the testbench also means sharing its top-level name, so the save script ``wavedisp``
generates for the RTL run applies to the netlist unchanged — a viewer simply skips the DUT-internal
signals synthesis flattened away. A project with its own ``_postsyn`` testbench has a different top,
and its save script has to be written by hand under that name.

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
   make lint.verilator

To build the design with Verilator:

.. code-block:: bash

   cd hw/lib/adderc/project
   make build.verilator

**ModelSim/Questa**

To compile and simulate in console mode:

.. code-block:: bash

   cd hw/lib/adderc/project
   make sim.modelsim

To compile and simulate with the GUI and waveforms:

.. code-block:: bash

   cd hw/lib/adderc/project
   make trace.modelsim

To only compile/elaborate the design:

.. code-block:: bash

   cd hw/lib/adderc/project
   make build.modelsim

**Available Targets Summary**

Targets are named ``<action>.<tool>``: the action is what you want done, the tool is who does it.
Several vendors do the same job here — two waveform viewers, two simulators — so the tool cannot
be left implicit. ``make help`` lists the targets a given project actually provides, sorted by
action, which depends on the ``.mk`` files its Makefile includes.

+----------------------------+----------------------------------------------------+
| Target                     | Description                                        |
+============================+====================================================+
| ``sim.iverilog``           | Simulate with Icarus Verilog, generate an FST dump |
+----------------------------+----------------------------------------------------+
| ``check.iverilog``         | Simulate without dumping, fail on any error        |
+----------------------------+----------------------------------------------------+
| ``trace.gtkwave``          | Simulate, then open the waveform in GTKWave        |
+----------------------------+----------------------------------------------------+
| ``trace.surfer``           | Simulate, then open the waveform in Surfer         |
+----------------------------+----------------------------------------------------+
| ``sim-post-syn.iverilog``  | Simulate the Vivado post-synthesis netlist         |
+----------------------------+----------------------------------------------------+
| ``trace-post-syn.gtkwave`` | Post-synthesis simulation, then open GTKWave       |
+----------------------------+----------------------------------------------------+
| ``trace-post-syn.surfer``  | Post-synthesis simulation, then open Surfer        |
+----------------------------+----------------------------------------------------+
| ``lint.verilator``         | Lint the design with Verilator                     |
+----------------------------+----------------------------------------------------+
| ``build.verilator``        | Build the design with Verilator                    |
+----------------------------+----------------------------------------------------+
| ``sim.modelsim``           | Simulate with ModelSim in console mode             |
+----------------------------+----------------------------------------------------+
| ``trace.modelsim``         | Simulate with ModelSim in GUI mode with waveforms  |
+----------------------------+----------------------------------------------------+
| ``build.modelsim``         | Compile/elaborate the design with ModelSim         |
+----------------------------+----------------------------------------------------+
| ``synth.vivado``           | Synthesize the design with Vivado                  |
+----------------------------+----------------------------------------------------+
| ``impl.vivado``            | Place & route the design with Vivado               |
+----------------------------+----------------------------------------------------+
| ``project.vivado``         | Generate the Vivado project                        |
+----------------------------+----------------------------------------------------+
| ``project.quartus``        | Generate the Quartus project                       |
+----------------------------+----------------------------------------------------+
| ``waves.wavedisp``         | Generate the save scripts for every viewer         |
+----------------------------+----------------------------------------------------+
| ``clean``                  | Remove the files that rebuild in seconds           |
+----------------------------+----------------------------------------------------+
| ``distclean``              | Also remove project files and tool results         |
+----------------------------+----------------------------------------------------+

``clean`` deliberately spares the Vivado outputs — the netlist, the placed-and-routed checkpoint,
the project. Each costs a synthesis or an implementation run to rebuild, which does not belong
beside a waveform dump that comes back in two seconds. ``make distclean`` removes those.

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
