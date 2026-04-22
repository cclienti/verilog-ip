==================================
Asynchronous Read Dual Port Memory
==================================


-----------
Description
-----------

The design is an asynchronous read memory with a read port and a write port simultaneously
addressable. Such design is usually synthesized with FPGA tools as a LUT memory.


----------
Parameters
----------


======  =====  ==============  ========================================
Name    Type   Default value   Description
======  =====  ==============  ========================================
DEPTH          6               Memory depth, 2**DEPTH words
------  -----  --------------  ----------------------------------------
WIDTH          32              Memory word width
======  =====  ==============  ========================================


-------
Signals
-------

======  ============  ============  ========================================
Name    I/O type      Range         Description
======  ============  ============  ========================================
clka    input wire    1             Write port clock
------  ------------  ------------  ----------------------------------------
ena     input wire    1             Write port enable
------  ------------  ------------  ----------------------------------------
wea     input wire    1             Write port write enable
------  ------------  ------------  ----------------------------------------
addra   input wire    [DEPTH-1:0]   Write word address
------  ------------  ------------  ----------------------------------------
dia     input wire    [WIDTH-1:0]   Write word
------  ------------  ------------  ----------------------------------------
addrb   input wire    [DEPTH-1:0]   Read word address
------  ------------  ------------  ----------------------------------------
dob     output wire   [WIDTH-1:0]   Read word
======  ============  ============  ========================================
Functional Description
----------------------

The `asdpmem` module implements a simple dual-port RAM with a synchronous write port and an asynchronous read port. The write operation occurs on the rising edge of `clka` when both `ena` and `wea` are asserted. The read operation is asynchronous and provides the data at `dob` corresponding to the address `addrb`. This design is typically synthesized as a LUT-based memory in FPGAs.

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
