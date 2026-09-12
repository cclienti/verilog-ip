AXI Stream TCP Socket
=====================

Description
-----------

One TCP connection between the IPv4 layer and an application, with the
application side as a pair of byte streams: payload received in order
leaves on ``m_app_*``, bytes the application presents on ``s_app_*``
are segmented, sent and retransmitted until acknowledged. The end of
the stream travels in the stream, as a close token beat with
``tuser``, so a plain wire from ``m_app_*`` to ``s_app_*`` makes the
socket an echo server — the first use case, ``nc`` or ``telnet`` to
``listen_port`` — and the same block, unchanged, serves whatever
replaces the wire later.

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

::

  s_axi_* ──► receive walker ────► receive buffer ────► m_app_*
  side-bands   validate, order,     packet FIFO,          in order, tlast
               checksum, events     commit / rollback     per segment,
                    │ events              │ occupancy     close token last
                    ▼                     ▼ window
             connection machine ◄──► connection record ──► connected
             tcp_connection_fsm      peer MAC/IP/port,     peer_ip, peer_port
                    │ levels         seq/ack, window,
                    ▼                timer, retries
  m_axi_* ◄── transmit walker ◄── scheduler ◄──── transmit ring ◄──── s_app_*
  complete     header image,      reset, SYN-ACK,   una/nxt/wr,       data, and
  frames       checksums,         FIN, resend,      bytes kept until  the close
               payload            probe, data, ACK  acknowledged      token

