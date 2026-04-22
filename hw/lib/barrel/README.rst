=======================
Barrel Shifter
=======================


-----------
Description
-----------

The design is a barrel shifter that dynamically shifts a word to the right of N bits at a time with
dynamic sign bit extension capabilities. The barrel shifter can shift up to SHIFT_MAX + 2 values,
from 0 to SHIFT_MAX + 1. When setting the shift word to SHIFT_MAX + 1, the "ex" word is copied to
the output.


----------
Parameters
----------

============  =====  ====================  ==========================================
Name          Type   Default value         Description
============  =====  ====================  ==========================================
WIDTH                64                    Width of the work to shift
------------  -----  --------------------  ------------------------------------------
SHIFT_MAX            46                    Maximum right shift
------------  -----  --------------------  ------------------------------------------
SHIFT_WIDTH          $clog2(SHIFT_MAX+2)   Number of bits to encode the shift command
------------  -----  --------------------  ------------------------------------------
IS_REG_IN            1                     Register all inputs if IS_REG_IN != 0
============  =====  ====================  ==========================================


-------
Signals
-------

==========  ===========  ==================  ===============================================
Name        I/O type     Range               Description
==========  ===========  ==================  ===============================================
clk         input wire   1                   Clock
----------  -----------  ------------------  -----------------------------------------------
enable      input wire   1                   Enable
----------  -----------  ------------------  -----------------------------------------------
is_signed   input wire   1                   sign extent the output if set
----------  -----------  ------------------  -----------------------------------------------
shift       input wire   [SHIFT_WIDTH-1:0]   Number of bit to right shift.
----------  -----------  ------------------  -----------------------------------------------
in          input wire   [WIDTH-1:0]         Input word to right shift
----------  -----------  ------------------  -----------------------------------------------
ex          input wire   [WIDTH-1:0]         Special value for out when shift is SHIFT_MAX+1
----------  -----------  ------------------  -----------------------------------------------
out         output reg   [WIDTH-1:0]         Shifted output
==========  ===========  ==================  ===============================================
Functional Description
----------------------

The `barrel` module implements a right barrel shifter with dynamic shift amount and optional sign extension. When `is_signed` is set, the output is sign-extended. If the `shift` input equals `SHIFT_MAX+1`, the output is set to the value of `ex`. All inputs can be optionally registered if `IS_REG_IN` is set.

Example Instantiation
---------------------

.. code-block:: verilog

   barrel #(
     .WIDTH(64),
     .SHIFT_MAX(46),
     .SHIFT_WIDTH($clog2(46+2)),
     .IS_REG_IN(1)
   ) u_barrel (
     .clk(clk),
     .enable(enable),
     .is_signed(is_signed),
     .shift(shift),
     .in(in),
     .ex(ex),
     .out(out)
   );
