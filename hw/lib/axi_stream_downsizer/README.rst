AXI Stream Downsizer
====================

Description
-----------

This module downsizes the data and user signals of an AXI Stream interface by a specified ratio: one
wide input beat is emitted as up to DOWNSIZE_RATIO narrow output beats, low sub-word first. It is the
counterpart of the AXI Stream Upsizer, and a stream that goes through the upsizer then the downsizer
comes out unchanged.

The input tkeep signal marks the valid sub-words of a beat; its set bits are assumed contiguous from
bit 0, as the upsizer produces them: the sub-words above the first cleared bit are skipped and must
not carry data. The input beat is acknowledged
on the transfer of its last kept sub-word, which is also where a tlast input beat raises the output
tlast.

The module holds no data: because an AXI source keeps its beat stable until it is acknowledged, the
narrow beats are muxed combinationally from the wide input, and only the sub-word counter is
registered.

The module is fully synchronous and includes a reset signal for initialization.


Interface
---------

Parameters
~~~~~~~~~~

===============  ===============  ===============================  ========================================
Name             Type             Default value                    Description
===============  ===============  ===============================  ========================================
DOWNSIZE_RATIO   int              4                                Ratio of input to output data width
---------------  ---------------  -------------------------------  ----------------------------------------
OUT_DATA_WIDTH   int              2                                Output data width in bits
---------------  ---------------  -------------------------------  ----------------------------------------
OUT_USER_WIDTH   int              1                                Output user width in bits
---------------  ---------------  -------------------------------  ----------------------------------------
IN_DATA_WIDTH    localparam int   OUT_DATA_WIDTH * DOWNSIZE_RATIO  Input data width in bits
---------------  ---------------  -------------------------------  ----------------------------------------
IN_USER_WIDTH    localparam int   OUT_USER_WIDTH * DOWNSIZE_RATIO  Input user width in bits
===============  ===============  ===============================  ========================================


Signals
~~~~~~~

=============  =============  =====================  ========================================
Name           I/O type       Range                  Description
=============  =============  =====================  ========================================
clock          input logic    1                      Clock signal
-------------  -------------  ---------------------  ----------------------------------------
sreset         input logic    1                      Synchronous reset signal, active high
-------------  -------------  ---------------------  ----------------------------------------
s_axi_tdata    input logic    [IN_DATA_WIDTH-1:0]    AXI Stream input data
-------------  -------------  ---------------------  ----------------------------------------
s_axi_tuser    input logic    [IN_USER_WIDTH-1:0]    AXI Stream input user signal
-------------  -------------  ---------------------  ----------------------------------------
s_axi_tvalid   input logic    1                      AXI Stream input valid signal
-------------  -------------  ---------------------  ----------------------------------------
s_axi_tlast    input logic    1                      AXI Stream input last signal
-------------  -------------  ---------------------  ----------------------------------------
s_axi_tkeep    input logic    [DOWNSIZE_RATIO-1:0]   AXI Stream input keep, set bits contiguous from bit 0
-------------  -------------  ---------------------  ----------------------------------------
s_axi_tready   output logic   1                      AXI Stream input ready signal
-------------  -------------  ---------------------  ----------------------------------------
m_axi_tdata    output logic   [OUT_DATA_WIDTH-1:0]   AXI Stream output data
-------------  -------------  ---------------------  ----------------------------------------
m_axi_tuser    output logic   [OUT_USER_WIDTH-1:0]   AXI Stream output user signal
-------------  -------------  ---------------------  ----------------------------------------
m_axi_tvalid   output logic   1                      AXI Stream output valid signal
-------------  -------------  ---------------------  ----------------------------------------
m_axi_tlast    output logic   1                      AXI Stream output last signal
-------------  -------------  ---------------------  ----------------------------------------
m_axi_tready   input logic    1                      AXI Stream output ready signal
=============  =============  =====================  ========================================