The two engines meet only in the connection record and in the
machine. The receive walker writes the record (peer, next expected
sequence, the peer's acknowledgement and window), commits or dooms
segments in the receive buffer, and hands the machine its events,
the scheduler its acknowledgement-owed flag and the one-entry reset
request. The scheduler reads the record and the ring's pointers to
choose the next segment, the transmit walker builds and emits it, and
neither ever waits on the receive side, nor the receive side on
them. The receive buffer and the ring are the two block RAMs; the
ring is indexed by sequence number and freed by acknowledgement, not
by read, which is why it is not a packet FIFO.

Receive
-------

A segment is validated on the fly: at least 20 bytes, a data offset
of at least 5 that fits ``s_length``, a destination equal to
``local_ip`` (the parser also passes limited broadcast, which is
dropped here), a TCP checksum over the pseudo-header, header and data
that verifies, and no ``tuser``. Options are walked, and one is read:
the MSS option of the SYN, which bounds what the socket sends (see
Transmit); every other option is skipped. The checksum verdict only
exists on the last byte, so the payload is written speculatively into
the receive buffer — an `axi_stream_packet_fifo
<../../../lib/axi_stream_packet_fifo/README.rst>`_ in backpressure
mode, whose commit/rollback is exactly the mechanism needed — and
doomed with ``tuser`` when the sum fails. The FIFO reports its
occupancy on ``level`` and ``frames``, committed beats and frames not
yet popped, and the socket's window is ``2**LOG2_RX_DEPTH - level``.
A segment is stored only if its payload fits that free space *and* a
frame slot is free, ``2**LOG2_RX_FRAMES`` being the frame capacity:
an interactive session is a stream of one-byte segments and can run
out of frame slots long before bytes, and a segment refused for want
of one is consumed and acknowledged without it, like any that does
not fit, so the peer resends it later and the window is never
retracted. The walker writes one segment at a time and checks the fit
at the header, before writing, so the frame in flight — which the
FIFO leaves out of its counts — is never unaccounted for. The FIFO's
data is nine bits wide, the byte and a token bit: when the
peer's FIN is accepted the walker commits a one-beat frame with the
token bit set, behind every committed segment by construction, and
on the way out that beat becomes the close token — ``m_app_tuser``
and ``m_app_tlast`` high, ``m_app_tdata`` to be ignored — the read
side's end of stream, one extra beat per connection. It is a data
bit and not the FIFO's own ``tuser``, which dooms a frame.

Only in-order data is accepted, and only while the connection machine
holds ``rx_open``: a segment whose sequence number is exactly the
next expected one and whose payload fits the free space is stored,
acknowledged, and delivered on ``m_app_*`` with ``tlast`` on its last
byte, the segment boundary. Anything else that belongs to the
connection — an old segment (the peer's retransmission, our
acknowledgement was lost), a future one (reordering or a lost
predecessor), a partial overlap, a window probe, data carried by the
handshake ACK itself — is consumed, not stored, and answered with a
pure acknowledgement carrying the current expected sequence number
and window. The peer's retransmission timer then drives recovery from
its side, and the socket never needs out-of-order storage. A FIN is
accepted, and reported to the connection machine, under the same
gate as data — ``rx_open``, and in order: its own sequence number,
after any data the segment carries and which must itself have been
stored, is the next expected one — and it needs one free byte in
the receive buffer for its token, failing which it is treated like
data that does not fit. A FIN not accepted is not acknowledged
either, so the peer retransmits it; that is what keeps a FIN on the
handshake ACK from being swallowed in ``SYN_RCVD`` with the machine
never told. When the application does not consume, the window closes to zero;
when the free space has been advertised below the effective MSS and
rises back to it or more, a pure acknowledgement carries the update
without waiting for the peer's probe.

An acknowledgement number strictly above the oldest unacknowledged
byte and up to and including the next byte to send releases the
transmit ring up to it, clears the retry counter, and restarts the
retransmission timer if a sequence number is still outstanding or
bytes wait against a zero window, or stops it. An acknowledgement
equal to the oldest unacknowledged byte
— a duplicate, or any segment the peer sends while our lost segment
is outstanding — changes nothing, so it cannot keep the timer from
expiring. One ahead of what was sent is answered with a pure
acknowledgement. Every acceptable segment from the peer also restarts
the idle limit.

Resets
------

Every segment not accepted above is answered as RFC 793 prescribes
for a socket that does not exist, unless it carries ``RST`` itself:
a reset with sequence number equal to the segment's acknowledgement
number when it carries ``ACK``, otherwise sequence 0 and an
acknowledgement of the segment's own sequence number plus its length
plus one per SYN or FIN. Concretely:

- a segment to any port other than ``listen_port``, in any state;
- in ``LISTEN``, a segment to ``listen_port`` carrying ``ACK`` — the
  tail of a connection the socket has already forgotten, which is
  routine after an abort; a SYN is accepted, and a segment with
  neither is dropped;
- in any state past ``LISTEN``, a segment from any other peer, a SYN
  included, so a second client sees "connection refused" instead of
  a timeout.

The reset is addressed from the offending segment, not from the
connection record: the receive walker captures its source MAC, IP
and port, its destination port, sequence and acknowledgement
numbers, flags and length into a one-entry reset request, and the
transmit side builds the reset from that, with the live
``local_mac`` and ``local_ip`` as its source when no connection has
sampled them. A further offending segment arriving while the request is
pending is dropped; its sender retransmits. A reset *from* the
connected peer that is in order closes the connection at once, in any
state past ``LISTEN``. When the socket itself gives a connection up —
retransmission budget spent, idle limit reached — it sends a reset to
the peer from the connection record before clearing it, so the peer
does not sit in ``ESTABLISHED`` for minutes.

Transmit
--------

Bytes accepted on ``s_app_*`` enter a ``2**LOG2_TX_DEPTH``-byte ring
and stay there until acknowledged; ``s_app_tready`` drops only when
the ring is full. A beat with ``s_app_tuser`` high is the
application's close token, the mirror of the one on ``m_app_*``: it
carries no data, its ``tdata`` is ignored, it never enters the ring,
and it sets the close flag the FIN waits for. A data beat never
carries ``tuser``, so there is one form and no ambiguity about
whether a flagged byte is data. Beats that arrive after the token,
or while the connection machine does not hold ``tx_open``, tokens
included, are accepted and discarded — a write on a closed socket —
rather than held: holding would freeze an application's pipeline for
the rest of the connection and, worse, deadlock the clean-up, whose
frame-wise flush needs the wire to keep taking what ``m_app_*``
delivers. The close flag is cleared on the way from ``CLOSED`` to
``LISTEN``, so a token the flush loops back through the wire cannot
close the next connection.

The ring is nine bits wide: each byte lands at the position of its
sequence number together with its ``s_app_tlast``,
which a block RAM gives at that width for nothing, and neither the
byte's place nor its stay depends on the bit. A segment is sent as
soon as unsent bytes are present and either a ``tlast`` is among
them — send now, the push — or an effective MSS of them are waiting.
The first condition is a counter of pending pushes, up by one when a
``tlast`` byte is accepted and down by one when a segment ends on
one, so the scheduler sees a boolean. There is no Nagle delay: an
interactive echo must go back per keystroke. Every data segment
carries ``PSH`` and ``ACK``.

A segment is cut at the first ``tlast`` from the send pointer, or at
the effective MSS, whichever comes first; pushes are never merged, so
the framing the application expressed leaves as it was expressed,
and with the echo wire one segment in is exactly one segment out. It
is a hint, not a frame: a message longer than the MSS leaves in
several segments, and the far end marks a boundary at every segment
it receives, so anything that needs real framing across TCP puts it
in the payload.

The effective MSS is the smallest of the ``MSS`` parameter, the MSS
option the peer's SYN carried, and 536 when it carried none, per RFC
1122. It is the largest payload sent or resent; with ``DF`` set on
every frame, a segment cut at the socket's own size would be dropped
by any narrower hop on the path, and the stack has no path MTU
discovery to notice.

Those two rules are the whole of the send policy, and they put the
``TCP_NODELAY``/``TCP_CORK`` choice in the application's hands, byte
by byte: ``tlast`` on every unit is no-delay, ``tlast`` withheld is
cork. What is *not* implemented, and left as a documented extension,
is the cork timeout Linux applies after 200 ms — an application that
never asserts ``tlast`` and stops short of the effective MSS leaves
its bytes in the ring until more arrive. It would be a third send
rule, "unsent bytes waiting and none arrived for ``PUSH_IDLE_CLOCKS``
cycles", one counter and one more boolean into the scheduler, zero
disabling it. The echo wire never needs it, every looped segment ends
with a ``tlast``; it is deferred until an application behind the
socket does.

The headers leave before the data and a retransmission re-reads the
ring, so the data sum cannot be taken at write time: the transmit
engine reads a segment once to sum it, then again to emit it. That
first pass is also what finds the cut: it reads from the send pointer
byte by byte and stops at the first ``tlast``, at the effective MSS,
or after the one byte of a probe, so a single scan yields both the
length the IP header needs and the data sum, and no length is kept
per segment. A retransmission scans from the oldest unacknowledged
byte under the same rule and reproduces the original cut, the same
``tlast`` bits and the same MSS being there. At one byte per cycle a
full-MSS segment costs under 30 µs, invisible on Fast Ethernet.

The retransmission timer runs whenever a sequence number is
outstanding — data, our SYN-ACK, our FIN — and also, as the persist
timer, whenever unsent bytes wait in the ring against a zero window
(see below). On expiry with a sequence number outstanding, the oldest
unacknowledged segment, at most an effective MSS from the ring or the
control segment itself, is sent again; the timer restarts and the
retry counter increments. ``MAX_RETRIES`` consecutive expiries
without an acknowledgement that advances give the connection up. A
fixed ``RTO_CLOCKS`` period, no round-trip estimate and no back-off,
is enough on a LAN and keeps the timer a plain counter.

The timer is the only trigger of a retransmission. TCP has no
explicit request; the peer signals a loss implicitly, and neither
signal is acted on here. Duplicate acknowledgements — the same
number again, no data, the window unchanged, three of which RFC 5681
turns into an immediate resend of the oldest segment — change
nothing, as stated above. Selective acknowledgement is never
negotiated, the SYN-ACK carrying the MSS option alone, so the peer
never sends SACK blocks and nothing parses them. Fast retransmit is
the documented, not implemented, extension: one counter of such
duplicates and one more boolean into the scheduler, firing the same
resend the timer does, restarting the timer, and not counting
against ``MAX_RETRIES``. Keystroke segments carry data and so are
not duplicates; only the peer's pure acknowledgements of later
echoes are, which is the RFC's intent. Without it a lost echo shows
as a pause of up to ``RTO_CLOCKS`` before the character appears.

The peer's receive window bounds what may be in flight: the window
field of every acceptable segment is kept, and no byte is sent beyond
the oldest unacknowledged one plus that window. Bytes the application
presents past it wait in the ring. When that window is zero and bytes
wait, the timer runs even though nothing is outstanding, and on
expiry a one-byte probe is sent from the first unsent byte; the peer
answers with its current window and sending resumes when a window
update arrives, on that answer or on any segment. Unanswered probes
count against ``MAX_RETRIES`` like retransmissions, and an answered
one clears the counter like any acceptable acknowledgement: a peer
that keeps its window closed but keeps answering is slow, one that
stops answering is gone. A telnet client advertises tens of
kilobytes, so the echo never meets this rule; it is here because the
ring must never overrun a peer that is smaller than it.

An idle connection runs no timer at all, so a peer that vanishes
without a reset would hold the single connection record forever and
every later client would be refused. The idle limit closes that:
``IDLE_CLOCKS`` without an acceptable segment from the peer gives the
connection up, reset sent, like a spent retry budget; zero disables
it. Linux keeps such a connection for hours by default, but Linux
has more than one record.

A pure acknowledgement is not sent the moment it is owed: it waits
``ACK_DELAY_CLOCKS`` for a data segment to carry it. With the echo
wire the received bytes are back in the ring within a few cycles of
their delivery, so the acknowledgement rides on the echo and each
keystroke costs one frame each way instead of two. The delay is far
below the 500 ms RFC 1122 allows.

The transmit side serves, in this priority: a reset — from the reset
request, or to the peer on giving up — then the SYN-ACK or FIN the
connection machine holds pending (sent on the rising edge of the
level, resent on expiry while it stays high), a retransmission or
persist probe, a data segment, a pure acknowledgement. One segment is
in flight through the engine at a time; the packet mux downstream
merges it with the responders' frames.

Frame assembly
--------------

Seven kinds of segment leave the socket. Each is one complete
Ethernet frame; the differences are the TCP header fields and where
the payload, if any, comes from:

=========================== ================== ============ ============ ================== ==============
Kind                        Sequence           Ack          Flags        Payload            TCP header
=========================== ================== ============ ============ ================== ==============
SYN-ACK                     ISN                ``rcv_nxt``  SYN, ACK     none               24, MSS option
Data                        first byte's       ``rcv_nxt``  PSH, ACK     ring, up to the    20
                                                                         effective MSS
Pure acknowledgement        ``snd_nxt``        ``rcv_nxt``  ACK          none               20
Persist probe               first unsent byte  ``rcv_nxt``  ACK          ring, 1 byte       20
FIN                         ``snd_nxt``        ``rcv_nxt``  FIN, ACK     none               20
Reset, from the request     RFC 793            RFC 793      RST or       none               20
                                                            RST, ACK
Reset, on giving up         ``snd_nxt``        ``rcv_nxt``  RST, ACK     none               20
=========================== ================== ============ ============ ================== ==============

A retransmission is a data, SYN-ACK or FIN segment rebuilt from the
same rules with the oldest unacknowledged sequence number. The
window field is the free space of the receive buffer on every kind
but a reset, where it is zero. Data segments carry ``PSH``
unconditionally; the peer's read side does not wait for a full
buffer either way.

The other header fields have one source each. Destination MAC from
the connection record, or from the reset request for a reset it
answers; source MAC and source IP from the identity sampled at the
SYN, or the live inputs for a reset sent with no connection;
EtherType ``0x0800``. In the IP header, version and IHL
``0x45``, TOS zero, total length computed from the TCP header length
and the payload length, identification zero (legal for a datagram
with ``DF`` set, RFC 6864, and one less counter), flags ``DF`` alone,
offset zero, TTL 64, protocol 6, destination IP from the record or
the request. In the TCP header, source port ``listen_port`` and
destination port the peer's, both swapped from the request for a
reset (whose source port is then whatever port the offending segment
was sent to), urgent pointer zero, and the MSS option on the SYN-ACK
only, carrying
the ``MSS`` parameter.

The header is built the way the `ARP responder
<../axi_stream_eth_arp/README.rst>`_ builds its reply: once the
scheduler has decided the kind, the transmit walker assembles a
header image — 58 bytes at most, one register vector — and streams
it by byte index during ``HEADER``, then the payload from the ring
during ``PAYLOAD``. One state for the three headers: nothing changes
at the Ethernet-to-IP or IP-to-TCP boundary that the machine needs
to express, the image is one vector and the checksum index runs on
its own beside the byte index.
Both checksums are ones'-complement sums over halfwords of that same
image, one halfword per cycle, taken by a second index that runs
ahead of the byte index: the IP header checksum covers its ten
halfwords and is emitted at frame byte 24, the TCP checksum covers
the six pseudo-header halfwords, the ten or twelve of the TCP header
and the data sum, and is emitted at byte 50. At one halfword per
cycle from byte 0 both are complete before their slot, with no extra
state and no second copy of any field. The ``SUM`` state supplies
only the data sum, read from the ring before the header starts;
segments without payload skip it, so the pre-pass costs nothing on
control segments or pure acknowledgements, and the headers are never
read twice.

Once the first byte of a frame is presented, every following byte is
delivered as fast as the downsizer takes it, one per four cycles at
100 Mbit: the transmit path has no store-and-forward stage and the
`RMII MAC <../rmii_mac_tx/README.rst>`_ truncates a frame whose
source pauses, which the peer then drops on the FCS. The socket
meets that by construction — the header is a register image, the
payload is already in the ring, the data sum is complete before the
first byte — and the application stream cannot break it, since it
feeds the ring and never the frame in flight. What the serialization
of the sum pass and the wire-paced emit does cost is bulk throughput,
about a fifth on full-size segments (computed, not measured); a
summer running ahead over the unsent bytes while the current frame
drains would recover it without a buffer, and is left for a use case
that moves bulk data.

The Ethernet and IP header prepend is the third copy of the same
logic in this tree, after the `ARP <../axi_stream_eth_arp/README.rst>`__
and `ICMP <../axi_stream_icmp_echo/README.rst>`__ responders. A shared
block taking a payload stream with destination, protocol and length
side-bands would serve all three; the two existing ones are done and
measured, so that refactor, if it comes, starts here.

Connection
----------

The passive half of the RFC 793 diagram: ``CLOSED``, ``LISTEN``,
``SYN_RCVD``, ``ESTABLISHED``, ``CLOSE_WAIT``, ``LAST_ACK``, in the
`connection machine <../tcp_connection_fsm/README.rst>`_. The SYN-ACK
carries a single option, ``MSS``; the initial sequence number is
sampled from a free-running counter. One client at a time: a SYN from
another peer while a connection is up gets a reset. Data or a FIN
riding on the handshake ACK itself are not stored; the peer
retransmits them once the connection is established, one round trip
later on a path that is rare.

The close follows the socket API, carried in the streams. When the
peer's FIN has been accepted, the close token is queued behind every
byte the peer sent, and the application receives it on ``m_app_*``
after the last of them — the read side's end of stream, ``read()``
returning zero. The application answers with its own close token on
``s_app_*`` once it has nothing more to send, and the socket sends
its FIN as soon as that token is in, the ring is empty and
everything sent is acknowledged. Because both tokens travel in the
streams they cannot overtake data: a wire returns the token behind
the last echoed byte, and so does anything with a register slice or
a dual-clock FIFO between the streams, with no pipeline bookkeeping
in the application. A token sent while the connection is up but
before the peer's FIN is harmless and takes effect then; one sent
while ``tx_open`` is low is discarded with everything else. An
active close from ``ESTABLISHED`` — the
``FIN_WAIT`` states — and an active open are the extension that makes
a client out of this block; they add states to the connection
machine and change neither stream.

A connection ends in ``CLOSED``, whether by the peer's
acknowledgement of our FIN, a reset, or the socket giving up; the
machine stays there until the socket reports the clean-up done. The
clean-up is: the reset owed to the peer sent, if any; the transmit
ring dropped, bytes the application had not yet sent lost, as on a
closed socket; the receive buffer flushed frame by frame — a segment
in delivery on ``m_app_*`` finishes to its ``tlast``, the committed
ones behind it are read and discarded, until ``level`` reads zero;
the connection record cleared. Data the old peer
sent that the application had not yet read is discarded, the reset
semantics; after a clean close there is none, since our FIN needed
the application's token, which follows the last delivered byte.

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
  its own area and timing numbers; its README is the contract.
  Inputs are one-cycle events the receive walker has qualified
  against the connection record — ``syn_rx``, ``ctl_acked``,
  ``fin_rx``, ``rst_rx`` — the ``give_up`` pulse from the timer side
  (retry budget spent or idle limit reached), and three levels the
  socket computes: ``listen``, tied high; ``close_ready``, which is
  the application's close token received with the ring empty and
  everything acknowledged;
  ``clear_done``, the clean-up above finished. Outputs are the
  seven Moore levels the socket's engines act on: ``clear``,
  ``listening``, ``syn_ack_pending``, ``connected``, ``rx_open``,
  ``tx_open``, ``fin_pending``.
- **Receive walker** — its own component, `tcp_rx_parser
  <../tcp_rx_parser/README.rst>`_, verified against the model like the
  others. ``IDLE``, ``HEADER``, ``OPTIONS``, ``PAYLOAD``, ``DROP``: it
  decodes and validates one segment and streams its payload, and knows
  nothing of the connection. The socket wraps it with the record
  match, the in-order and window decisions, the events it raises for
  the connection machine, the acknowledgement-owed flag and the reset
  request, and the receive FIFO write with the walker's payload doom
  folded into the socket's not-accepted decision.
- **Transmit walker** — its own component, `tcp_tx_frame
  <../tcp_tx_frame/README.rst>`_, so it is verified against the
  bench-side model on its own, like the connection machine. ``IDLE``,
  ``SUM``, ``HEADER``, ``PAYLOAD``: it emits one frame of the kind the
  scheduler hands it, from the header fields and a payload it reads
  back from the ring; a segment without payload leaves ``HEADER`` for
  ``IDLE`` directly, and ``SUM`` is entered only with a payload to
  scan.
- **Transmit scheduler** — not a machine. A priority encoder over
  the booleans of the priority above: a reset owed, a pending
  SYN-ACK or FIN on its rising edge or on expiry, a resend or probe
  on expiry, data ready within the window, an acknowledgement owed
  past its hold-off. When the walker is idle the encoder's choice is
  latched as the segment kind and handed over; when the walker
  reports done, the side effects keyed on that kind fire — the send
  pointer advanced by the scanned length, the acknowledgement-owed
  flag or the reset request cleared, the timer restarted, the retry
  counted. A kind register, an in-flight flag and decode, with no
  sequence of its own; the walker's ``IDLE`` is the only wait.

Three machines in all, then: the connection machine in its own
component, and the two walkers here.

Parameters
----------

- ``LOG2_RX_DEPTH``: receive buffer size in bytes, log2 (default 11 —
  2048 bytes; the largest window advertised; at least ``MSS``).
- ``LOG2_RX_FRAMES``: receive buffer capacity in segments, log2
  (default 6 — 64 segments not yet read by the application; a
  segment arriving with none free is refused and resent by the peer).
- ``LOG2_TX_DEPTH``: transmit ring size in bytes, log2 (default 11 —
  2048 bytes; bounds the unacknowledged data; at least ``MSS``).
- ``MSS``: maximum segment size advertised in the SYN-ACK, and the
  socket's own bound on the effective MSS (default 1460, the 1500
  MTU; at most 16 bits).
