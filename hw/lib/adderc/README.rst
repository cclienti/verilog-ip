====================================
Adder/Subtractor with Carry In/Out
====================================


-----------
Description
-----------

The design is an adder/subtractor with input and output carries. Adder/subtractor output and output
carry can be registered.

The adder/subtractor can be statically easily chained to create a larger adder using the input and
output carries. Such technique can also be used to dynamically used to create SWAR (SIMD Within A
Register) adder/subtractor (8x8bits, 4x16bits, 2x32bits, 1x64bits).


----------
Parameters
----------

===========  =====  ==============  =============================================
Name         Type   Default value   Description
===========  =====  ==============  =============================================
IS_REG_OUT          1               Add an output register (if different of zero)
-----------  -----  --------------  ---------------------------------------------
WIDTH               32              Adder/Subtractor Width (carries not included)
===========  =====  ==============  =============================================


-------
Signals
-------

=========  ===========  ============  ========================================================
Name       I/O type     Range         Description
=========  ===========  ============  ========================================================
clk        input wire   1             Clock
---------  -----------  ------------  --------------------------------------------------------
srst       input wire   1             Synchronous reset
---------  -----------  ------------  --------------------------------------------------------
enable     input wire   1             Register Enable (if IS_REG_OUT != 0)
---------  -----------  ------------  --------------------------------------------------------
sub_nadd   input wire   1             Subtract (1) or Add (0)
---------  -----------  ------------  --------------------------------------------------------
cin        input wire   1             Input carry
---------  -----------  ------------  --------------------------------------------------------
a          input wire   [WIDTH-1:0]   Adder/Subtractor A input
---------  -----------  ------------  --------------------------------------------------------
b          input wire   [WIDTH-1:0]   Adder/Subtractor B input
---------  -----------  ------------  --------------------------------------------------------
out        output reg   [WIDTH-1:0]   Adder/Subtractor output (registered if IS_REG_OUT != 0)
---------  -----------  ------------  --------------------------------------------------------
cout       output reg   1             Output carry (registered if IS_REG_OUT != 0)
=========  ===========  ============  ========================================================
