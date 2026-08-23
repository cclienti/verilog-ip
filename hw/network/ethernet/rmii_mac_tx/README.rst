Fast Ethernet RMII MAC Transmitter
==================================

Description
-----------

Counterpart of ``rmii_mac_rx``. The module reads an Ethernet frame from a
2-bit AXI stream (one RMII dibit per beat, low bits of each byte first) and
drives the PHY: it generates the preamble and SFD, streams the payload on
``txd``/``txen``, and enforces the 96 bit-time inter-frame gap by holding
``axi_tready`` low between frames. The stream carries the frame as it must
appear on the wire, FCS included — nothing here computes the CRC.

The line cannot pause, so the source must sustain one beat per clock from
the first accepted beat to ``axi_tlast`` (buffer the frame upstream before
asserting ``axi_tvalid``). On an underflow the frame is truncated on the
wire and the rest of it is consumed and discarded. ``axi_tuser`` asserted
on a beat aborts the frame the same way: the beat is not transmitted and
the remainder is discarded up to ``axi_tlast``. Either way the receiving
side drops the truncated frame on its FCS check.

Parameters
----------

None. Preamble length (32 dibits) and inter-frame gap (48 clocks) are
fixed by the standard for 100BASE-TX.

Signals
-------

- ``clock``: 50 MHz RMII reference clock.
- ``srst``: synchronous reset, active high.
- ``axi_tvalid``, ``axi_tlast``, ``axi_tdata[1:0]``, ``axi_tuser``,
  ``axi_tready``: AXI stream slave carrying the frame dibits;
  ``axi_tuser`` aborts the frame.
- ``txd[1:0]``, ``txen``: RMII transmit interface, registered outputs.
