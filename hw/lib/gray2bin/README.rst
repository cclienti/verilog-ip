Asynchronous Gray to Binary Converter
======================================

Description
-----------

The ``gray2bin`` module is a configurable, combinational converter that transforms a Gray code input
word (``gray``) into its equivalent binary value (``bin``). This is especially useful for safe
signal transitions between asynchronous clock domains, such as in dual-clock FIFOs.

Parameters
----------

======  ==============  ========================
Name    Default value   Description
======  ==============  ========================
WIDTH   4               Input and output width
======  ==============  ========================

Signals
-------

=====  ============  ============  =======================
Name   I/O type      Range         Description
=====  ============  ============  =======================
gray   input wire    [WIDTH-1:0]   Input Gray code word
bin    output wire   [WIDTH-1:0]   Output binary word
=====  ============  ============  =======================

Example Instantiation
---------------------

.. code-block:: verilog

   gray2bin #(
     .WIDTH(4)
   ) u_gray2bin (
     .gray(gray),
     .bin(bin)
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
