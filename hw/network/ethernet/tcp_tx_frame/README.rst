TCP Transmit Frame Builder
==========================

Description
-----------

The transmit walker of the `TCP socket
<../axi_stream_tcp_socket/README.rst>`_, as a component of its own so
the socket hands it one segment at a time and so it is verified
against the `bench-side model <../tcp_model/README.rst>`_ on its own,
like the `connection machine <../tcp_connection_fsm/README.rst>`_.

Given the header fields the scheduler has chosen and a payload it
reads back from the transmit ring, it emits one complete Ethernet
frame — MAC and IPv4 headers (TTL 64, DF set, a fresh IP checksum),
the TCP header, the MSS option on a SYN-ACK, then the payload — with
both checksums in place, ready for the `packet mux
<../../../lib/axi_stream_packet_mux/README.rst>`_ and the `FCS
generator <../axi_stream_eth_fcs_gen/README.rst>`_. It builds any of
the socket's segment kinds: the flags, ``with_mss``, the payload
length and every header value are inputs, so a SYN-ACK, a data
segment, a pure acknowledgement, a persist probe, a FIN and a reset
are all the same walk with different fields.

The fields are latched on ``start``. A payload of ``pl_len`` bytes is
read back twice through ``pl_addr``/``pl_data`` — once in ``SUM`` to
accumulate the TCP data checksum (the header leaves before the data
and a retransmission re-reads the ring, so the sum cannot be taken at
write time), then again in ``PAYLOAD`` to emit it. ``pl_addr`` is a
0-based offset into the segment; the scheduler maps it onto the ring,
so a retransmission is the same walk with a different base.

The block holds ``m_axi_tready``'s backpressure at every beat and
carries ``m_axi_tuser`` low; the frame it emits never aborts. This
first version sums the fixed header halfwords combinationally, which
is simple and correct; the running-ahead checksum pipeline the socket
README describes is a timing refinement that does not change the
bytes emitted, and is left for when the block is placed in context.

Signals
-------

- ``clock``, ``sreset``: clock and synchronous reset, active high.
- ``start``: one-cycle pulse, begin a frame; all fields below are
  sampled with it.
- ``with_mss``: include the 4-byte MSS option (a SYN-ACK).
- ``pl_len`` (16 bits): payload bytes, 0 for a control segment.
- ``dst_mac``/``src_mac`` (48), ``ip_id`` (16), ``src_ip``/``dst_ip``
  (32), ``src_port``/``dst_port`` (16): the addressing.
- ``seq``/``ack`` (32), ``flags`` (8), ``window`` (16), ``mss`` (16):
  the TCP fields; ``mss`` is used only when ``with_mss``.
- ``pl_addr`` (16, out), ``pl_data`` (8, in): combinational payload
  read-back, the ring byte at the segment offset ``pl_addr``.
- ``m_axi_*``: AXI stream master, one complete Ethernet frame;
  ``m_axi_tuser`` is constant zero.
- ``busy``: high from ``start`` until the last beat.

Parameters
----------

None.

Testing
-------

The bench drives every segment kind and hundreds of random
field/payload combinations, captures the emitted bytes under random
backpressure, and compares them against ``tcp_model_pkg.build_frame``
byte for byte, then parses them back with ``parse_frame`` and checks
every field and the payload. The payload is read for both the sum and
the emit pass, so the two-pass read is exercised, and odd-length
payloads test the checksum's trailing-byte pad. Backpressure is a
ready registered off the clock with a posedge monitor, race-free
across simulators. 1388 checks, ALL TESTS PASSED under
``check.iverilog`` and ``check.verilator``, ``lint.verilator`` clean.
Mutation-tested: a wrong TTL, a dropped payload byte in the sum, a
zeroed MSS value, a TCP length off by one, and the IP checksum bytes
swapped each fail the bench, by 82 to 1041 checks.
