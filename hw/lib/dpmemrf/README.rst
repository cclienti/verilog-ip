===========================
Dual Port Read First Memory
===========================


-----------
Description
-----------

The design is a dual port memory with two read/write ports. The memory is called "read first": it
reads before overwriting the data on the same port or on different ports. Writing on both ports at
the same address produce an undefined behavior.

The output memory latency is one or two cycles depending on the parameters used to instanciate the
design.


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
