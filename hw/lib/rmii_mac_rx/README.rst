Fast Ethernet RMII MAC Receiver
===============================

Description
-----------

Implements a Fast Ethernet RMII MAC receiver. Receives data from the PHY (2-bit RMII interface) and outputs Ethernet frames as AXI stream data. The preamble and SFD are stripped; only the payload is sent to the AXI stream. Handles frame boundaries and error signaling.

Parameters
----------

None.

Signals
-------

================  ===========  ==========  ===========================================
Name              Direction    Width       Description
================  ===========  ==========  ===========================================
clock             input        1           Clock signal, 50 MHz
srst              input        1           Synchronous reset, active high
rxd               input        [1:0]       Data from PHY (RMII)
rxen              input        1           PHY is sending data
axi_tvalid        output       1           AXI stream data valid
axi_tlast         output       1           Last data in the frame
axi_tdata         output       [1:0]       AXI stream data
axi_tuser         output       1           Indicates error in the frame
axi_tready        input        1           AXI stream ready to accept data
================  ===========  ==========  ===========================================

Functional Description
----------------------

The `rmii_mac_rx` module receives data from a Fast Ethernet PHY using the RMII interface and outputs Ethernet frames as AXI stream data. The preamble and SFD are not sent to the AXI stream, only the payload. Frame boundaries and errors are signaled using the AXI stream sideband signals.

Example Instantiation
---------------------

.. code-block:: verilog

   rmii_mac_rx u_rmii_mac_rx (
     .clock(clock),
     .srst(srst),
     .rxd(rxd),
     .rxen(rxen),
     .axi_tvalid(axi_tvalid),
     .axi_tlast(axi_tlast),
     .axi_tdata(axi_tdata),
     .axi_tuser(axi_tuser),
     .axi_tready(axi_tready)
   );
