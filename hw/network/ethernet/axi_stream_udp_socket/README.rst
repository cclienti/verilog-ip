AXI Stream UDP Socket
======================

Description
-----------

One UDP listener between the IPv4 layer and an application, on
``listen_port``, with the application side as a pair of byte streams:
each datagram received is delivered whole on ``m_app_*``, ``tlast`` its
last byte; each datagram the application presents whole on ``s_app_*``,
``tlast`` sends it. There is no connection: RFC 768 has none, so there
is no handshake, no sequence space, no retransmission and no window
here, and nothing in this socket resembles the `TCP socket
<../axi_stream_tcp_socket/README.rst>`_'s connection record beyond the
shared IPv4/Ethernet framing.

That also means there is no single peer to remember across bytes, the
way the TCP socket remembers one for a connection's life: a datagram in
may come from one correspondent and the reply may need to go to
another, or to several in turn. The peer address travels beside the
stream instead of living in a record — ``m_app_peer_mac`` /
``m_app_peer_ip`` / ``m_app_peer_port`` accompany a received datagram
exactly as the IPv4 parser's own side-bands accompany a segment,
sampled with its first beat and stable to its last; ``s_app_dst_mac`` /
``s_app_dst_ip`` / ``s_app_dst_port`` are the mirror going out, sampled
the same way. Wiring all six alongside the data, ``tvalid``, ``tlast``
and ``tready`` — the whole datagram, address included — straight from
``m_app`` back to ``s_app`` makes a UDP echo server, ``nc -u`` or any
client on ``listen_port``; the socket captures the sender's MAC as
delivered to it, and never resolves one itself, exactly as the TCP
socket never ARPs on its transmit path — a reply can only go to a
peer this socket has itself heard from.

::

  s_axi_* ──► receive walker ──► receive buffer ──► m_app_*
  side-bands   validate,          packet FIFO,        payload, tlast
               checksum            commit/rollback,    per datagram
                                    peer mac/ip/port    m_app_peer_*
                                    riding as INFO
  m_axi_* ◄── transmit walker ◄── transmit buffer ◄── s_app_*
  complete      header image,      packet FIFO,         payload, tlast
  frames        payload            dst mac/ip/port      per datagram
                                    and checksum riding  s_app_dst_*
                                    as INFO

Two straight-through walkers around two `axi_stream_packet_fifo
<../../../lib/axi_stream_packet_fifo/README.rst>`_ instances, not two
engines meeting in a shared record: every datagram is independent, so
nothing here needs to remember one across the next. Each FIFO's
``INFO_WIDTH`` side-band — sampled on the committing beat, stable for
the whole output frame, exactly the mechanism the TCP socket's own
receive buffer uses for commit/rollback — carries the address fields
and, on the transmit side, the precomputed checksum, so neither walker
ever re-reads a datagram it has already streamed once. That is the one
respect in which this socket is simpler than the TCP transmit engine:
with no retransmission, a datagram is read from its buffer exactly
once, to emit it.

Given how little of the TCP socket's complexity applies — no
connection machine, no ring, no scheduler, no timers — the two walkers
stay inside this one component rather than becoming separate blocks
the way `tcp_rx_parser <../tcp_rx_parser/README.rst>`_ and `tcp_tx_frame
<../tcp_tx_frame/README.rst>`_ did: each is a handful of states, and
splitting them would trade one small, comprehensible file for three.
Both are still written and verified as the project's clean, explicit
FSMs (see State machines below), checked against a bench-side model of
their own, `udp_model_pkg <../udp_model/README.rst>`_, the same
verification discipline the TCP components use, just not the same
number of files.

Receive
-------

A datagram is validated on the fly: at least 8 bytes (the UDP header),
its length field equal to ``s_length`` exactly — the IPv4 layer has
already cut the datagram at ``total_length``, so a real stack's length
field is always redundant with it, and a mismatch is not something a
real stack ever sends — a destination equal to ``local_ip`` (the parser
also passes limited broadcast, dropped here as in the TCP socket and
the ICMP responder), a destination port equal to ``listen_port``, and a
checksum over the pseudo-header, header and data that verifies, unless
the received checksum field is zero: RFC 768 defines that as "no
checksum", to be accepted unconditionally, not as a sum that happens to
verify. Anything else — the wrong port, a foreign or broadcast
destination, a structurally short header — is silently dropped: no
ICMP Port Unreachable is generated, the datagram simply disappears, as
UDP allows and as a real stack's peer must already tolerate. Generating
one is a documented, not implemented, extension, in the same spirit as
the TCP socket's deferred fast retransmit; it would need the ICMP layer
to build an error reply carrying the offending IP header and first
eight payload bytes, a capability `axi_stream_icmp_echo
<../axi_stream_icmp_echo/README.rst>`_ does not have.

