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

The step is one level of XOR reduction, not the ``DATA_WIDTH``
sequential conditional stages the textbook bit-serial recurrence needs.
CRC-32 is linear over GF(2) in ``{crc_in, data}``, so the whole map is
exactly the XOR of the bit-serial step evaluated on each set input bit
alone — the basis expansion of a linear map, computed once at
elaboration into two constant matrices and reduced to a plain XOR tree
at runtime. Measured on the `Zedboard TCP endpoint
<../../boards/zedboard/tcp_endpoint/README.rst>`_: the bit-serial
form, unrolled combinationally every cycle in
``axi_stream_eth_fcs_gen``, was the fabric-domain critical path once
the TCP receive checksum was fixed — 31 logic levels, 16 CARRY4,
reached through whichever control signal happened to gate the byte on
the bus that cycle, itself unrelated to the actual depth.

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

Testing
-------

The bench sweeps ``DATA_WIDTH`` at 1, 2, 4 and 8 bits per step, all
four consuming the same two messages and reaching the same CRC, and a
fifth instance checks the ``POLY`` parameter with CRC-32C — every
instance checked against an independently known value: the textbook
check value for ``"123456789"``, a 60-byte ramp against zlib's
``crc32``, and the CRC-32C check value. ALL TESTS PASSED under
``check.iverilog`` and ``check.verilator``, ``lint.verilator`` clean.
Mutation-tested: dropping either matrix's contribution for one input
bit, reversing the data basis vectors, an off-by-one loop bound, and
XOR replaced by AND in the reduction each fail the bench.
