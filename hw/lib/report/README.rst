Info/Warning/Error Report Module
==================================

Description
-----------

The ``report`` module provides standardized reporting of information, warnings, and errors during
simulation. The time unit for messages can be configured via the ``UNIT`` parameter. This module is
intended for use in testbenches and simulation environments to standardize and simplify reporting.

Parameters
----------

==================  ==============  ===========================================
Name                Default value   Description
==================  ==============  ===========================================
UNIT                "us"            Time unit string for formatting messages
MAX_STRING_LENGTH   1024            Maximum length for report strings
==================  ==============  ===========================================

Signals
-------

None. This module exposes no ports; it is used via Verilog task calls in simulation.

Example Instantiation
---------------------

.. code-block:: verilog

   report #(
     .UNIT("us"),
     .MAX_STRING_LENGTH(1024)
   ) u_report ();

License
-------

This module is licensed under the **CERN Open Hardware Licence Version 2 - Permissive (CERN-OHL-P-2.0)**.
See `LICENSE <../../LICENSE>`_ for details.
