AXI Stream Packet FIFO
======================

Description
-----------

Store-and-forward packet FIFO with commit/rollback semantics. Frames are
written speculatively into a dual-port RAM (`dpmemrf
<../dpmemrf/README.rst>`_): a clean ``tlast`` commits the frame, and
``tuser`` on any beat dooms it — the write pointer rolls back at
``tlast`` and the frame is reclaimed in one cycle. The read side
therefore only ever produces complete, valid frames and carries no
``tuser`` at all. This is the component that turns a flagged stream
(such as an Ethernet receive path, where the FCS verdict only arrives at
the end of the frame) into a stream a consumer can parse without any
abort handling.

An ``INFO_WIDTH`` side-band word (``s_info``, sampled on the committing
beat) and the frame length in beats ride in an internal per-frame FIFO;
``m_info``/``m_length`` are stable for the whole output frame, so the
consumer knows the length from the first beat and can never pop out of
step.

Two overflow policies:

- ``DROP_ON_FULL = 0`` backpressures and never loses a frame.
  ``s_axi_tready`` is combinational on ``s_axi_tuser`` (a doomed beat
  needs no room and is always consumed). Every frame must fit in the
  FIFO: a larger one deadlocks the writer — permanently once no older
  committed frame is left for the reader to drain, since the oversize
  frame itself can never commit.
- ``DROP_ON_FULL = 1`` never backpressures (``s_axi_tready`` is constant
  one, for line-rate sources like a MAC receiver): a frame that meets a
  full data or info FIFO is dropped whole, committed frames untouched,
  which also disposes of frames larger than the FIFO.

Latency is store-and-forward: a frame becomes visible to the reader once
committed, two cycles after its last beat.

Parameters
----------

- ``DATA_WIDTH``: beat width (default 8).
- ``LOG2_DEPTH``: data FIFO depth in beats, log2 (default 11 = 2048).
- ``LOG2_FRAMES``: committed-frame capacity, log2 (default 6 = 64, so
  with the default depth the data FIFO is the binding limit for any
  frame of 32 bytes or more — the info FIFO never fills first for legal
  Ethernet frames).
- ``INFO_WIDTH``: side-band word width (default 1; tie ``s_info`` low
  and ignore ``m_info`` when unused).
- ``DROP_ON_FULL``: overflow policy, see above (default 0).

Signals
-------

- ``clock``, ``sreset``: clock and synchronous reset, active high.
- ``s_axi_*``: AXI stream slave; ``s_axi_tuser`` dooms the frame;
  ``s_info`` is the side-band word.
- ``m_axi_*``: AXI stream master, complete valid frames only.
- ``m_info``, ``m_length``: per-frame side-band and length in beats,
  stable for the whole frame.
