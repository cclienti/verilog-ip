Dual Clock FIFO implemented with FPGA LUT memories
==================================================

-----------
Description
-----------

The `dclkfifolut` module is a dual clock FIFO implemented using FPGA LUT memories, designed for safe
data transfer between asynchronous clock domains. It manages clock domain crossing using Gray code
pointers, following the method described by Clifford E. Cummings (SNUG 2002). All outputs on the
read side are registered with `rclk`, and all outputs on the write side are registered with `wclk`.

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

Example Instantiation
---------------------

.. code-block:: verilog

   dclkfifolut #(
     .LOG2_FIFO_DEPTH(3),
     .FIFO_WIDTH(8)
   ) u_dclkfifolut (
     .rsrst(rsrst),
     .rclk(rclk),
     .ren(ren),
     .rdata(rdata),
     .rlevel(rlevel),
     .rempty(rempty),
     .wsrst(wsrst),
     .wclk(wclk),
     .wen(wen),
     .wdata(wdata),
     .wlevel(wlevel),
     .wfull(wfull)
   );