- ``RTO_CLOCKS``: retransmission and persist timeout in clock cycles
  (default 10 000 000 — 200 ms at 50 MHz).
- ``MAX_RETRIES``: consecutive retransmissions or unanswered probes
  before the connection is given up (default 8).
- ``IDLE_CLOCKS``: clock cycles without an acceptable segment from
  the peer before the connection is given up (default
  30 000 000 000 — 10 minutes at 50 MHz; 0 disables).
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
- ``m_app_tdata`` (8 bits), ``m_app_tuser``, ``m_app_tvalid``,
  ``m_app_tlast``, ``m_app_tready``: AXI stream master to the
  application, received payload in order, ``tlast`` on the last byte
  of each segment; a beat with ``tuser`` high is the close token, the
  end of the stream, ``tdata`` to be ignored.
- ``s_app_tdata`` (8 bits), ``s_app_tuser``, ``s_app_tvalid``,
  ``s_app_tlast``, ``s_app_tready``: AXI stream slave from the
  application, bytes to send, ``tlast`` sends what is waiting now; a
  beat with ``tuser`` high is the application's close token, ``tdata``
  ignored. On these two streams ``tuser`` means close, not the drop
  or abort it means on every network stream of the chain.
- ``connected``: a connection is up, ``ESTABLISHED`` to ``LAST_ACK``.
- ``peer_ip`` (32 bits), ``peer_port`` (16 bits): the connected peer,
  valid while ``connected`` is high.
