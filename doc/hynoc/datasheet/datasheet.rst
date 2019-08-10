Description
===========

**HyNoC** (Hyper-performance NoC) is a Network-On-a-Chip dedicated to High Performance Computing with static and dynamic
routing capabilities. It can manage any topologies by assembling routers with a variable number of ports and each router
implements distributed arbitration schemes within each port.

This work was originally based on Hermes [MOR2004]_ NoC, but many changes are proposed to drastically reduce area and
increase performance to mainly target the FPGA domain and the High Performance Computing. If the reader needs some
information related to NoC classification, the [AGA2009]_ survey will be a relevant start point.

The HyNoC router is built upon following characteristics:

  - Wormhole switching
  - Buffered (FIFO) flow control
  - Distributed arbitration
  - Fully parallel round robin in each distributed arbiter
  - Dedicated clock domain to each port
