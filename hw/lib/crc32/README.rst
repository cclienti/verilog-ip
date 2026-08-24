CRC-32 Step
===========

Description
-----------

Combinational CRC-32 step in the reflected (LSB-first) form: ``crc_out``
is ``crc_in`` advanced by ``DATA_WIDTH`` input bits, ``data[0]`` first.
The client owns the CRC register and closes the loop through ``crc_in``,
so the seed and the final complement policy are the client's choice —
which is why neither is a parameter. Shared by
``axi_stream_eth_fcs_gen`` and ``axi_stream_eth_fcs_check`` so the FCS
polynomial has a single definition.

For the Ethernet FCS: seed the register with ``32'hFFFFFFFF``, step every
frame byte through, and the FCS is the complemented register sent low
byte first.

Parameters
----------

- ``POLY``: reflected polynomial (default ``32'hEDB88320``, the
  IEEE 802.3 / zlib CRC-32).
- ``DATA_WIDTH``: bits consumed per step (default 8).

Signals
-------

- ``crc_in``: current CRC register value.
- ``data``: ``DATA_WIDTH`` input bits, LSB first.
- ``crc_out``: CRC register value after the input bits.
