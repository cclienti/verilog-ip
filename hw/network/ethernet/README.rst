Fast Ethernet (RMII)
====================

Building blocks for a Fast Ethernet endpoint on an RMII PHY. The MAC
modules work on the native 2-bit RMII stream; the FCS modules work on
bytes, on the far side of the generic AXI stream resizers
(`axi_stream_upsizer <../../lib/axi_stream_upsizer/README.rst>`_,
`axi_stream_downsizer <../../lib/axi_stream_downsizer/README.rst>`_).

A frame is flagged for dropping by ``tuser`` raised together with
``tlast`` on every stream of the chain; on a transmit stream, ``tuser``
on any beat aborts the frame.

The resizers carry one ``tuser`` bit per sub-word while the MAC and FCS
modules use a single bit, so the seams need glue — wiring the ports
directly would silently truncate the error flag to bit 0. On the
transmit side replicate it (``{4{tuser}}`` into the downsizer, whose
``tkeep`` input is tied full since frames are whole bytes); on the
receive side reduce it and fold in an incomplete last byte:
``|m_axi_tuser || (m_axi_tlast && m_axi_tkeep != '1)`` into the checker.
An `axi_stream_packet_fifo <../../lib/axi_stream_packet_fifo/README.rst>`_
in DROP_ON_FULL mode ends the receive chain: frames the checker flags
vanish there, so the protocol layer only ever parses complete valid
frames, with the length delivered on the first beat. The checker
testbench instantiates this exact chain and keeps it working.

+---------------------------------------------------------------------+----------------------------------------------+
| Module                                                              | Description                                  |
+=====================================================================+==============================================+
| `rmii_mac_rx <rmii_mac_rx/README.rst>`_                             | RMII MAC Receiver (2-bit AXI stream)         |
+---------------------------------------------------------------------+----------------------------------------------+
| `rmii_mac_tx <rmii_mac_tx/README.rst>`_                             | RMII MAC Transmitter (2-bit AXI stream)      |
+---------------------------------------------------------------------+----------------------------------------------+
| `axi_stream_eth_fcs_gen <axi_stream_eth_fcs_gen/README.rst>`_       | FCS generator with minimum-frame padding     |
+---------------------------------------------------------------------+----------------------------------------------+
| `axi_stream_eth_fcs_check <axi_stream_eth_fcs_check/README.rst>`_   | FCS checker and stripper                     |
+---------------------------------------------------------------------+----------------------------------------------+
