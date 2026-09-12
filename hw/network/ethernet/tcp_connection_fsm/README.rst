TCP Connection FSM
==================

Description
-----------

The connection state machine of the `TCP socket
<../axi_stream_tcp_socket/README.rst>`_, the passive-server half of
the RFC 793 diagram, as a component of its own: ``CLOSED``,
``LISTEN``, ``SYN_RCVD``, ``ESTABLISHED``, ``CLOSE_WAIT``,
``LAST_ACK``. It holds no sequence number, no timer and no buffer —
those are the socket's datapath — and sees the network only as
events the socket's receive walker has already qualified against the
connection record. Its outputs are levels decoded from the state,
which the socket's engines turn into work: send a SYN-ACK, store
data, send a FIN, clear the record. This README is the contract
between the two; the socket README describes the machine only by
reference to it.

It is separate so that a version produced by an FSM synthesis tool
drops in without touching the socket, runs against the same
testbench, and gets its own area and timing figures. The
hand-written version follows the extraction rules the socket README
states: one enumerated state, one registered process, one next-state
process, one outputs process, Moore outputs throughout, every state
named in the case and a default that recovers to ``CLOSED``, and no
counter or arithmetic in the transition conditions.

Transitions
-----------

Events are one-cycle pulses — the four segment events registered by
the receive walker on the last beat of a segment, ``abort`` by the
timer side — so at most one segment's events arrive per cycle and
several of them may be set together — a FIN rides on an ACK, the
socket gives up in any state. The machine resolves them in a fixed
order: ``rst_rx`` first, then ``abort``, then the event the current
state waits for. A pulse a state does not wait for is ignored: a SYN
outside ``LISTEN`` is the walker's business (a reset for a foreign
peer, a challenge ACK for the connected one), an ACK in
``ESTABLISHED`` only moves the transmit ring, and ``fin_rx`` cannot
occur in ``SYN_RCVD`` because the walker accepts a FIN only under
``rx_open``, like data, and leaves one it does not accept
unacknowledged for the peer to retransmit.

::

  CLOSED      --listen & clear_done----> LISTEN
  LISTEN      --syn_rx-----------------> SYN_RCVD
  SYN_RCVD    --ctl_acked--------------> ESTABLISHED
  ESTABLISHED --fin_rx-----------------> CLOSE_WAIT
  CLOSE_WAIT  --close_ready------------> LAST_ACK
  LAST_ACK    --ctl_acked--------------> CLOSED
  any but CLOSED, LISTEN
              --rst_rx-----------------> CLOSED
              --abort------------------> CLOSED

``ctl_acked`` is the walker's verdict that the peer acknowledged the
control segment outstanding in the current state — the SYN-ACK in
``SYN_RCVD``, the FIN in ``LAST_ACK`` — which is why one event serves
both. A FIN carried by the handshake ACK itself is not accepted in
``SYN_RCVD``: the ACK moves the machine to ``ESTABLISHED`` and the
peer retransmits the FIN into it, one round trip later on a path that
is rare; the alternative, an arc from ``SYN_RCVD`` to ``CLOSE_WAIT``,
would have to accept a FIN behind data the state drops.

``CLOSED`` is where the socket cleans up — the reset owed to the
peer sent, the ring dropped, the receive buffer flushed frame by
frame, the record cleared — and the machine stays there until the
socket reports ``clear_done``; ``listen`` is tied high by the socket
and exists so that an active open, a later extension, has somewhere
to start from. A reset in ``SYN_RCVD`` also goes through ``CLOSED``
rather than straight back to ``LISTEN``, so that the clean-up is one
place. ``close_ready`` is the socket's verdict that its own FIN may
go: the application's close token has been received, the ring is
empty, everything sent is acknowledged. ``abort`` is the socket giving the
connection up — retransmission budget spent, idle limit reached — and
arrives from the timer side, not from the walker.

Outputs
-------

All Moore, each the decode of one or more states. The socket's
transmit scheduler turns the two ``*_pending`` levels into a send on
their rising edge and repeats on the retransmission timer while they
stay high; that edge detection lives in the socket, so the machine
emits no pulse and needs no entry state.

==================== ========= ========= ============ ============= ============ =========
Output               CLOSED    LISTEN    SYN_RCVD     ESTABLISHED   CLOSE_WAIT   LAST_ACK
==================== ========= ========= ============ ============= ============ =========
``clear``            1         0         0            0             0            0
``listening``        0         1         0            0             0            0
``syn_ack_pending``  0         0         1            0             0            0
``connected``        0         0         0            1             1            1
``rx_open``          0         0         0            1             0            0
``tx_open``          0         0         0            1             1            0
``fin_pending``      0         0         0            0             0            1
==================== ========= ========= ============ ============= ============ =========

``rx_open`` is ``ESTABLISHED`` only: data carried by the handshake
ACK itself is dropped and the peer retransmits it, which spares the
walker a store in ``SYN_RCVD``. ``tx_open`` stays high in
``CLOSE_WAIT`` — the peer has finished sending, the application has
not — and drops in ``LAST_ACK``, after the socket has decided the
ring is empty. ``connected`` is the socket's ``connected`` port.
``clear`` holds for as long as the clean-up takes, since ``CLOSED``
waits for ``clear_done``.

Benchmark note
--------------

Vivado extracts and re-encodes state machines on its own
(``fsm_encoding``), which would blur a comparison between two
descriptions of the same machine; pin the encoding or disable the
extraction on both sides when measuring, and say which in the commit.

Parameters
----------

None.

Signals
-------

- ``clock``, ``sreset``: clock and synchronous reset, active high;
  reset lands in ``CLOSED``.
- ``listen``: level, leave ``CLOSED`` for ``LISTEN`` once the clean-up
  is done; tied high by the socket.
- ``clear_done``: level, the socket has finished the clean-up
  ``clear`` asked for.
- ``syn_rx``: pulse, an acceptable SYN for the listening port arrived
  (no ACK, no RST, validated by the walker).
- ``ctl_acked``: pulse, the peer acknowledged the control segment
  outstanding in the current state.
- ``fin_rx``: pulse, an in-order FIN from the connected peer arrived.
- ``rst_rx``: pulse, an acceptable RST from the connected peer
  arrived.
- ``abort``: pulse, the socket gives the connection up —
  retransmission budget spent or idle limit reached.
- ``close_ready``: level, the socket may send its FIN — the
  application's close token received, transmit ring empty, everything
  sent acknowledged.
- ``clear``: level, ``CLOSED``; the socket sends the reset it owes,
  drops the ring, flushes the receive buffer and clears the record.
- ``listening``: level, ``LISTEN``; the walker may accept a SYN and
  sample the identity.
- ``syn_ack_pending``: level, ``SYN_RCVD``; a SYN-ACK is owed.
- ``connected``: level, ``ESTABLISHED`` to ``LAST_ACK``; the
  connection record is valid.
- ``rx_open``: level, ``ESTABLISHED``; in-order data is stored and
  delivered.
- ``tx_open``: level, ``ESTABLISHED`` and ``CLOSE_WAIT``; application
  bytes are accepted and sent.
- ``fin_pending``: level, ``LAST_ACK``; a FIN is owed.
