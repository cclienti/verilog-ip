Adder/Subtractor with Carry In/Out
==================================

Description
-----------

The ``adderc`` module is an adder/subtractor with input and output carries, supporting both addition
and subtraction of two inputs (``a``, ``b``) with an optional carry-in (``cin``). The operation is
selected by the ``sub_nadd`` signal (0 = add, 1 = subtract). Output and carry can be optionally
registered on the rising edge of ``clk`` if ``IS_REG_OUT`` is set, with support for synchronous
reset (``srst``) and register enable (``enable``). The design can be easily chained using the input
and output carries to create larger adders, and can also be used for SWAR (SIMD Within A Register)
operations (e.g., 8x8bits, 4x16bits, 2x32bits, 1x64bits).

Parameters
----------

===========  ==============  =============================================
Name         Default value   Description
===========  ==============  =============================================
IS_REG_OUT   1               Add an output register (if different of zero)
WIDTH        32              Adder/Subtractor Width (carries not included)
===========  ==============  =============================================

Signals
-------

=========  ===========  ============  ========================================================
Name       I/O type     Range         Description
=========  ===========  ============  ========================================================
clk        input wire   1             Clock
srst       input wire   1             Synchronous reset
enable     input wire   1             Register Enable (if IS_REG_OUT != 0)
sub_nadd   input wire   1             Subtract (1) or Add (0)
cin        input wire   1             Input carry
a          input wire   [WIDTH-1:0]   Adder/Subtractor A input
b          input wire   [WIDTH-1:0]   Adder/Subtractor B input
out        output reg   [WIDTH-1:0]   Adder/Subtractor output (registered if IS_REG_OUT != 0)
cout       output reg   1             Output carry (registered if IS_REG_OUT != 0)
=========  ===========  ============  ========================================================

Example Instantiation
---------------------

.. code-block:: verilog

   adderc #(
     .IS_REG_OUT(1),
     .WIDTH(32)
   ) u_adderc (
     .clk(clk),
     .srst(srst),
     .enable(enable),
     .sub_nadd(sub_nadd),
     .cin(cin),
     .a(a),
     .b(b),
     .out(out),
     .cout(cout)
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
