Multiport Shared Memory Interface
===================================

Description
-----------

The ``shmemif`` module implements a multiport shared memory interface with dynamic round-robin
arbitration. Each port can independently request access, and the arbiter grants access to the shared
memory in a fair, rotating order. The interface is parameterizable for number of ports, address
width, data width, and output register option.

Parameters
----------

=====================  ==============  ===========================================
Name                   Default value   Description
=====================  ==============  ===========================================
NB_PORTS               4               Number of ports
LOG2_NB_PORTS          2               Log2 of number of ports
ADDR_WIDTH             12              Address width
DATA_WIDTH             32              Data width
REGISTER_MEM_OUTPUT    1               Register memory outputs if set
=====================  ==============  ===========================================

Signals
-------

=================  ============  ==============================  ============================
Name               I/O type      Range                           Description
=================  ============  ==============================  ============================
clk                input wire    1                               Clock
srst               input wire    1                               Synchronous reset
shmem_request      input wire    [NB_PORTS-1:0]                  Port request signals
shmem_wren         input wire    [NB_PORTS-1:0]                  Port write enables
shmem_addr         input wire    [NB_PORTS*ADDR_WIDTH-1:0]       Port addresses
shmem_datain       input wire    [NB_PORTS*DATA_WIDTH-1:0]       Port data inputs
shmem_dataout      output wire   [NB_PORTS*DATA_WIDTH-1:0]       Port data outputs
shmem_done         output reg    [NB_PORTS-1:0]                  Port done signals
mem_wren           output reg    1                               Memory write enable
mem_addr           output reg    [ADDR_WIDTH-1:0]                Memory address
mem_datain         output reg    [DATA_WIDTH-1:0]                Memory data input
mem_dataout        input wire    [DATA_WIDTH-1:0]                Memory data output
=================  ============  ==============================  ============================

Example Instantiation
---------------------

.. code-block:: verilog

   shmemif #(
     .NB_PORTS(4),
     .LOG2_NB_PORTS(2),
     .ADDR_WIDTH(12),
     .DATA_WIDTH(32),
     .REGISTER_MEM_OUTPUT(1)
   ) u_shmemif (
     .clk(clk),
     .srst(srst),
     .shmem_request(shmem_request),
     .shmem_wren(shmem_wren),
     .shmem_addr(shmem_addr),
     .shmem_datain(shmem_datain),
     .shmem_dataout(shmem_dataout),
     .shmem_done(shmem_done),
     .mem_wren(mem_wren),
     .mem_addr(mem_addr),
     .mem_datain(mem_datain),
     .mem_dataout(mem_dataout)
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
