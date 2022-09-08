=================================================
Asynchronous Signed/Unsigned Less Than Comparator
=================================================


-----------
Description
-----------

The design is a dynamically signed or unsigned "strictly less than" comparator. By complementing
the output, the comparator works as a "greater or equal" comparator.

Using this comparator with the "strictly greater than" comparator and some simple logic functions, it
is possible to describe all possible standard comparisons (<,<=,==,>=,>,!=).

----------
Parameters
----------

======  =====  ==============  ========================================
Name    Type   Default value   Description
======  =====  ==============  ========================================
WIDTH          32              Input words width
======  =====  ==============  ========================================


-------
Signals
-------

==========  ============  ============  ========================================
Name        I/O type      Range         Description
==========  ============  ============  ========================================
a           input wire    [WIDTH-1:0]   input word
----------  ------------  ------------  ----------------------------------------
b           input wire    [WIDTH-1:0]   input word
----------  ------------  ------------  ----------------------------------------
is_signed   input wire    1             signed if set else unsigned comparison
----------  ------------  ------------  ----------------------------------------
out         output wire   1             set if a<b, else reset
==========  ============  ============  ========================================
