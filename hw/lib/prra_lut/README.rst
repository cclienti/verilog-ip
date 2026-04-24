Parallel Round-Robin Arbiter Lookup Table
==========================================

Description
-----------

The ``prra_lut`` module implements a lookup table for round-robin arbitration, allowing a full state
machine where each state can transition to any other state based on priorities to avoid starvation.
It outputs the next state (granted requester) given a set of requests, following round-robin
priority. This module is a core component in parallel round-robin arbiters (``prra``) and static
shared memory interfaces (``shmemif``), supporting both request-grant and request-done round robin
systems. The number of requesters and the state offset are configurable via parameters.

Parameters
----------

=============  ==============  ========================================
Name           Default value   Description
=============  ==============  ========================================
WIDTH          4               Number of requesters
LOG2_WIDTH     $clog2(WIDTH)   Ceil log2 of number of requesters
STATE_OFFSET   0               Offset to build state indexes in the LUT
=============  ==============  ========================================

Signals
-------

========  ===========  =================  ========================================
Name      I/O type     Range              Description
========  ===========  =================  ========================================
request   input wire   [WIDTH-1:0]        Request inputs
state     output reg   [LOG2_WIDTH-1:0]   State output (granted requester index)
========  ===========  =================  ========================================

Example Instantiation
---------------------

.. code-block:: verilog

   prra_lut #(
     .WIDTH(4),
     .LOG2_WIDTH($clog2(4)),
     .STATE_OFFSET(0)
   ) u_prra_lut (
     .request(request),
     .state(state)
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
