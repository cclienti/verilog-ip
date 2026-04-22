============================
Dual Port Write First Memory
============================


-----------
Description
-----------

The design is a dual port memory with two read/write ports. The memory is called "write first": The
read value is the written data (on the same port). By the way, reading on a port and writing on the
other at the same address or writing on both ports at the same address produce an undefined
behavior.

The output memory latency is one or two cycles depending on the parameters used to instanciate the
design (two cycles when OUTREGx is '1' else one cycle).


----------
Parameters
----------


========  =====  ==============  ========================================
Name      Type   Default value   Description
========  =====  ==============  ========================================
DEPTH            10              Number of word: 2^DEPTH
--------  -----  --------------  ----------------------------------------
WIDTH            32              Word width
--------  -----  --------------  ----------------------------------------
OUTREGA          1               Add an extra register on the A port
--------  -----  --------------  ----------------------------------------
OUTREGB          1               Add an extra register on the B port
========  =====  ==============  ========================================


-------
Signals
-------

======  ===========  ============  ========================================
Name    I/O type     Range         Description
======  ===========  ============  ========================================
clka    input wire   1             Port A clock
------  -----------  ------------  ----------------------------------------
ena     input wire   1             Port A enable
------  -----------  ------------  ----------------------------------------
wea     input wire   1             Port A write enable
------  -----------  ------------  ----------------------------------------
addra   input wire   [DEPTH-1:0]   Port A address
------  -----------  ------------  ----------------------------------------
dia     input wire   [WIDTH-1:0]   Port A data input
------  -----------  ------------  ----------------------------------------
doa     output reg   [WIDTH-1:0]   Port A data output
------  -----------  ------------  ----------------------------------------
clkb    input wire   1             Port B clock
------  -----------  ------------  ----------------------------------------
enb     input wire   1             Port B enable
------  -----------  ------------  ----------------------------------------
web     input wire   1             Port B write enable
------  -----------  ------------  ----------------------------------------
addrb   input wire   [DEPTH-1:0]   Port B address
------  -----------  ------------  ----------------------------------------
dib     input wire   [WIDTH-1:0]   Port B data input
------  -----------  ------------  ----------------------------------------
dob     output reg   [WIDTH-1:0]   Port B data output
======  ===========  ============  ========================================
Functional Description
----------------------

The `dpmemwf` module implements a dual-port RAM with two independent read/write ports (A and B). It is a "write first" memory: when a write occurs, the new data is immediately available on the output. Simultaneous access (read/write or write/write) to the same address on both ports results in undefined behavior. The output latency is one or two cycles, depending on the OUTREG parameters.

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
