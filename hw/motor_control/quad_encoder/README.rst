Quadrature Encoder Interface
============================

The ``quad_encoder`` module decodes position and direction from a quadrature rotary encoder (A/B
signals). It includes a configurable input sampling stage and a digital filter to debounce and
stabilize the A and B channel inputs before decoding.

The module samples the A/B inputs at a rate controlled by the ``sampling`` input. Each input is
filtered using a shift register of depth ``NUM_SAMPLER_FILTER`` to eliminate glitches. A pulse is
generated on each valid encoder transition, and the direction output indicates the rotation
direction.

Parameters
----------

======================  ==============  =====================================================
Name                    Default value   Description
======================  ==============  =====================================================
SAMPLING_WIDTH          16              Width of the sampling counter
NUM_SAMPLER_FILTER      5               Number of filter stages for A/B input debouncing
======================  ==============  =====================================================

Signals
-------

==============  ===========  ======================  =====================================================
Name            I/O type     Range                   Description
==============  ===========  ======================  =====================================================
clock           input wire   1                       System clock
srst            input wire   1                       Synchronous reset, active high
sampling        input wire   [SAMPLING_WIDTH-1:0]    Sampling period (in clock cycles)
channel_a       input wire   1                       Encoder channel A input
channel_b       input wire   1                       Encoder channel B input
direction       output reg   1                       Rotation direction (1=forward, 0=backward)
pulse           output reg   1                       One-cycle pulse per valid encoder transition
==============  ===========  ======================  =====================================================

Example Instantiation
---------------------

.. code-block:: verilog

   quad_encoder #(
     .SAMPLING_WIDTH(16),
     .NUM_SAMPLER_FILTER(5)
   ) u_quad_encoder (
     .clock(clock),
     .srst(srst),
     .sampling(sampling),
     .channel_a(channel_a),
     .channel_b(channel_b),
     .direction(direction),
     .pulse(pulse)
   );

Simulation
----------

.. code-block:: bash

   cd project
   make sim    # Icarus Verilog simulation
   make trace  # Simulate and open GTKWave
