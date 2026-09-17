UDP Model Package
==================

Description
-----------

A bench-side model of UDP over IPv4 over Ethernet, byte exact, for the
testbenches of the `UDP socket <../axi_stream_udp_socket/README.rst>`_
and of the endpoint around it. ``udp_model_pkg`` is a SystemVerilog
package of pure functions on dynamic byte arrays: build a datagram, an
IPv4 packet or a whole Ethernet frame from a header record and a
payload, checksum included; parse and validate one back. Not
synthesizable, and not meant to be.

It exists for the same reason `tcp_model_pkg
<../tcp_model/README.rst>`_ does — so the socket's RTL is written
against something it shares nothing with — and is deliberately its own
package rather than an extension of it: the two duplicate a handful of
generic helpers (the byte-string utilities, the ones'-complement
arithmetic, the IPv4 header checksum, the Ethernet/IPv4 builders and
parser), but a UDP-only endpoint's bench should not need to compile
TCP's model to get IPv4 support, and coupling two protocol models that
otherwise share nothing would cost more than the duplication does. The
checksums are taken over the bytes of a finished header by the RFC
1071 recipe, and the self-check anchors the builders to five whole
frames produced by ``project/gen_vectors.py``, a pure Python
implementation, and the IPv4 checksum to the same published textbook
example ``tcp_model_pkg`` uses.

The record type ``udp_hdr_t`` is a packed struct carrying every field
of the three headers. ``no_checksum`` is not a wire field but a
build-side request — RFC 768's "no checksum", sent as an all-zero
checksum field — that ``parse_udp`` also reports back through, so a
round trip through build and parse preserves it. A byte string is
``bytes_t``, a dynamic array of bytes, with helpers to slice,
concatenate, compare, print and decode from hex, identical to the ones
in ``tcp_model_pkg``.

Functions
---------

- ``build_udp(h, payload)``: the L4 unit, header, payload, checksum in
  place unless ``h.no_checksum`` — what the IPv4 parser delivers to the
  socket. RFC 768's edge case is handled: a computed checksum of zero
  is sent as all ones, found by search and checked directly, the same
  way the TCP model's directed vectors were found.
- ``build_ipv4(h, l4)``, ``build_eth(h, ip)``, ``build_frame(h,
  payload)``: the layers above, the last one a complete frame without
  FCS, what the socket emits.
- ``parse_frame(f, h, err)``: validates a frame — lengths, EtherType,
  version/IHL, no fragment, protocol, both checksums — fills the record
  and returns 1, or returns 0 with the reason in ``err``. Padding
  beyond ``total_length`` is tolerated, as the receive chain tolerates
  it. ``frame_payload(f)`` and ``frame_l4(f)`` slice an accepted frame.
- ``parse_udp(src_ip, dst_ip, dgram, h, err)``: the same for an L4 unit
  with the pseudo-header addresses supplied beside it, the socket's own
  input, including the length-field-equals-the-unit's-own-size check
  the socket's RTL applies; ``udp_payload(dgram)`` slices it.
- ``ip_checksum``, ``udp_checksum``, ``ones_sum``, ``csum_fold``,
  ``csum_verifies``: the arithmetic, exposed for a bench that assembles
  a header the builders do not produce.
- ``hdr_str``, ``bytes_hex``: text for messages.

Build order
-----------

A package must be compiled before the file that imports it, and the
makefiles sort sources by path. ``common.mk`` therefore moves every
file named ``*_pkg.sv`` to the front of the lists; that suffix is the
convention a package must follow here. A bench that uses the model
lists ``../../udp_model`` in ``TESTBENCH_DEPS`` and imports
``udp_model_pkg::*``.

Testing
-------

``make check.iverilog`` and ``make check.verilator`` run the
self-check: the published IPv4 checksum example, the checksum fold
forced through its double carry, the hex decoder's odd-length and
bad-char rejection, the five golden frames built and parsed, the
computed-zero checksum sent as all ones, the L4 unit parsed with its
pseudo-header, eleven single-byte damages each refused with the
expected reason including the UDP length-field mismatch the socket's
RTL also checks, a short L4 unit fed straight to ``parse_udp`` for its
own length guard, a padded and a truncated frame, and three hundred
random round trips through build and parse with the checksum enabled
and disabled both. 1555 checks, ALL TESTS PASSED under
``check.iverilog`` and ``check.verilator``. Mutation-tested: the
protocol constant, the RFC 768 zero-checksum substitution, the length
field comparison, the no-checksum bypass, the checksum fold's
complement and the pseudo-header's address order each fail the bench.
To add a vector, extend ``VECTORS`` in ``gen_vectors.py``, run it, and
paste its output into the bench.
