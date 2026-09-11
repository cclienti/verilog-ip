AXI Stream TCP Socket
=====================

Description
-----------

One TCP connection between the IPv4 layer and an application, with the
application side as a pair of byte streams: payload received in order
leaves on ``m_app_*``, bytes the application presents on ``s_app_*``
are segmented, sent and retransmitted until acknowledged. A wire from
``m_app_*`` to ``s_app_*`` makes the socket an echo server — the first
use case, ``nc`` or ``telnet`` to ``listen_port`` — and the same block,
unchanged, serves whatever replaces the wire later.

The socket is a passive server with a single connection record: it
listens on ``listen_port``, completes the three-way handshake, runs
the connection, and follows the peer's close. Segments arrive as the
`IPv4 parser <../axi_stream_ipv4_parser/README.rst>`_ and `packet
demux <../../../lib/axi_stream_packet_demux/README.rst>`_ deliver them
— cut at ``total_length``, whole frames — with the parser side-bands
on ``s_src_ip``/``s_dst_ip``/``s_length`` and the frame's source MAC
from the `eth parser <../axi_stream_eth_parser/README.rst>`_ on
``s_src_mac``, all sampled with the segment's first beat. Every frame
the socket sends is a complete Ethernet frame, MAC and IP headers
included (TTL 64, DF set, a fresh IP header checksum), ready for the
`packet mux <../../../lib/axi_stream_packet_mux/README.rst>`_ and the
`FCS generator <../axi_stream_eth_fcs_gen/README.rst>`_, which pads
short segments to the minimum frame. The peer's MAC is captured from
the frame carrying its SYN and kept in the connection record, so no
ARP lookup sits on the transmit path.

Unlike the `ARP <../axi_stream_eth_arp/README.rst>`_ and `ICMP
<../axi_stream_icmp_echo/README.rst>`_ responders, the socket never
answers a segment with a frame built from it: the receive side and
the transmit side are separate engines around the connection record,
and ``s_axi_tready`` does not drop while a frame drains. The receive
chain behind the demuxes therefore no longer stalls on TCP traffic,
only on the two responders.

Receive
-------

A segment is validated on the fly: at least 20 bytes and a data
offset that fits ``s_length``, a destination equal to ``local_ip``
(the parser also passes limited broadcast, which is dropped here), a
TCP checksum over the pseudo-header, header and data that verifies,
and no ``tuser``. Options are skipped, none is interpreted. The
checksum verdict only exists on the last byte, so the payload is
written speculatively into the receive buffer — an
`axi_stream_packet_fifo <../../../lib/axi_stream_packet_fifo/README.rst>`_
in backpressure mode, whose commit/rollback is exactly the mechanism
needed — and doomed with ``tuser`` when the sum fails. Its
``LOG2_FRAMES`` is set to ``LOG2_RX_DEPTH`` so that the frame count
can never bind before the byte count: an interactive session is a
stream of one-byte segments. The socket keeps the byte occupancy
itself (the FIFO does not expose it), and the free space is the
window it advertises.

Only in-order data is accepted: a segment whose sequence number is
exactly the next expected one and whose payload fits the free space is
stored, acknowledged, and delivered on ``m_app_*`` with ``tlast`` on
its last byte, the segment boundary. Anything else that belongs to
the connection — an old segment (the peer's retransmission, our
acknowledgement was lost), a future one (reordering or a lost
predecessor), a partial overlap, a window probe — is consumed, not
stored, and answered with a pure acknowledgement carrying the current
expected sequence number and window. The peer's retransmission timer
then drives recovery from its side, and the socket never needs
out-of-order storage. When the application does not consume, the
window closes to zero; when the free space has been advertised below
``MSS`` and rises back to ``MSS`` or more, a pure acknowledgement
carries the update without waiting for the peer's probe.

An acknowledgement number between the oldest unacknowledged byte and
the next byte to send releases the transmit ring up to it and restarts
the retransmission timer if data is still outstanding, or stops it.
One outside that range is ignored, and answered with a pure
acknowledgement if it lies ahead of what was sent.

While the socket is not listening for it, a segment is matched
against the connection record — peer IP, peer port, ``listen_port``.
A segment for any other port, or from any other peer while a
connection is up, is answered with a reset built as RFC 793 specifies
for a closed port, unless it carries ``RST`` itself; the peer sees
"connection refused" instead of a timeout. A reset from the peer, in
any state past ``LISTEN``, closes the connection at once.

