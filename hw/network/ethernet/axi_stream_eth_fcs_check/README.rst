AXI Stream Ethernet FCS Checker
===============================

Description
-----------

Verifies and strips the Ethernet FCS (CRC-32, IEEE 802.3) of a byte-wide
AXI stream frame, the counterpart of ``axi_stream_eth_fcs_gen`` on the
receive side of ``rmii_mac_rx`` and an upsizer. The frame end is only
known when ``tlast`` arrives, so the stream is delayed by four bytes:
when the last input byte shows up the delay line holds exactly the FCS,
``m_axi_tlast`` lands on the last payload byte, and the received FCS is
compared against the CRC computed over the emitted bytes.

``m_axi_tuser`` raised with ``m_axi_tlast`` marks a frame to drop: the
FCS did not match, or the source flagged the frame with ``s_axi_tuser``
on any beat (which is how ``rmii_mac_rx`` reports its own errors). A
frame of four bytes or fewer has no payload at all and is dropped
silently — nothing is emitted.

Parameters
----------

None.

Signals
-------

- ``clock``, ``sreset``: clock and synchronous reset, active high.
- ``s_axi_*``: AXI stream slave, the frame with its FCS.
- ``m_axi_*``: AXI stream master, the frame without its FCS, ``tuser``
  with ``tlast`` flags a frame to drop.
