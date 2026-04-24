Asynchronous Signed/Unsigned Less Than Comparator
==================================================

Description
-----------

The ``cmplt`` module is a dynamically signed or unsigned "strictly less than" comparator. It
compares two input words (``a``, ``b``) and outputs ``1`` if ``a`` is strictly less than ``b``,
otherwise outputs ``0``. The comparison is performed as signed if ``is_signed`` is set, or as
unsigned otherwise. By complementing the output, it can function as a "greater or equal" comparator.
Combined with other comparators and simple logic, it enables implementation of all standard
comparison operations (<, <=, ==, >=, >, !=).

Parameters
----------

======  ==============  ====================
Name    Default value   Description
======  ==============  ====================
WIDTH   32              Input words width
======  ==============  ====================

Signals
-------

==========  ============  ============  ========================================
Name        I/O type      Range         Description
==========  ============  ============  ========================================
a           input wire    [WIDTH-1:0]   Input word A
b           input wire    [WIDTH-1:0]   Input word B
is_signed   input wire    1             Signed (1) or unsigned (0) comparison
out         output wire   1             Set if a < b, else reset
==========  ============  ============  ========================================

Example Instantiation
---------------------

.. code-block:: verilog

   cmplt #(
     .WIDTH(32)
   ) u_cmplt (
     .a(a),
     .b(b),
     .is_signed(is_signed),
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
