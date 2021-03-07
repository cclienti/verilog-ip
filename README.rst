=============================
Generic Verilog IP Repository
=============================


Introduction
============

Sources
=======


::

   git clone https://github.com/cclienti/verilog-ip.git
   cd verilog-ip.git


Simulation
==========


Preparing
---------

First install the prerequisites to simulate and lint the designs. Depending on your linux
distribution, the command can change.

RPM based linux distributions:

::

   sudo dnf install iverilog verilator gtkwave make

APT based linux distributions:

::

   sudo apt update
   sudo apt install iverilog verilator gtkwave make

A python package is used to properly import signals to monitor in the Gtkwave VCD viewer. The
package can be easily retrieved using the python pip command.

::

   python3 -m venv venv  # the venv directory is added in the .gitignore
   source venv/bin/activate
   python -m pip install --upgrade pip
   pip install wheel
   pip install wavedisp
   pip install sphinx


Testing
-------

In order to test your environment, you can go in a project directory and execute the command make
trace.

::

   cd hw/motor_control/pwm_generator/project
   make trace
