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
