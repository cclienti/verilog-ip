AXI Stream Ethernet FCS Generator
=================================

Description
-----------

Appends the Ethernet FCS (CRC-32, IEEE 802.3) to a byte-wide AXI stream
frame. The input frame starts at the destination MAC — exactly the CRC
coverage — and frames shorter than ``MIN_FRAME_BYTES`` are zero-padded
first, so with the default of 60 the output meets the 64-byte minimum
frame size once the FCS is counted. The FCS is emitted least significant
byte first, ready for a downsizer and ``rmii_mac_tx``.

A beat with ``s_axi_tuser`` set aborts the frame: from that beat on the
input passes through unchanged (``tuser`` and ``tlast`` included) and no
padding or FCS is appended, so a downstream MAC drains the remains and
the far end can never mistake them for a valid frame.

Backpressure is honored on both sides; during padding and FCS emission
``s_axi_tready`` stays low.

Parameters
----------

- ``MIN_FRAME_BYTES``: frame length before FCS below which zero padding
  is inserted (default 60, the 802.3 minimum; 0 disables padding).

Signals
-------

- ``clock``, ``sreset``: clock and synchronous reset, active high.
- ``s_axi_*``: AXI stream slave, one frame byte per beat, ``tuser``
  aborts the frame.
- ``m_axi_*``: AXI stream master, the frame with padding and FCS.
