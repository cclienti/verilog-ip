Byte Read Select
================

Description
-----------

The ``rdselb`` module selects a byte from a 32-bit input word (``in``) according to the ``sel``
input and extends it to 32 bits. If ``is_signed`` is set, the output is sign-extended; otherwise,
it is zero-extended. This is useful for byte extraction and extension in bus or memory interfaces.

Parameters
----------

None. This module has no parameters.

Signals
-------

==========  ============  ========  =====================================
Name        I/O type      Range     Description
==========  ============  ========  =====================================
is_signed   input wire    1         Sign-extend if set, else zero-extend
sel         input wire    [1:0]     Byte select (0=LSB, 3=MSB)
in          input wire    [31:0]    Input 32-bit word
out         output wire   [31:0]    Extended output
==========  ============  ========  =====================================

Example Instantiation
---------------------

.. code-block:: verilog

   rdselb u_rdselb (
     .is_signed(is_signed),
     .sel(sel),
     .in(in),
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
