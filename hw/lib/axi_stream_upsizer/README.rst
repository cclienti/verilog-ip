AXI Stream Upsizer
==================

Description
-----------

This module upsizes the data and user signals of an AXI Stream interface by a specified ratio. It
takes in a smaller data width and combines multiple input words into a larger output word, while
also appropriately handling the user signals.

The upsizing ratio is configurable, allowing for flexibility in adapting to different data widths.

The module also handles the user signals and the last signal appropriately, ensuring that the
integrity of the data stream is maintained. It uses a shift register to manage the buffering of
incoming data and user signals, and it generates the appropriate tkeep signals for the output
stream.

The module is fully synchronous and includes a reset signal for initialization.


Interface
---------

Parameters
~~~~~~~~~~

===============  ===============  =============================  ========================================
Name             Type             Default value                  Description
===============  ===============  =============================  ========================================
UPSIZE_RATIO     int              4                              Ratio of input to output data width
---------------  ---------------  -----------------------------  ----------------------------------------
IN_DATA_WIDTH    int              2                              Input data width in bits
---------------  ---------------  -----------------------------  ----------------------------------------
IN_USER_WIDTH    int              1                              Input user width in bits
---------------  ---------------  -----------------------------  ----------------------------------------
OUT_DATA_WIDTH   localparam int   IN_DATA_WIDTH * UPSIZE_RATIO   Output data width in bits
---------------  ---------------  -----------------------------  ----------------------------------------
OUT_USER_WIDTH   localparam int   IN_USER_WIDTH * UPSIZE_RATIO   Output user width in bits
===============  ===============  =============================  ========================================


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
m_axi_tkeep    output logic   [UPSIZE_RATIO-1:0]     AXI Stream output keep signal
-------------  -------------  ---------------------  ----------------------------------------
m_axi_tready   input logic    1                      AXI Stream output ready signal
=============  =============  =====================  ========================================