The checksum accumulator folds every byte as it arrives, the same
technique `tcp_rx_parser <../tcp_rx_parser/README.rst>`__ uses and for
the same reason — RFC 1071 allows folding at any point in a
ones'-complement sum, so growing an accumulator to 32 bits and folding
twice at the end buys nothing a single running fold does not, and
costs a wider adder on every path. The pseudo-header's terms fold into
the same running value on the first byte rather than being reduced on
their own first, since ``s_src_ip``/``s_dst_ip`` only become valid on
the cycle the first byte is accepted — the mistake made once already
on the TCP side and documented there.

The verdict is known only on the last byte, so the payload is written
speculatively into the receive buffer, an ``axi_stream_packet_fifo``
whose commit/rollback is exactly the mechanism needed, and doomed with
``tuser`` when the checksum fails. Its ``INFO_WIDTH`` word carries the
sender's MAC, IP and port, sampled at the header and committed with the
frame; it rides through to ``m_app_peer_mac``/``m_app_peer_ip``/
``m_app_peer_port``, stable for the whole delivered datagram. A
datagram whose payload does not fit the free space, or which arrives
with no frame slot free, is not written and not answered — UDP has
nothing resembling an acknowledgement to withhold, so there is nothing
to do but let it be lost, which is exactly what a real network already
does to a UDP datagram under load. The fit is checked at the header,
before writing, the same discipline the TCP socket uses for the same
reason: the frame in flight is never left unaccounted for.

Transmit
--------

Bytes the application presents on ``s_app_*``, with
``s_app_dst_mac``/``s_app_dst_ip``/``s_app_dst_port`` stable from the
first beat, enter a second ``axi_stream_packet_fifo`` and commit on
``tlast``; there is no close token and no ``tuser`` on this stream, and
none is needed — a datagram is already delimited by ``tlast``, and UDP
has no connection to close. Its ``INFO_WIDTH`` word carries the
destination address together with the datagram's own checksum, folded
byte by byte exactly as the receive side folds an incoming one, with
the pseudo-header and UDP header terms — ``local_ip``, the destination
address, ``listen_port`` as the source port, and the length, known
exactly on the committing beat — folded in the same way. RFC 768's one
edge case is honoured: a computed checksum of all zero bits is sent as
all one bits, since zero on the wire means "no checksum". Because the
checksum is complete before the commit, the walker never reads a
datagram back to sum it the way the TCP transmit engine does for a
retransmission it cannot avoid — nothing here is ever sent twice, so
one read suffices.

A datagram larger than ``2**LOG2_TX_DEPTH`` bytes deadlocks the writer
exactly as an oversized frame does in any ``axi_stream_packet_fifo``
used in backpressure mode; keeping datagrams within the buffer is the
application's obligation, as it already must be to stay within a
1500-byte MTU with ``DF`` set.

The transmit walker has nothing to arbitrate: with no resets, no
control segments and no retries, its only decision is whether a
committed datagram is waiting, so it is a plain poll of the transmit
buffer's frame count, not the priority scheduler the TCP socket needs.
When one is waiting, the walker pops it, builds the fixed 42-byte
Ethernet+IPv4+UDP header image — there are no options and no variable
field, unlike TCP's data offset, so the image and its layout never
change — and streams header then payload, one byte per cycle, exactly
as the TCP transmit engine does. Destination MAC and IP, and the
checksum, come from the FIFO's ``INFO_WIDTH`` word; length from
``m_length``, the FIFO's own frame-length output, plus the 8-byte UDP
header.

The header fields: destination MAC and IP from the FIFO's ``INFO_WIDTH``
word, source MAC and IP ``local_mac``/``local_ip``, EtherType
``0x0800``; in the IP header, version and IHL ``0x45``, TOS zero, total
length from the UDP length, identification zero (``DF`` set, RFC
6864), flags ``DF`` alone, offset zero, TTL 64, protocol ``0x11``; in
the UDP header, source port ``listen_port``, destination port and
checksum from the ``INFO_WIDTH`` word, length as above. The Ethernet
and IP prepend is the fourth copy of the same logic in this tree, after
the `ARP <../axi_stream_eth_arp/README.rst>`_, `ICMP
<../axi_stream_icmp_echo/README.rst>`_ and TCP transmit paths; the
shared block a refactor would extract, noted in the TCP socket's own
README, would serve this one too.

Measured on the `Zedboard UDP endpoint
<../../../boards/zedboard/udp_endpoint/README.rst>`_ (Vivado 2026.1,
the -1 part): the transmit fold above, three terms wide on a
one-byte datagram's single beat, appears nowhere in the timing report
— no ``tx_fold``, ``tx_checksum`` or ``txf_s_info`` net on any listed
path. The receive fold does appear, as the middle segment of the
build's critical path, but not as its own bottleneck: the front
receive packet FIFO's look-ahead valid logic, the path the TCP build
already leaves alone, runs through the whole parser chain and back,
and this fold is on it because the doom flag depends on the verdict
and the receive buffer's ``tready`` is combinational on the doom. The
TCP receive parser sits on the same path in the same way; the 89 ps
between the two builds' fabric slacks is placement.

State machines
---------------

Both walkers keep the project's clean, explicit style: an enumerated
state, one registered process, one next-state process, one outputs
process, Moore outputs, no state hidden in a counter.

