PWM Generator
=============

The ``pwm_generator`` module implements a parameterizable PWM (Pulse Width Modulation) signal
generator. The PWM period and duty cycle are controlled at runtime via ``pwm_max`` and
``pwm_high_max`` inputs, making it suitable for motor speed control and other FPGA-based
applications.

The module uses an internal counter that increments each clock cycle. The PWM output is set high
when the counter resets to zero and is cleared when the counter reaches ``pwm_high_max``. The period
is determined by ``pwm_max``.

Parameters
----------

===========  ==============  ===========================
Name         Default value   Description
===========  ==============  ===========================
PWM_WIDTH    32              Width of the PWM counters
===========  ==============  ===========================

Signals
-------

==============  ===========  ==================  =====================================================
Name            I/O type     Range               Description
==============  ===========  ==================  =====================================================
clock           input wire   1                   System clock
srst            input wire   1                   Synchronous reset, active high
pwm_high_max    input wire   [PWM_WIDTH-1:0]     Counter value at which PWM output goes low
pwm_max         input wire   [PWM_WIDTH-1:0]     Counter value at which PWM period resets
pwm_output      output reg   1                   PWM output signal
==============  ===========  ==================  =====================================================

The PWM duty cycle is: ``duty = pwm_high_max / pwm_max``.
The PWM frequency is: ``f_pwm = f_clk / (pwm_max + 1)``.

Example Instantiation
---------------------

.. code-block:: verilog

   pwm_generator #(
     .PWM_WIDTH(32)
   ) u_pwm_generator (
     .clock(clock),
     .srst(srst),
     .pwm_high_max(pwm_high_max),
     .pwm_max(pwm_max),
     .pwm_output(pwm_output)
   );

Simulation
----------

.. code-block:: bash

   cd project
   make sim    # Icarus Verilog simulation
   make trace  # Simulate and open GTKWave
