=====================================
Asynchronous Gray to Binary Converter
=====================================


-----------
Description
-----------

This design is a configurable gray to binary asynchronous converter. This module can be used in a
dual clock FIFO for "safe" transitions between two clock domains.


----------
Parameters
----------

======  =====  ==============  ========================================
Name    Type   Default value   Description
======  =====  ==============  ========================================
WIDTH          4               Input and output word with
======  =====  ==============  ========================================


-------
Signals
-------

=====  ============  ============  ========================================
Name   I/O type      Range         Description
=====  ============  ============  ========================================
gray   input wire    [WIDTH-1:0]   Input gray word
-----  ------------  ------------  ----------------------------------------
bin    output wire   [WIDTH-1:0]   Output binary word
=====  ============  ============  ========================================