Transmit
--------

Bytes accepted on ``s_app_*`` enter a ``2**LOG2_TX_DEPTH``-byte ring
and stay there until acknowledged; ``s_app_tready`` drops when the
ring is full and outside the states that carry data. A segment is
sent as soon as unsent bytes are present and either ``s_app_tlast``
was accepted with them — send now, the push — or ``MSS`` of them are
waiting. There is no Nagle delay: an interactive echo must go back
per keystroke. Every data segment carries ``PSH`` and ``ACK``.

Those two rules are the whole of the send policy, and they put the
``TCP_NODELAY``/``TCP_CORK`` choice in the application's hands, byte
by byte: ``tlast`` on every unit is no-delay, ``tlast`` withheld is
cork. What is *not* implemented, and left as a documented extension,
is the cork timeout Linux applies after 200 ms — an application that
never asserts ``tlast`` and stops short of ``MSS`` leaves its bytes
in the ring until more arrive. It would be a third send rule, "unsent
bytes waiting and none arrived for ``PUSH_IDLE_CLOCKS`` cycles", one
counter and one more boolean into the scheduler, zero disabling it.
The echo wire never needs it, every looped segment ends with a
``tlast``; it is deferred until an application behind the socket
does.

The headers leave before the data and a retransmission re-reads the
ring, so the data sum cannot be taken at write time: the transmit
engine reads a segment once to sum it, then again to emit it. At one
byte per cycle a full-``MSS`` segment costs under 30 µs, invisible on
Fast Ethernet.

The retransmission timer runs whenever a sequence number is
outstanding — data, our SYN-ACK, our FIN. On expiry the oldest
unacknowledged segment, at most ``MSS`` bytes from the ring or the
control segment itself, is sent again and the timer restarts;
``MAX_RETRIES`` consecutive expiries reset the connection. A fixed
``RTO_CLOCKS`` period, no round-trip estimate and no back-off, is
enough on a LAN and keeps the timer a plain counter.

A pure acknowledgement is not sent the moment it is owed: it waits
``ACK_DELAY_CLOCKS`` for a data segment to carry it. With the echo
wire the received bytes are back in the ring within a few cycles of
their delivery, so the acknowledgement rides on the echo and each
keystroke costs one frame each way instead of two. The delay is far
below the 500 ms RFC 1122 allows.

The transmit side serves, in this priority: a reset or a handshake
segment the connection machine asks for, a retransmission, a data
segment, a pure acknowledgement. One segment is in flight through the
engine at a time; the packet mux downstream merges it with the
responders' frames.

Connection
----------

The passive half of the RFC 793 diagram: ``LISTEN``, ``SYN_RCVD``,
``ESTABLISHED``, ``CLOSE_WAIT``, ``LAST_ACK``, and back to ``LISTEN``.
The SYN-ACK carries a single option, ``MSS``; the initial sequence
number is sampled from a free-running counter. A SYN from another
peer while a connection is up gets a reset, so one client at a time.

The socket has no application-side close request yet: after the
peer's FIN it sends its own as soon as the ring is empty, everything
sent is acknowledged, and the receive buffer has been drained — so
that an application looping the last bytes back still gets them out.
Once that FIN is acknowledged the connection record is cleared and
both buffers are emptied; bytes the application had not yet sent are
lost, as on a closed socket. Active open and active close are the
extension that makes a client out of this block; they add states to
the connection machine and a control side-band, and change neither
stream.

``connected`` is high from ``ESTABLISHED`` to ``LAST_ACK``
inclusive; ``peer_ip`` and ``peer_port`` are valid while it is.
``local_mac``, ``local_ip`` and ``listen_port`` are sampled when a
SYN is accepted and held for the connection's life.

Testing
-------

Test the echo with ``nc`` before ``telnet``: telnet opens with option
negotiation, and echoing ``IAC DO x`` back converges to ``WONT`` but
muddies the first bytes on the wire.

State machines
--------------

