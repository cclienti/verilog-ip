Small Constant Divider
=======================

Description
-----------

The ``smalldiv`` module computes the quotient and remainder of a dividend divided by a constant
divider value. The implementation is optimized for small constant dividers and is parameterizable
for divider value, dividend width, and pipeline registers. Useful for efficient division by small
constants in hardware.

Parameters
----------

=====================  ==============  ===========================================
Name                   Default value   Description
=====================  ==============  ===========================================
DIVIDER_VALUE          5               Constant divider value
DIVIDER_WIDTH          $clog2(5)       Width of divider
DIVIDEND_WIDTH         18              Width of dividend
THEORETICAL_LUT_WIDTH  6               LUT width for implementation
REGISTER_IN            1               Register input if set
REGISTER_OUT           1               Register output if set
=====================  ==============  ===========================================

Signals
-------

=========  ===========  ====================  ============================
Name       I/O type     Range                 Description
=========  ===========  ====================  ============================
clock      input wire   1                     Clock
enable     input wire   1                     Enable
dividend   input wire   [DIVIDEND_WIDTH-1:0]  Dividend input
quotient   output reg   [DIVIDEND_WIDTH-1:0]  Quotient output
remainder  output reg   [DIVIDER_WIDTH-1:0]   Remainder output
=========  ===========  ====================  ============================

Example Instantiation
---------------------

.. code-block:: verilog

   smalldiv #(
     .DIVIDER_VALUE(5),
     .DIVIDER_WIDTH($clog2(5)),
     .DIVIDEND_WIDTH(18),
     .THEORETICAL_LUT_WIDTH(6),
     .REGISTER_IN(1),
     .REGISTER_OUT(1)
   ) u_smalldiv (
     .clock(clock),
     .enable(enable),
     .dividend(dividend),
     .quotient(quotient),
     .remainder(remainder)
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
