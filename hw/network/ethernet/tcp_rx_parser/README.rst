TCP Receive Segment Parser
==========================

Description
-----------

The receive walker of the `TCP socket
<../axi_stream_tcp_socket/README.rst>`_, as a component of its own so
it is verified against the `bench-side model <../tcp_model/README.rst>`_
on its own, like the `connection machine
<../tcp_connection_fsm/README.rst>`_ and the `transmit builder
<../tcp_tx_frame/README.rst>`_. It is the streaming twin of the
model's ``parse_tcp``.

It decodes and validates one TCP segment as the `IPv4 parser
<../axi_stream_ipv4_parser/README.rst>`_ and `packet demux
<../../../lib/axi_stream_packet_demux/README.rst>`_ deliver it — the
L4 unit, cut at ``total_length``, with ``s_src_ip``/``s_dst_ip``/
``s_length`` beside its first beat — and streams the payload out. It
knows nothing of the connection: the record match, the in-order and
window decisions, the events and the receive FIFO are the socket's,
wrapped around this. Keeping it connectionless is what lets it be
checked field-for-field against ``parse_tcp`` with no state to set up.

Validation is on the fly: at least 20 bytes, a data offset of at
least 5 that fits ``s_length``, a TCP checksum over the pseudo-header,
header and data that verifies, and no ``tuser`` on any beat. The
header fields are registered as their bytes pass and are stable from
``hdr_valid`` to ``seg_done``. Options are walked and the MSS option
is read; every other option is skipped, and the walk is bounded by
the header length so a malformed option cannot run into the payload.
The payload leaves on ``m_pl_*``, its ``tlast`` the segment's last
byte; ``m_pl_tuser`` is raised on that last beat when the segment
failed — the doom the socket's receive FIFO honours, so a bad segment
written speculatively is rolled back. A structurally bad segment (a
data offset that does not fit) is consumed to its end with no payload
emitted and ``seg_ok`` low.

Clean FSM for the socket's benchmark goal: ``IDLE``, ``HEADER``,
``OPTIONS``, ``PAYLOAD``, ``DROP``, with the option walk a small
second machine; the byte counter, the field registers and the
checksum accumulator are datapath. Header, options and drop bytes are
consumed unconditionally; only the payload waits on ``m_pl_tready``,
which is where a stall propagates back to ``s_axi_tready``.

Signals
-------

- ``clock``, ``sreset``: clock and synchronous reset, active high.
- ``s_axi_*``: AXI stream slave, one TCP segment; ``s_axi_tuser`` on
  any beat fails it.
- ``s_src_ip``, ``s_dst_ip`` (32), ``s_length`` (16): the parser
  side-bands, sampled on the first beat, for the pseudo-header
  checksum and the length checks.
- ``m_pl_*``: AXI stream master, the payload; ``m_pl_tuser`` on the
  last beat is the doom for a failed segment.
- ``src_port``/``dst_port`` (16), ``seq_num``/``ack_num`` (32),
  ``flags`` (8), ``window``/``urgent`` (16), ``mss`` (16, 0 when
  absent), ``payload_len`` (16): the decoded header, stable from
  ``hdr_valid`` to ``seg_done``.
- ``hdr_valid``: pulse, the 20-byte header parsed and structurally
  sound.
- ``seg_done``: pulse, the segment ended.
- ``seg_ok``: with ``seg_done``, the segment fully validated.

Parameters
----------

None.

Testing
-------

The bench drives segments built by ``tcp_model_pkg`` under random
payload backpressure and checks the decoded fields, the pass/fail
verdict and the streamed payload against ``parse_tcp`` and
``tcp_payload`` — an independent decoder. Good segments of every kind
and length, a hand-built option list (two NOPs, MSS, a window-scale
option, EOL, padding) whose MSS must be read from behind the NOPs, a
data offset below 5 that must be dropped, single-byte damages to the
header, a payload byte and the checksum field that must each flip the
verdict and doom the payload, and a ``tuser`` mid-segment that must
fail it. 1250 checks, ALL TESTS PASSED under ``check.iverilog`` and
``check.verilator``, ``lint.verilator`` clean. Mutation-tested: a
corrupted sequence byte, the checksum comparison inverted, the
data-offset lower-bound check removed, the MSS high byte zeroed, and
the payload doom held low each fail the bench, by 1 to 366 checks.