This block is also a benchmark for an FSM synthesis flow, so every
control machine is explicit and separable: an enumerated state, one
registered process, one next-state process, one outputs process,
Moore outputs unless a handshake forces a Mealy one. Transition
conditions are named booleans computed outside the machine — header
done, timer expired, ring empty — never a counter compare inside the
case; every state is named in the case, and the default recovers to
the idle state. Counters, pointers and the timer are datapath, not
state.

- **Connection machine** — its own component,
  `tcp_connection_fsm <../tcp_connection_fsm/README.rst>`_, so a
  generated version drops in without touching the socket and gets
  its own area and timing numbers. Inputs are one-cycle events from
  the receive engine — acceptable SYN, acknowledgement of the
  outstanding control segment, FIN, RST, retries exhausted — and a
  transmit-done pulse; outputs are the state, ``connected``, and the
  requests for a SYN-ACK, a FIN or a reset. States ``CLOSED``,
  ``LISTEN``, ``SYN_RCVD``, ``ESTABLISHED``, ``CLOSE_WAIT``,
  ``LAST_ACK``.
- **Receive walker** — ``IDLE``, ``HEADER``, ``OPTIONS``, ``PAYLOAD``,
  ``DROP``. Walks the segment, validates it, writes the receive
  buffer, raises the events above and the acknowledgement-owed
  flag. Registers the events, so the connection machine never sees a
  raw stream bit.
- **Transmit walker** — ``IDLE``, ``SUM``, ``ETH_HEADER``,
  ``IP_HEADER``, ``TCP_HEADER``, ``PAYLOAD``. Emits one frame of the
  kind it was handed.
- **Transmit scheduler** — the priority above. Written as a machine
  if it needs one to sequence the pre-pass and the hand-off, as
  priority logic otherwise; decided when the RTL is written.

Parameters
----------

- ``LOG2_RX_DEPTH``: receive buffer size in bytes, log2 (default 11 —
  2048 bytes; the largest window advertised; at least ``MSS``).
- ``LOG2_TX_DEPTH``: transmit ring size in bytes, log2 (default 11 —
  2048 bytes; bounds the unacknowledged data; at least ``MSS``).
- ``MSS``: maximum segment size, advertised in the SYN-ACK and the
  largest payload sent (default 1460, the 1500 MTU; at most 16 bits).
- ``RTO_CLOCKS``: retransmission timeout in clock cycles (default
  10 000 000 — 200 ms at 50 MHz).
- ``MAX_RETRIES``: consecutive retransmissions before the connection
  is reset (default 8).
- ``ACK_DELAY_CLOCKS``: hold-off of a pure acknowledgement, in clock
  cycles, for a data segment to carry it (default 4096 — 82 µs at
  50 MHz).

Signals
-------

- ``clock``, ``sreset``: clock and synchronous reset, active high.
- ``local_mac`` (48 bits), ``local_ip`` (32 bits), ``listen_port``
  (16 bits): endpoint identity and the listening port, sampled when a
  SYN is accepted.
- ``s_axi_tdata`` (8 bits), ``s_axi_tuser``, ``s_axi_tvalid``,
  ``s_axi_tlast``, ``s_axi_tready``: AXI stream slave, TCP segments
  from the IPv4 demux.
- ``s_src_ip`` (32 bits), ``s_dst_ip`` (32 bits), ``s_length``
  (16 bits), ``s_src_mac`` (48 bits): parser side-bands, stable for
  the whole segment, sampled with its first beat.
- ``m_axi_tdata`` (8 bits), ``m_axi_tuser``, ``m_axi_tvalid``,
  ``m_axi_tlast``, ``m_axi_tready``: AXI stream master, complete
  Ethernet frames; ``m_axi_tuser`` is constant zero.
- ``m_app_tdata`` (8 bits), ``m_app_tvalid``, ``m_app_tlast``,
  ``m_app_tready``: AXI stream master to the application, received
  payload in order, ``tlast`` on the last byte of each segment.
- ``s_app_tdata`` (8 bits), ``s_app_tvalid``, ``s_app_tlast``,
  ``s_app_tready``: AXI stream slave from the application, bytes to
  send; ``tlast`` sends what is waiting now.
- ``connected``: a connection is up, ``ESTABLISHED`` to ``LAST_ACK``.
- ``peer_ip`` (32 bits), ``peer_port`` (16 bits): the connected peer,
  valid while ``connected`` is high.
