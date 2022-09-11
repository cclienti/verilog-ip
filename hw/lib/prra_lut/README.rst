Parallel Round-Robin Arbiter Lookup Table
=========================================


Description
-----------

The design allows to describe a full state machine where each state can go to all states considering a
priorities to avoid starvation.

The architecture is the main component for the Parallel Round Robin design (PRRA) and the Static
Shared Memory Interface (SHMEM). On the one side, the PRRA uses the LUT to create a request-grant
round robin system where the grant signal is kept while the request is set. On the other side the
SHMEM uses the LUT as a request-done round robin system where all the requesters are interleaved.


Parameters
----------

=============  =====  ==============  ========================================
Name           Type   Default value   Description
=============  =====  ==============  ========================================
WIDTH                 4               Number of requester
-------------  -----  --------------  ----------------------------------------
LOG2_WIDTH            $clog2(WIDTH)   Ceil Log2 number of requester
-------------  -----  --------------  ----------------------------------------
STATE_OFFSET          0               Offset to build state indexes in the LUT
=============  =====  ==============  ========================================


Signals
-------

========  ===========  =================  ========================================
Name      I/O type     Range              Description
========  ===========  =================  ========================================
request   input wire   [WIDTH-1:0]        Requests LUT input
--------  -----------  -----------------  ----------------------------------------
state     output reg   [LOG2_WIDTH-1:0]   State output
========  ===========  =================  ========================================
