Motor Control Modules
=====================

This directory contains Verilog/SystemVerilog modules and example projects for FPGA-based motor
control applications. The modules are designed to work together and can be integrated on the
DE0-Nano board or any other FPGA platform.

Modules
-------

+---------------------------------------------------------------+------------------------------------------------------+
| Module                                                        | Description                                          |
+===============================================================+======================================================+
| `pwm_generator <pwm_generator/README.rst>`_                   | Parameterizable PWM signal generator                 |
+---------------------------------------------------------------+------------------------------------------------------+
| `quad_encoder <quad_encoder/README.rst>`_                     | Quadrature encoder interface with input filtering    |
+---------------------------------------------------------------+------------------------------------------------------+
| `uart_reg_if <uart_reg_if/README.rst>`_                       | UART-based register interface for remote control     |
+---------------------------------------------------------------+------------------------------------------------------+
| `de0_nano <de0_nano/README.rst>`_                             | DE0-Nano top-level integration example               |
+---------------------------------------------------------------+------------------------------------------------------+

System Overview
---------------

The motor control subsystem integrates the above modules into a complete solution:

- The **PWM generator** produces a variable duty-cycle signal to control motor speed.
- The **Quadrature encoder** reads position and direction from a rotary encoder attached to the motor shaft.
- The **UART register interface** enables a host (PC or microcontroller) to read encoder data and set PWM parameters over a serial link.
- The **DE0-Nano** top-level ties all modules together for a ready-to-use demonstration.

.. code-block:: text

   Host (PC/MCU)
       │
       │ UART (serial)
       ▼
   uart_reg_if ──► pwm_generator ──► PWM output ──► Motor driver
                       ▲
   quad_encoder ───────┘ (position/direction feedback)

Simulation
----------

Each module has a ``project/`` directory with a ``Makefile``. For example:

.. code-block:: bash

   cd pwm_generator/project
   make sim    # Icarus Verilog simulation
   make trace  # Simulate and open GTKWave
   make lint   # Lint with Verilator

License
-------

All source files are licensed under the **CERN Open Hardware Licence Version 2 - Permissive (CERN-OHL-P-2.0)**.
See `LICENSE <../LICENSE>`_ for details.
