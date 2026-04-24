Dual Port Write First Memory
=============================

Description
-----------

The ``dpmemwf`` module is a dual-port RAM with two independent read/write ports (A and B),
implementing a "write first" memory behavior: when a write occurs, the new data is immediately
available on the output of the same port. Simultaneous access (read/write or write/write) to the
same address on both ports results in undefined behavior. The output latency is one or two cycles,
depending on the ``OUTREG`` parameters.

Parameters
----------

========  ==============  ========================================
Name      Default value   Description
========  ==============  ========================================
DEPTH     10              Number of words: 2^DEPTH
WIDTH     32              Word width
OUTREGA   1               Add an extra register on the A port
OUTREGB   1               Add an extra register on the B port
========  ==============  ========================================

Signals
-------

======  ===========  ============  ========================================
Name    I/O type     Range         Description
======  ===========  ============  ========================================
clka    input wire   1             Port A clock
ena     input wire   1             Port A enable
wea     input wire   1             Port A write enable
addra   input wire   [DEPTH-1:0]   Port A address
dia     input wire   [WIDTH-1:0]   Port A data input
doa     output reg   [WIDTH-1:0]   Port A data output
clkb    input wire   1             Port B clock
enb     input wire   1             Port B enable
web     input wire   1             Port B write enable
addrb   input wire   [DEPTH-1:0]   Port B address
dib     input wire   [WIDTH-1:0]   Port B data input
dob     output reg   [WIDTH-1:0]   Port B data output
======  ===========  ============  ========================================

Example Instantiation
---------------------

.. code-block:: verilog

   dpmemwf #(
     .DEPTH(10),
     .WIDTH(32),
     .OUTREGA(1),
     .OUTREGB(1)
   ) u_dpmemwf (
     .clka(clka),
     .ena(ena),
     .wea(wea),
     .addra(addra),
     .dia(dia),
     .doa(doa),
     .clkb(clkb),
     .enb(enb),
     .web(web),
     .addrb(addrb),
     .dib(dib),
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
