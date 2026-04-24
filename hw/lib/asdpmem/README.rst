Asynchronous Read Dual Port Memory
===================================

Description
-----------

The ``asdpmem`` module implements a simple dual-port RAM with a synchronous write port and an
asynchronous read port. The write operation occurs on the rising edge of ``clka`` when both ``ena``
and ``wea`` are asserted, while the read operation is asynchronous and provides the data at ``dob``
corresponding to the address ``addrb``. This design is typically synthesized as a LUT-based memory
in FPGAs and allows simultaneous access to the read and write ports.

Parameters
----------

======  ==============  ========================================
Name    Default value   Description
======  ==============  ========================================
DEPTH   6               Memory depth, 2**DEPTH words
WIDTH   32              Memory word width
======  ==============  ========================================

Signals
-------

======  ============  ============  ========================================
Name    I/O type      Range         Description
======  ============  ============  ========================================
clka    input wire    1             Write port clock
ena     input wire    1             Write port enable
wea     input wire    1             Write port write enable
addra   input wire    [DEPTH-1:0]   Write word address
dia     input wire    [WIDTH-1:0]   Write word
addrb   input wire    [DEPTH-1:0]   Read word address
dob     output wire   [WIDTH-1:0]   Read word
======  ============  ============  ========================================

Example Instantiation
---------------------

.. code-block:: verilog

   asdpmem #(
     .DEPTH(6),
     .WIDTH(32)
   ) u_asdpmem (
     .clka(clka),
     .ena(ena),
     .wea(wea),
     .addra(addra),
     .dia(dia),
     .addrb(addrb),
     .dob(dob)
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
