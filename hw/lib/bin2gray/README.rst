Asynchronous Binary to Gray Converter
======================================

Description
-----------

The ``bin2gray`` module is a configurable, combinational converter that transforms a binary input
word (``bin``) into its equivalent Gray code (``gray``). This is especially useful for safe signal
transitions between asynchronous clock domains, such as in dual-clock FIFOs.

Parameters
----------

======  ==============  ========================
Name    Default value   Description
======  ==============  ========================
WIDTH   4               Input and output width
======  ==============  ========================

Signals
-------

=====  ===========  ============  =======================
Name   I/O type     Range         Description
=====  ===========  ============  =======================
bin    input wire   [WIDTH-1:0]   Input binary word
gray   output reg   [WIDTH-1:0]   Output Gray code word
=====  ===========  ============  =======================

Example Instantiation
---------------------

.. code-block:: verilog

   bin2gray #(
     .WIDTH(4)
   ) u_bin2gray (
     .bin(bin),
     .gray(gray)
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
