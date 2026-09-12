TCP Model Package
=================

Description
-----------

A bench-side model of TCP over IPv4 over Ethernet, byte exact, for the
testbenches of the `TCP socket <../axi_stream_tcp_socket/README.rst>`_
and of the `endpoint <../rmii_eth_endpoint/README.rst>`_ around it.
``tcp_model_pkg`` is a SystemVerilog package of pure functions on
dynamic byte arrays: build a segment, an IPv4 packet or a whole
Ethernet frame from a header record and a payload, both checksums
included; parse and validate one back, checksums verified, options
walked; and the sequence-space arithmetic a peer needs. Not
synthesizable, and not meant to be.

It exists so that the socket's RTL is written against something it
shares nothing with. The ICMP echo's bench once went blind because
bench and RTL used the same faulty checksum expression; here the
checksums are taken over the bytes of a finished header by the RFC
1071 recipe, and the self-check anchors the builders to nine whole
frames produced by ``project/gen_vectors.py``, a pure Python
implementation, and the IPv4 checksum to the published textbook
example. A bench that compares the socket's output against
``build_frame`` is therefore comparing against an independent stack.

The record type ``tcp_hdr_t`` is a packed struct carrying every field
of the three headers, MSS option included (zero means no option), so
it crosses function boundaries in every simulator. A byte string is
``bytes_t``, a dynamic array of bytes, with helpers to slice,
concatenate, compare, print and decode from hex.

Functions
---------

- ``build_tcp(h, payload)``: the L4 unit, header, MSS option when
  ``h.mss`` is non-zero, payload, checksum in place — what the IPv4
  parser delivers to the socket.
- ``build_ipv4(h, l4)``, ``build_eth(h, ip)``, ``build_frame(h,
  payload)``: the layers above, the last one a complete frame without
  FCS, what the socket emits.
- ``parse_frame(f, h, err)``: validates a frame — lengths, EtherType,
  version/IHL, no fragment, protocol, both checksums, data offset,
  options — fills the record and returns 1, or returns 0 with the
  reason in ``err``. Padding beyond ``total_length`` is tolerated, as
  the receive chain tolerates it. ``frame_payload(f)`` and
  ``frame_l4(f)`` slice an accepted frame.
- ``parse_tcp(src_ip, dst_ip, seg, h, err)``: the same for an L4 unit
  with the pseudo-header addresses supplied beside it, the socket's
  own input; ``tcp_payload(seg)`` slices it.
- ``ip_checksum``, ``tcp_checksum``, ``ones_sum``, ``csum_fold``,
  ``csum_verifies``: the arithmetic, exposed for a bench that assembles
  a header the builders do not produce.
- ``seg_len(h, payload_len)``: sequence numbers a segment consumes;
  ``seq_lt``, ``seq_le``: modular comparisons.
- ``flags_str``, ``hdr_str``, ``bytes_hex``: text for messages.

Build order
-----------

A package must be compiled before the file that imports it, and the
makefiles sort sources by path. ``common.mk`` therefore moves every
file named ``*_pkg.sv`` to the front of the lists; that suffix is the
convention a package must follow here. A bench that uses the model
lists ``../../tcp_model`` in ``TESTBENCH_DEPS`` and imports
``tcp_model_pkg::*``.

Testing
-------

``make check.iverilog`` and ``make check.verilator`` run the
self-check: the published checksum example, the checksum fold forced
through its double carry, the hex decoder's odd-length and bad-char
rejection, the nine golden frames built and parsed, the L4 unit parsed
with its pseudo-header, twelve single-byte damages each refused with
the expected reason plus a padded and a truncated frame, a short L4
unit fed straight to ``parse_tcp`` for its own length guard, option
lists the builder never produces (NOPs, window scale, EOL, a length
past the header, a kind with no length byte, and an MSS option of the
wrong length), three hundred random round trips through build and
parse, and the sequence-space functions around the wrap. Every branch
is reached: the four cases above were added after a review found them
uncovered, each confirmed to kill a mutant of the guard it exercises.
To add a vector, extend ``VECTORS`` in ``gen_vectors.py``, run it, and
paste its output into the bench.
