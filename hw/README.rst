Hardware Directory Overview
==========================

This directory contains all hardware-related source files, IP cores, and project-specific modules for this repository.

Directory Structure
-------------------

- **boards/**: Board-specific files, constraints, and top-level integration for supported FPGA or ASIC boards.
- **lib/**: Reusable Verilog IP cores for arithmetic, memory, communication, and control. See `lib/README.rst` for details.
- **Makefiles/**: Makefile fragments and build scripts for hardware synthesis, simulation, and verification.
- **motor_control/**: Motor control modules and subsystems, including PWM generators, encoders, and interfaces. See `motor_control/README.rst` for details.
- **network/**: Network-on-Chip (NoC) and related communication modules. See `network/README.rst` for details.

How to Use
----------

1. Browse the subdirectories for the hardware modules or IP cores you need.
2. Refer to each subdirectory's `README.rst` for detailed documentation and integration instructions.
3. Use the provided Makefiles and scripts for building, simulating, or synthesizing your hardware designs.

Contributions
-------------

Contributions and improvements are welcome. Please ensure new modules are well-documented and tested.

License
-------

All HDL (Verilog/SystemVerilog) source files in this directory are licensed under the **CERN Open Hardware Licence Version 2 - Permissive (CERN-OHL-P-2.0)**.

The full license text is available in [hw/LICENSE](./LICENSE).