- **Receive walker** — ``IDLE``, ``HEADER`` (the 8 UDP header bytes,
  decoding and starting the checksum fold), ``PAYLOAD`` (streamed to
  the receive buffer, the fit already checked at the header), ``DROP``
  (a datagram shorter than 8 bytes, consumed with nothing stored). The
  byte counter, the header fields and the checksum accumulator are
  datapath.
- **Transmit walker** — ``IDLE`` (polling the transmit buffer's frame
  count), ``HEADER`` (the fixed 42-byte image, streamed by byte
  index), ``PAYLOAD`` (streamed from the transmit buffer). No ``SUM``
  state: the checksum is already complete in the FIFO's ``INFO_WIDTH``
  word by the time ``HEADER`` needs it.

Parameters
----------

- ``LOG2_RX_DEPTH``: receive buffer size in bytes, log2 (default 11 —
  2048 bytes).
- ``LOG2_RX_FRAMES``: receive buffer capacity in datagrams, log2
  (default 6 — 64 datagrams not yet read by the application).
- ``LOG2_TX_DEPTH``: transmit buffer size in bytes, log2 (default 11 —
  2048 bytes; the largest datagram the application may send).
- ``LOG2_TX_FRAMES``: transmit buffer capacity in datagrams, log2
  (default 6 — 64 datagrams not yet sent).

Signals
-------

- ``clock``, ``sreset``: clock and synchronous reset, active high.
- ``local_mac`` (48 bits), ``local_ip`` (32 bits), ``listen_port``
  (16 bits): endpoint identity and the listening port, live inputs —
  there being no connection, nothing here is ever sampled and held.
- ``s_axi_tdata`` (8 bits), ``s_axi_tuser``, ``s_axi_tvalid``,
  ``s_axi_tlast``, ``s_axi_tready``: AXI stream slave, UDP datagrams
  from the IPv4 demux.
- ``s_src_ip`` (32 bits), ``s_dst_ip`` (32 bits), ``s_length``
  (16 bits), ``s_src_mac`` (48 bits): parser side-bands, stable for the
  whole datagram, sampled with its first beat.
- ``m_axi_tdata`` (8 bits), ``m_axi_tuser``, ``m_axi_tvalid``,
  ``m_axi_tlast``, ``m_axi_tready``: AXI stream master, complete
  Ethernet frames; ``m_axi_tuser`` is constant zero.
- ``m_app_tdata`` (8 bits), ``m_app_tvalid``, ``m_app_tlast``,
  ``m_app_tready``: AXI stream master to the application, one received
  datagram's payload per frame, ``tlast`` its last byte.
- ``m_app_peer_mac`` (48 bits), ``m_app_peer_ip`` (32 bits),
  ``m_app_peer_port`` (16 bits): the sender of the datagram on
  ``m_app_*``, stable for its whole frame.
- ``s_app_tdata`` (8 bits), ``s_app_tvalid``, ``s_app_tlast``,
  ``s_app_tready``: AXI stream slave from the application, one
  datagram's payload per frame, ``tlast`` sends it.
- ``s_app_dst_mac`` (48 bits), ``s_app_dst_ip`` (32 bits),
  ``s_app_dst_port`` (16 bits): the destination of the datagram on
  ``s_app_*``, sampled with its first beat.

Testing
-------

Test the echo with ``nc -u``: unlike TCP there is no stream to
misinterpret with option negotiation, so nothing here needs the
``telnet``-before-``nc`` caution the TCP socket's README carries.

The bench drives datagrams built by ``udp_model_pkg`` into a small
64-byte, four-datagram receive and transmit buffer, with ``m_app``
wired straight back to ``s_app``, address fields included, so the
socket is an echo server. It walks a basic round trip, then every
rejection this README describes — the wrong port, a broadcast
destination, a bad checksum, a checksum field of zero with a payload
byte a real checksum would have caught, a ``tuser`` mid-datagram, a
length field that disagrees with ``s_length``, a datagram shorter than
a header, and a payload larger than the buffer — each checked to leave
no reply and the socket able to answer the next datagram cleanly
afterward. A dedicated scenario holds the application off to fill all
four receive frame slots, confirms a fifth datagram is dropped for
want of one, and that releasing the application drains exactly the
four that fit; a directed vector, found by search against this
bench's own addresses the way the TCP checksum's directed vectors
were, exercises RFC 768's computed-zero-sent-as-all-ones edge case in
hardware. Sixty random round trips close it out, payload length and
content random, checksum enabled and disabled about equally. 277
checks, ALL TESTS PASSED under ``check.iverilog`` and
``check.verilator``, ``lint.verilator`` clean. Mutation-tested: the
no-checksum bypass, the length-field check, the destination-port
check, the checksum's one's-complement, its RFC 768 substitution, the
length term folded into it, and a byte's halfword placement each fail
the bench; removing the not-accepted or no-free-frame-slot dooming
does not just fail a check, it deadlocks the writer against a full
buffer, exactly the failure mode the receive buffer's own README
warns an oversized or misrouted frame invites without it.
