Miscellaneous Utilities
=======================

Description
-----------

This directory contains utility Verilog code for use in simulation and other modules. It provides
math helper functions and a simulation assertion module.

math.v
------

Provides various math-related constant functions for use at elaboration time in Verilog code.

**Example:**

.. code-block:: verilog

   function integer log2;
      input integer value;
      begin
         value = value-1;
         for (log2=0; value>0; log2=log2+1) begin
            value = value>>1;
         end
      end
   endfunction

myassert.v
----------

Implements an assertion module for simulation-time checking. On each rising edge of ``clk``, if
``test`` is not ``1``, the module prints an assertion failure message and stops the simulation.

Parameters
----------

========  ==============  =====================================
Name      Default value   Description
========  ==============  =====================================
MYSTRING  "UNKNOWN"       Message string for assertion failure
========  ==============  =====================================

Signals
-------

======  ===========  =====  ==============================
Name    I/O type     Range  Description
======  ===========  =====  ==============================
clk     input wire   1      Clock
test    input wire   1      Assertion condition (must be 1)
======  ===========  =====  ==============================

Example Instantiation
---------------------

.. code-block:: verilog

   myassert #(
     .MYSTRING("Check input valid")
   ) u_myassert (
     .clk(clk),
     .test(input_valid)
   );

License
-------

This module is licensed under the **CERN Open Hardware Licence Version 2 - Permissive (CERN-OHL-P-2.0)**.
See `LICENSE <../../LICENSE>`_ for details.
