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
Functional Description
----------------------

The `cmplt` module compares two input words (`a`, `b`) and outputs `1` if `a` is strictly less than `b`, otherwise outputs `0`. The comparison is performed as signed if `is_signed` is set, or as unsigned otherwise. This module can be used to implement all standard comparison operations in combination with other comparators and logic.

Example Instantiation
---------------------

.. code-block:: verilog

   cmplt #(
     .WIDTH(32)
   ) u_cmplt (
     .a(a),
     .b(b),
     .is_signed(is_signed),
     .out(out)
   );
