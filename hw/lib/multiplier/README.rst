Signed/Unsigned Multiplier
===========================

Description
-----------

The ``multiplier`` module multiplies two input words (``a``, ``b``) as signed or unsigned values,
depending on the ``is_signed`` signal. It supports parameterizable input widths (``WIDTH_A``,
``WIDTH_B``) and pipelining, with the number of pipeline registers set by ``NB_EXTRA_REG``. The
output width is the sum of the input widths.

Parameters
----------

=============  ==============  ===========================================
Name           Default value   Description
=============  ==============  ===========================================
WIDTH_A        32              Width of input ``a``
WIDTH_B        32              Width of input ``b``
NB_EXTRA_REG   4               Number of extra pipeline registers
=============  ==============  ===========================================

Signals
-------

==========  ===========  ======================  ============================
Name        I/O type     Range                   Description
==========  ===========  ======================  ============================
clk         input wire   1                       Clock
enable      input wire   1                       Register enable
is_signed   input wire   1                       Signed (1) or unsigned (0)
a           input wire   [WIDTH_A-1:0]           Multiplicand
b           input wire   [WIDTH_B-1:0]           Multiplier
out         output wire  [WIDTH_A+WIDTH_B-1:0]   Product output
==========  ===========  ======================  ============================

Example Instantiation
---------------------

.. code-block:: verilog

   multiplier #(
     .WIDTH_A(32),
     .WIDTH_B(32),
     .NB_EXTRA_REG(4)
   ) u_multiplier (
     .clk(clk),
     .enable(enable),
     .is_signed(is_signed),
     .a(a),
     .b(b),
     .out(out)
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
