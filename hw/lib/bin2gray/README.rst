=====================================
Asynchronous Binary to Gray Converter
=====================================


-----------
Description
-----------

This design is a configurable binary to gray asynchronous converter. This module can be used in dual
clock fifo for "safe" transitions between two clock domains.


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

=====  ===========  ============  ========================================
Name   I/O type     Range         Description
=====  ===========  ============  ========================================
bin    input wire   [WIDTH-1:0]   Input binary word
-----  -----------  ------------  ----------------------------------------
gray   output reg   [WIDTH-1:0]   Output binary word
=====  ===========  ============  ========================================
