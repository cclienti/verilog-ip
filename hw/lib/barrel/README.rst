Barrel Shifter
==============

Description
-----------

The ``barrel`` module is a right barrel shifter that dynamically shifts a word (``in``) by a
specified number of bits (``shift``), with support for dynamic sign extension when ``is_signed`` is
set. The shift amount can range from 0 up to ``SHIFT_MAX + 1``; when ``shift`` equals
``SHIFT_MAX + 1``, the output is set to the value of ``ex``. All inputs can be optionally
registered if ``IS_REG_IN`` is set.

Parameters
----------

============  ====================  ==========================================
Name          Default value         Description
============  ====================  ==========================================
WIDTH         64                    Width of the word to shift
SHIFT_MAX     46                    Maximum right shift
SHIFT_WIDTH   $clog2(SHIFT_MAX+2)   Number of bits to encode the shift command
IS_REG_IN     1                     Register all inputs if IS_REG_IN != 0
============  ====================  ==========================================

Signals
-------

==========  ===========  ==================  ===============================================
Name        I/O type     Range               Description
==========  ===========  ==================  ===============================================
clk         input wire   1                   Clock
enable      input wire   1                   Enable
is_signed   input wire   1                   Sign extend the output if set
shift       input wire   [SHIFT_WIDTH-1:0]   Number of bits to right shift
in          input wire   [WIDTH-1:0]         Input word to right shift
ex          input wire   [WIDTH-1:0]         Special value for out when shift is SHIFT_MAX+1
out         output reg   [WIDTH-1:0]         Shifted output
==========  ===========  ==================  ===============================================

Example Instantiation
---------------------

.. code-block:: verilog

   barrel #(
     .WIDTH(64),
     .SHIFT_MAX(46),
     .SHIFT_WIDTH($clog2(46+2)),
     .IS_REG_IN(1)
   ) u_barrel (
     .clk(clk),
     .enable(enable),
     .is_signed(is_signed),
     .shift(shift),
     .in(in),
     .ex(ex),
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
