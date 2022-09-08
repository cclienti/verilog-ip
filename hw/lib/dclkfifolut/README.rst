==================================================
Dual Clock FIFO implemented with FPGA LUT memories
==================================================


-----------
Description
-----------

The design is a dual clock FIFO implemented using FPGA LUT memories. The design manages the clock
domain crossing using gray codes as depicted here: Simulation and Synthesis Techniques for
Asynchronous FIFO Design, Clifford E. Cummings, SNUG 2002

All output signal of the read side are registered using the rclk clock and all output signals of the
write port are registered using the wclk clock.


----------
Parameters
----------

================  =====  ==============  ========================================
Name              Type   Default value   Description
================  =====  ==============  ========================================
LOG2_FIFO_DEPTH          3               Depth of the FIFO: 2^LOG2_FIFO_DEPTH
----------------  -----  --------------  ----------------------------------------
FIFO_WIDTH               8               FIFO
================  =====  ==============  ========================================


-------
Signals
-------

=======  ===========  ====================  ========================================
Name     I/O type     Range                 Description
=======  ===========  ====================  ========================================
rsrst    input wire   1                     Read port synchronous reset
-------  -----------  --------------------  ----------------------------------------
rclk     input wire   1                     Read port clock
-------  -----------  --------------------  ----------------------------------------
ren      input wire   1                     Read port enable
-------  -----------  --------------------  ----------------------------------------
rdata    output reg   [FIFO_WIDTH-1:0]      Read port output data
-------  -----------  --------------------  ----------------------------------------
rlevel   output reg   [LOG2_FIFO_DEPTH:0]   Read port number of words in the FIFO
-------  -----------  --------------------  ----------------------------------------
rempty   output reg   1                     Read port empty
-------  -----------  --------------------  ----------------------------------------
wsrst    input wire   1                     Write port synchronous reset
-------  -----------  --------------------  ----------------------------------------
wclk     input wire   1                     Write port clock
-------  -----------  --------------------  ----------------------------------------
wen      input wire   1                     Write port enable
-------  -----------  --------------------  ----------------------------------------
wdata    input wire   [FIFO_WIDTH-1:0]      Write port input data
-------  -----------  --------------------  ----------------------------------------
wlevel   output reg   [LOG2_FIFO_DEPTH:0]   Write port number of words in the FIFO
-------  -----------  --------------------  ----------------------------------------
wfull    output reg   1                     Write port full signal
=======  ===========  ====================  ========================================
