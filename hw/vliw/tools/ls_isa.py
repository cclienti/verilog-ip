#!/usr/bin/env python3
# SPDX-License-Identifier: CERN-OHL-P-2.0
# Copyright (c) 2026 Christophe Clienti
"""Single source of truth for the VLIW Load/Store slot encoding.

The tables below mirror LOAD_STORE.md sections 2.1 (operand rails), 3.1
(field positions and opcode map) and 10.2 (dual-access tier).  Everything
else -- the specification tables, the assembler reference listing and the
RTL decode parameters -- is generated from them, so the doc, the RTL and
the toolchain cannot drift apart.

Run with --help for the available actions (--check, --check-doc, --test,
--asm, --md, --sv, --decode), and -o to write a generated view to a file.

Extending to the other slots (ALU, CTRL) means adding their FIELDS /
FORMATS / INSTRUCTIONS tables; the checkers and emitters are generic.
"""

import argparse
import contextlib
import io
import os
import re
import sys
import textwrap
import unittest

SLOT_WIDTH = 36

# Register-file geometry: 5 banks of 32 registers, one write port and ten
# read ports per bank (the read ports are LUTRAM replicas, so any read
# reaches any bank). A source address is BANK_SEL_BITS + REG_SEL_BITS.
NUM_BANKS      = 5
REG_SEL_BITS   = 5
BANK_SEL_BITS  = 3
SRC_ADDR_BITS  = BANK_SEL_BITS + REG_SEL_BITS   # 8: any of the 160 names

SLOT_MASK = (1 << SLOT_WIDTH) - 1
SLOT_HEX  = (SLOT_WIDTH + 3) // 4               # hex digits in a slot word
TIER_BIT  = SLOT_WIDTH - 1                      # 0 = classic tier, 1 = dual tier

# ---------------------------------------------------------------- fields
# name -> (bit ranges [(msb, lsb), ...], register-file port, description)
# Ranges are listed most-significant chunk first; a field with several
# chunks is split in the encoding but reassembled by fixed wiring.
#
# The four read rails are the four bytes of [31:0]: ST2 carries four 8-bit
# sources and no destination, so it tiles the payload exactly. Every other
# format keeps each port on its own byte, which leaves the classic tier a
# contiguous immediate in the bits ST2 spends on s0/s1.
FIELDS = {
    "opcode6":   ([(35, 30)], None,      "classic-tier opcode (bit 35 = 0)"),
    "opcode4":   ([(35, 32)], None,      "dual-tier opcode (bit 35 = 1)"),
    "rs_base":   ([(7, 0)],   "read 1",  "base address register"),
    "rs_index":  ([(15, 8)],  "read 2",  "index register (indexed loads)"),
    "rs_data":   ([(15, 8)],  "read 2",  "store data (classic stores)"),
    "rs_stride": ([(15, 8)],  "read 2",  "signed byte stride (dual ops)"),
    "s0":        ([(31, 24)], "read 3",  "lane-0 store data (dual stores)"),
    "s1":        ([(23, 16)], "read 4",  "lane-1 store data (dual stores)"),
    "rs_datax":  ([(23, 16)], "read 4",  "store data (indexed stores)"),
    "rs_mov":    ([(7, 0)],   "read 1",  "move source (lane 0 for MOV2)"),
    "rs_mov1":   ([(15, 8)],  "read 2",  "move source, lane 1 (MOV2)"),
    "rd":        ([(29, 25)], "write A", "load destination (LS-A bank)"),
    "d0":        ([(29, 25)], "write A", "lane-0 destination (LS-A bank)"),
    "d1":        ([(20, 16)], "write B", "lane-1 destination (LS-B bank)"),
    "imm17":     ([(24, 8)],  None,      "signed byte offset"),
    "imm14":     ([(29, 16)], None,      "signed byte offset"),
    "imm9":      ([(24, 16)], None,      "signed byte offset (exchange)"),
}

# Immediates are two's complement; every other field is unsigned.
SIGNED = {"imm17", "imm14", "imm9"}

# Field name shown to the reader where it differs from the table key
# (rs_datax is the port-4 rail; the assembler operand is still rs_data).
DISPLAY = {"rs_datax": "rs_data", "rs_mov": "rs", "rs_mov1": "rs1"}


# ---------------------------------------------------------------- formats
# name -> (field list, reserved bit list, layout note)
FORMATS = {
    "N":     (["opcode6"], list(range(0, 30)), "no operand payload"),
    "L":     (["opcode6", "rd", "rs_base", "imm17"], [], "base + immediate load"),
    "S":     (["opcode6", "imm14", "rs_base", "rs_data"], [], "base + immediate store"),
    "LX":    (["opcode6", "rd", "rs_base", "rs_index"], list(range(16, 25)),
              "base + index load"),
    "SX":    (["opcode6", "rs_base", "rs_index", "rs_datax"],
              list(range(24, 30)), "base + index store"),
    "X":     (["opcode6", "rd", "rs_base", "rs_data", "imm9"], [],
              "exchange: store and return the pre-write word"),
    "L2":    (["opcode6", "d0", "rs_base", "rs_stride", "d1"], list(range(21, 25)),
              "dual strided load"),
    "ST2":   (["opcode4", "s0", "rs_base", "rs_stride", "s1"], [],
              "dual store, width in opcode"),
    "M":     (["opcode6", "rd", "rs_mov"], list(range(8, 25)),
              "register move into LS-A"),
    "M2":    (["opcode6", "d0", "rs_mov", "rs_mov1", "d1"], list(range(21, 25)),
              "dual register move into LS-A and LS-B"),
}

TIERS = {  # tier -> (opcode field, opcode width, first code, last code)
    "classic": ("opcode6", 6, 0b000000, 0b011111),
    "dual":    ("opcode4", 4, 0b1000,   0b1111),
}

# ---------------------------------------------------------- instructions
# (mnemonic, tier, opcode, format, subfield values, syntax, description)
I = lambda *a: dict(zip(
    ("mnemonic", "tier", "opcode", "format", "sub", "syntax", "desc"), a))

INSTRUCTIONS = [
    I("NOP",   "classic", 0b000000, "N",  {}, "",
      "no operation (all-zero slot word)"),

    I("LB",    "classic", 0b000001, "L",  {}, "rd, imm(rs_base)",
      "rd <- sign_ext(mem8[rs_base + imm])"),
    I("LH",    "classic", 0b000010, "L",  {}, "rd, imm(rs_base)",
      "rd <- sign_ext(mem16[rs_base + imm])"),
    I("LW",    "classic", 0b000011, "L",  {}, "rd, imm(rs_base)",
      "rd <- mem32[rs_base + imm]"),
    I("LBU",   "classic", 0b000100, "L",  {}, "rd, imm(rs_base)",
      "rd <- zero_ext(mem8[rs_base + imm])"),
    I("LHU",   "classic", 0b000101, "L",  {}, "rd, imm(rs_base)",
      "rd <- zero_ext(mem16[rs_base + imm])"),

    I("SB",    "classic", 0b000110, "S",  {}, "rs_data, imm(rs_base)",
      "mem8[rs_base + imm] <- rs_data[7:0]"),
    I("SH",    "classic", 0b000111, "S",  {}, "rs_data, imm(rs_base)",
      "mem16[rs_base + imm] <- rs_data[15:0]"),
    I("SW",    "classic", 0b001000, "S",  {}, "rs_data, imm(rs_base)",
      "mem32[rs_base + imm] <- rs_data"),

    I("LBX",   "classic", 0b001001, "LX", {}, "rd, (rs_base, rs_index)",
      "rd <- sign_ext(mem8[rs_base + rs_index])"),
    I("LHX",   "classic", 0b001010, "LX", {}, "rd, (rs_base, rs_index)",
      "rd <- sign_ext(mem16[rs_base + rs_index])"),
    I("LWX",   "classic", 0b001011, "LX", {}, "rd, (rs_base, rs_index)",
      "rd <- mem32[rs_base + rs_index]"),
    I("LBUX",  "classic", 0b001100, "LX", {}, "rd, (rs_base, rs_index)",
      "rd <- zero_ext(mem8[rs_base + rs_index])"),
    I("LHUX",  "classic", 0b001101, "LX", {}, "rd, (rs_base, rs_index)",
      "rd <- zero_ext(mem16[rs_base + rs_index])"),

    # dual strided loads: only 26 payload bits, so they live in the
    # classic tier with width and sign folded into the opcode
    I("LD2B",  "classic", 0b001110, "L2", {}, "d0, d1, (rs_base, rs_stride)",
      "d0 <- sign_ext(mem8[EA0]); d1 <- sign_ext(mem8[EA1])"),
    I("LD2BU", "classic", 0b001111, "L2", {}, "d0, d1, (rs_base, rs_stride)",
      "d0 <- zero_ext(mem8[EA0]); d1 <- zero_ext(mem8[EA1])"),
    I("LD2H",  "classic", 0b010000, "L2", {}, "d0, d1, (rs_base, rs_stride)",
      "d0 <- sign_ext(mem16[EA0]); d1 <- sign_ext(mem16[EA1])"),
    I("LD2HU", "classic", 0b010001, "L2", {}, "d0, d1, (rs_base, rs_stride)",
      "d0 <- zero_ext(mem16[EA0]); d1 <- zero_ext(mem16[EA1])"),
    I("LD2W",  "classic", 0b010010, "L2", {}, "d0, d1, (rs_base, rs_stride)",
      "d0 <- mem32[EA0]; d1 <- mem32[EA1]"),

    I("SWX",   "classic", 0b010011, "SX", {}, "rs_data, (rs_base, rs_index)",
      "mem32[rs_base + rs_index] <- rs_data"),
    I("SHX",   "classic", 0b010100, "SX", {}, "rs_data, (rs_base, rs_index)",
      "mem16[rs_base + rs_index] <- rs_data[15:0]"),
    I("SBX",   "classic", 0b010101, "SX", {}, "rs_data, (rs_base, rs_index)",
      "mem8[rs_base + rs_index] <- rs_data[7:0]"),

    I("XCHW",  "classic", 0b010110, "X",  {}, "rd, rs_data, imm(rs_base)",
      "rd <- mem32[EA]; mem32[EA] <- rs_data   (EA = rs_base + imm)"),

    # register moves: the LS slot has no ALU, so a copy into its own banks
    # cannot be synthesised the way the ALU slots do it with ADD/XOR
    I("MOV",   "classic", 0b010111, "M",  {}, "rd, rs",
      "rd <- rs   (any bank -> LS-A)"),
    I("MOV2",  "classic", 0b011000, "M2", {}, "d0, d1, (rs, rs1)",
      "d0 <- rs; d1 <- rs1   (any banks -> LS-A, LS-B)"),

    # dual tier: the four-source stores, the only ops needing 28 payload bits
    I("ST2",   "dual", 0b1000, "ST2", {}, "(rs_base, rs_stride), s0, s1",
      "mem32[EA0] <- s0; mem32[EA1] <- s1"),
    I("ST2H",  "dual", 0b1001, "ST2", {}, "(rs_base, rs_stride), s0, s1",
      "mem16[EA0] <- s0[15:0]; mem16[EA1] <- s1[15:0]"),
    I("ST2B",  "dual", 0b1010, "ST2", {}, "(rs_base, rs_stride), s0, s1",
      "mem8[EA0] <- s0[7:0]; mem8[EA1] <- s1[7:0]"),
]

# EA_i = rs_base + i * rs_stride (bytes, word-aligned base) for the dual
# sign_ext(imm) (bytes) for the classic tier -- LOAD_STORE.md 3.5 / 10.
LATENCY = ("Every LS result retires at W + 2 in the baseline configuration, "
           "and one cycle later for each of the memory's BRAM_OUT_REG and "
           "ADRREG options -- MOV and MOV2 included, even though they never "
           "reach the memory, so that the one write port per bank sees at "
           "most one result per cycle. A conflicting dual access (stride "
           "whose word distance is divisible by 3) is split by the hardware: "
           "it costs one extra "
           "cycle and returns d1 one cycle after d0. Stores produce no "
           "register result. See LOAD_STORE.md sections 5.1 and 10.4.")


def common_prefix(names):
    """Longest common prefix of mnemonics sharing one opcode (LD2B, LD2W -> LD2)."""
    pre = names[0]
    for n in names[1:]:
        while not n.startswith(pre):
            pre = pre[:-1]
    return pre


# ------------------------------------------------------------------ utils
def field_bits(name):
    """Set of bit indices covered by a field."""
    out = set()
    for msb, lsb in FIELDS[name][0]:
        out |= set(range(lsb, msb + 1))
    return out


def field_width(name):
    return len(field_bits(name))


def field_str(name):
    """'[20:14]' or '{[25:21], [6:0]}' for a split field."""
    chunks = ["[%d:%d]" % (m, l) if m != l else "[%d]" % m
              for m, l in FIELDS[name][0]]
    return chunks[0] if len(chunks) == 1 else "{%s}" % ", ".join(chunks)


def field_limits(name):
    """Inclusive (min, max) an operand may take for this field."""
    w = field_width(name)
    return ((-(1 << (w - 1)), (1 << (w - 1)) - 1) if name in SIGNED
            else (0, (1 << w) - 1))


def display(name):
    return DISPLAY.get(name, name)


def place(name, val):
    """Place a field value into its (possibly split) bit positions.

    Raises ValueError if the value does not fit -- silently truncating an
    operand would emit a different instruction than the one written.
    """
    lo, hi = field_limits(name)
    if not lo <= val <= hi:
        raise ValueError("%s: %d out of range [%d, %d]" % (name, val, lo, hi))
    word, rest = 0, val & ((1 << field_width(name)) - 1)
    for msb, lsb in reversed(FIELDS[name][0]):      # low chunk first
        n = msb - lsb + 1
        word |= (rest & ((1 << n) - 1)) << lsb
        rest >>= n
    return word


def extract(name, word):
    value, shift = 0, 0
    for msb, lsb in reversed(FIELDS[name][0]):
        n = msb - lsb + 1
        value |= ((word >> lsb) & ((1 << n) - 1)) << shift
        shift += n
    return value


def value(name, word):
    """Field value as written by the programmer (sign-extended if signed)."""
    raw = extract(name, word)
    w = field_width(name)
    if name in SIGNED and raw >> (w - 1):
        raw -= 1 << w
    return raw


def encode(inst, operands=None):
    """Assemble one instruction; operands maps field name -> value."""
    fields, _, _ = FORMATS[inst["format"]]
    opf = TIERS[inst["tier"]][0]
    word = place(opf, inst["opcode"])
    for f, v in inst["sub"].items():
        word |= place(f, v)
    for f, v in (operands or {}).items():
        if f not in fields:
            raise KeyError("%s has no field %s" % (inst["mnemonic"], f))
        word |= place(f, v)
    return word


# ------------------------------------------------------------------ check
def check():
    err = []

    for name in FIELDS:
        for msb, lsb in FIELDS[name][0]:
            if not (0 <= lsb <= msb < SLOT_WIDTH):
                err.append("field %s: bad range [%d:%d]" % (name, msb, lsb))

    # every format accounts for exactly 32 bits, with no field overlap
    for fmt, (fields, reserved, _) in FORMATS.items():
        seen = {}
        for f in fields:
            for b in field_bits(f):
                if b in seen:
                    err.append("format %s: bit %d in both %s and %s"
                               % (fmt, b, seen[b], f))
                seen[b] = f
        for b in reserved:
            if b in seen:
                err.append("format %s: reserved bit %d also in %s"
                           % (fmt, b, seen[b]))
        total = len(seen) + len(reserved)
        if total != SLOT_WIDTH:
            err.append("format %s: covers %d bits, expected %d"
                       % (fmt, total, SLOT_WIDTH))

    # a role occupies one rail everywhere (that is the point of 2.1)
    for name, (_, port, _) in FIELDS.items():
        if port is None:
            continue
        same = [n for n, (_, p, _) in FIELDS.items()
                if p == port and field_bits(n) != field_bits(name)]
        # different roles on one port must be bit-identical or nested
        for other in same:
            a, b = field_bits(name), field_bits(other)
            if not (a <= b or b <= a):
                err.append("port %s: %s %s and %s %s are neither identical "
                           "nor nested" % (port, name, field_str(name),
                                           other, field_str(other)))

    # opcodes: in range for their tier, and unique per (tier, opcode, sub)
    seen_op = {}
    for inst in INSTRUCTIONS:
        opf, width, lo, hi = TIERS[inst["tier"]]
        if not (lo <= inst["opcode"] <= hi):
            err.append("%s: opcode %s out of %s tier range"
                       % (inst["mnemonic"], bin(inst["opcode"]), inst["tier"]))
        if FORMATS[inst["format"]][0][0] != opf:
            err.append("%s: format %s does not start with %s"
                       % (inst["mnemonic"], inst["format"], opf))
        key = (inst["tier"], inst["opcode"],
               tuple(sorted(inst["sub"].items())))
        if key in seen_op:
            err.append("%s collides with %s (same opcode and subfields)"
                       % (inst["mnemonic"], seen_op[key]))
        seen_op[key] = inst["mnemonic"]
        for f, v in inst["sub"].items():
            if v >= (1 << field_width(f)):
                err.append("%s: subfield %s value %d too wide"
                           % (inst["mnemonic"], f, v))

    # tier prefixes must be disjoint (the top slot bit discriminates)
    if (TIERS["classic"][3] >> (TIERS["classic"][1] - 1) != 0
            or TIERS["dual"][2] >> (TIERS["dual"][1] - 1) != 1):
        err.append("tier prefixes overlap on bit %d" % TIER_BIT)

    # NOP must be the all-zero word
    nop = [i for i in INSTRUCTIONS if i["mnemonic"] == "NOP"]
    if not nop or encode(nop[0]) != 0:
        err.append("NOP is not the all-zero word")

    # encode/decode round trip: every instruction must be recoverable, and
    # every operand field must survive placement and extraction
    for inst in INSTRUCTIONS:
        fields, _, _ = FORMATS[inst["format"]]
        ops = {}
        for k, f in enumerate(fields):
            if f.startswith("opcode") or f in inst["sub"]:
                continue
            lo, hi = field_limits(f)
            ops[f] = lo + ((k + 1) * 0x2B) % (hi - lo + 1)
        word = encode(inst, ops)
        tier = "dual" if (word >> TIER_BIT) & 1 else "classic"
        if tier != inst["tier"]:
            err.append("%s: encodes into the %s tier" % (inst["mnemonic"], tier))
            continue
        hits = [c for c in INSTRUCTIONS
                if c["tier"] == tier
                and c["opcode"] == extract(TIERS[tier][0], word)
                and all(extract(f, word) == v for f, v in c["sub"].items())]
        if [h["mnemonic"] for h in hits] != [inst["mnemonic"]]:
            err.append("%s: decodes to %s (ambiguous encoding)"
                       % (inst["mnemonic"], [h["mnemonic"] for h in hits]))
        for f, v in ops.items():
            if value(f, word) != v:
                err.append("%s: field %s does not round trip (%d -> %d)"
                           % (inst["mnemonic"], f, v, value(f, word)))

    for e in err:
        print("error: " + e, file=sys.stderr)
    print("%d fields, %d formats, %d instructions: %s"
          % (len(FIELDS), len(FORMATS), len(INSTRUCTIONS),
             "OK" if not err else "%d ERROR(S)" % len(err)), file=sys.stderr)
    return 1 if err else 0


# -------------------------------------------------------------- check doc
DOC = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "doc", "LOAD_STORE.md")


def _parse_doc(text):
    """Pull the field map and the opcode maps out of the specification.

    Recognises the two markdown row shapes and ignores every other table:
      | `name`   | `[msb:lsb]` | width | port | ...   -> field map
      | `010110` | `XCHW`      | ...                  -> an opcode map
    """
    fields, opcodes = {}, {}
    for line in text.splitlines():
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 4:
            continue
        c0, c1 = cells[0].strip("`"), cells[1].strip("`")
        if re.fullmatch(r"[01]+", c0) and re.fullmatch(r"\w+", c1):
            opcodes[c1] = c0
        elif re.fullmatch(r"\w+", c0) and c1[:1] in ("[", "{"):
            port = cells[3].replace(" addr", "").strip()
            fields.setdefault(c0, []).append(
                (c1, cells[2], None if port in ("—", "-", "") else port))
    return fields, opcodes


def _doc_reserved(text, tier):
    """The '<tier>-tier opcodes `lo`-`hi` (n entries)' claim, if present."""
    m = re.search(r"%s-tier opcodes `([01]+)`[^`]*`([01]+)` \((\d+) entries"
                  % tier, text)
    return (m.group(1), m.group(2), int(m.group(3))) if m else None


def check_doc(path=DOC):
    """Compare the specification's tables with the tables in this file."""
    err = []
    try:
        text = open(path).read()
    except OSError as exc:
        print("error: %s" % exc, file=sys.stderr)
        return 1
    dfields, dops = _parse_doc(text)

    for name in FIELDS:
        doc_name = "opcode" if name.startswith("opcode") else name
        want = (field_str(name), str(field_width(name)), FIELDS[name][1])
        rows = dfields.get(doc_name, [])
        if want not in rows:
            err.append("field %s: tables say %s, doc field map has %s"
                       % (name, want, rows or "no such row"))
    for name in dfields:
        if name != "opcode" and name not in FIELDS:
            err.append("field %s: in the doc field map, not in the tables" % name)

    for inst in INSTRUCTIONS:
        want = format(inst["opcode"], "0%db" % TIERS[inst["tier"]][1])
        got = dops.get(inst["mnemonic"])
        if got is None:
            err.append("%s: missing from the doc opcode maps" % inst["mnemonic"])
        elif got != want:
            err.append("%s: doc opcode %s, tables say %s"
                       % (inst["mnemonic"], got, want))
    known = {i["mnemonic"] for i in INSTRUCTIONS}
    for m in dops:
        if m not in known:
            err.append("%s: in a doc opcode map, not in the tables" % m)

    for tier, (_, width, lo, hi) in TIERS.items():
        used = {i["opcode"] for i in INSTRUCTIONS if i["tier"] == tier}
        free = sorted(c for c in range(lo, hi + 1) if c not in used)
        claim = _doc_reserved(text, tier)
        if claim is None:
            err.append("%s tier: doc states no reserved range" % tier)
        elif not free:
            err.append("%s tier: doc claims a reserved range, none is free" % tier)
        else:
            want = (format(free[0], "0%db" % width),
                    format(free[-1], "0%db" % width), len(free))
            if claim != want:
                err.append("%s tier reserved: doc says %s, tables say %s"
                           % (tier, claim, want))

    for e in err:
        print("error: " + e, file=sys.stderr)
    print("doc %s: %d fields, %d opcodes: %s"
          % (os.path.relpath(path), sum(len(v) for v in dfields.values()),
             len(dops), "OK" if not err else "%d ERROR(S)" % len(err)),
          file=sys.stderr)
    return 1 if err else 0


# -------------------------------------------------------------- emit: asm
def _runs(bits):
    """Contiguous descending runs of a bit list: [1,0] -> [(1, 0)]."""
    out = []
    for b in sorted(bits, reverse=True):
        if out and out[-1][1] == b + 1:
            out[-1] = (out[-1][0], b)
        else:
            out.append((b, b))
    return out


def bit_diagram(inst):
    """'[35:30]=000011  rd[29:25]  imm17[24:8]  rs_base[7:0]'

    Lists every field and every reserved run in descending bit order, so
    the diagram accounts for all SLOT_WIDTH bits of the slot.
    """
    fields, reserved, _ = FORMATS[inst["format"]]
    parts = []
    for f in fields:
        msb = max(field_bits(f))
        if f in ("opcode6", "opcode4"):
            parts.append((msb, "%s=%s" % (field_str(f), format(
                inst["opcode"], "0%db" % field_width(f)))))
        elif f in inst["sub"]:
            parts.append((msb, "%s%s=%s" % (display(f), field_str(f), format(
                inst["sub"][f], "0%db" % field_width(f)))))
        else:
            parts.append((msb, "%s%s" % (display(f), field_str(f))))
    for msb, lsb in _runs(reserved):
        parts.append((msb, "rsvd[%d:%d]" % (msb, lsb) if msb != lsb
                      else "rsvd[%d]" % msb))
    return "  ".join(t for _, t in sorted(parts, reverse=True))


def emit_asm():
    print("VLIW Load/Store slot -- instruction reference")
    print("=" * 76)
    print("\nEvery instruction is one %d-bit slot of the %d-bit VLIW word."
          % (SLOT_WIDTH, 4 * SLOT_WIDTH))
    print("Sources are %d-bit global register addresses (%d-bit bank + %d-bit"
          % (SRC_ADDR_BITS, BANK_SEL_BITS, REG_SEL_BITS))
    print("register, any of the %d banks); destinations are %d-bit with the"
          % (NUM_BANKS, REG_SEL_BITS))
    print("bank implicit (rd/d0 -> LS-A, d1 -> LS-B).\n")
    print(textwrap.fill(LATENCY, 76) + "\n")

    for tier in TIERS:
        insts = [i for i in INSTRUCTIONS if i["tier"] == tier]
        print("-" * 76)
        print("%s tier (%s, opcode %s)" % (
            tier.upper(), field_str(TIERS[tier][0]),
            "%s..%s" % (format(TIERS[tier][2], "0%db" % TIERS[tier][1]),
                        format(TIERS[tier][3], "0%db" % TIERS[tier][1]))))
        print("-" * 76)
        print("\n%-8s %-30s %s" % ("Mnemonic", "Operands", "Operation"))
        for i in insts:
            print("%-8s %-30s %s" % (i["mnemonic"], i["syntax"], i["desc"]))
        print()
        for i in insts:
            print(("%s %s" % (i["mnemonic"], i["syntax"])).rstrip())
            print("    %s" % bit_diagram(i))
            print("    %s" % i["desc"])
            print()

    # reserved ranges
    for tier, (opf, width, lo, hi) in TIERS.items():
        used = {i["opcode"] for i in INSTRUCTIONS if i["tier"] == tier}
        free = [c for c in range(lo, hi + 1) if c not in used]
        if free:
            print("%s tier reserved (illegal-instruction trap): %s"
                  % (tier, ", ".join(format(c, "0%db" % width)
                                     for c in free)))


# --------------------------------------------------------------- emit: md
def emit_md():
    print("| Field       | Bits                    | Width | Port / rail  |"
          " Description |")
    print("|-------------|-------------------------|-------|--------------|"
          "-------------|")
    for n, (_, port, desc) in FIELDS.items():
        print("| `%s` | `%s` | %d | %s | %s |"
              % (n, field_str(n), field_width(n), port or "—", desc))

    for tier in TIERS:
        print("\n**%s tier opcode map**\n" % tier.capitalize())
        print("| Opcode | Mnemonic | Operands | Description |")
        print("|--------|----------|----------|-------------|")
        w = TIERS[tier][1]
        for i in [x for x in INSTRUCTIONS if x["tier"] == tier]:
            sub = "".join(" (%s=%s)" % (f, format(v, "0%db" % field_width(f)))
                          for f, v in sorted(i["sub"].items()))
            print("| `%s`%s | `%s` | `%s` | %s |"
                  % (format(i["opcode"], "0%db" % w), sub,
                     i["mnemonic"], i["syntax"], i["desc"]))


# --------------------------------------------------------------- emit: sv
def emit_sv():
    print("// Generated by hw/vliw/tools/ls_isa.py -- do not edit.")
    print("package ls_isa_pkg;\n")
    print("   /* verilator lint_off UNUSEDPARAM */  // constants are for consumers")
    print("   /* verilator lint_off UNUSEDSIGNAL */ // extractors slice one field\n")
    for tier, (opf, width, lo, hi) in TIERS.items():
        print("   // %s tier" % tier)
        for op in sorted({i["opcode"] for i in INSTRUCTIONS
                          if i["tier"] == tier}):
            names = [i["mnemonic"] for i in INSTRUCTIONS
                     if i["tier"] == tier and i["opcode"] == op]
            name = names[0] if len(names) == 1 else common_prefix(names)
            print("   localparam logic [%d:0] LS_OP_%-6s = %d'b%s;%s"
                  % (width - 1, name, width, format(op, "0%db" % width),
                     "" if len(names) == 1
                     else "   // " + ", ".join(names)))
        print()
    print("   // field extraction (constant slices -- no address mux)")
    for n in FIELDS:
        if n.startswith("opcode"):
            continue
        chunks = ", ".join("inst[%d:%d]" % (m, l) if m != l else "inst[%d]" % m
                           for m, l in FIELDS[n][0])
        body = chunks if len(FIELDS[n][0]) == 1 else "{%s}" % chunks
        print("   function automatic logic [%d:0] ls_%s"
              "(input logic [%d:0] inst);"
              % (field_width(n) - 1, n, SLOT_WIDTH - 1))
        print("      return %s;" % body)
        print("   endfunction\n")
    print("   /* verilator lint_on UNUSEDSIGNAL */")
    print("   /* verilator lint_on UNUSEDPARAM */")
    print("\nendpackage")


# ------------------------------------------------------------ emit: decode
def emit_decode(text):
    try:
        word = (int(text, 0) if text.startswith(("0x", "0b", "0o"))
                else int(text, 16))
    except ValueError:
        print("error: %r is not a %d-bit word (use 0x..., 0b... or bare hex)"
              % (text, SLOT_WIDTH))
        return
    word &= SLOT_MASK
    tier = "dual" if (word >> TIER_BIT) & 1 else "classic"
    opf, width, _, _ = TIERS[tier]
    op = extract(opf, word)
    hits = [i for i in INSTRUCTIONS
            if i["tier"] == tier and i["opcode"] == op
            and all(extract(f, word) == v for f, v in i["sub"].items())]
    print("word     0x%0*X  (%s tier, opcode %s)"
          % (SLOT_HEX, word, tier, format(op, "0%db" % width)))
    if not hits:
        print("         reserved opcode -> illegal-instruction trap")
        return
    inst = hits[0]
    print("mnemonic %s %s" % (inst["mnemonic"], inst["syntax"]))
    for f in FORMATS[inst["format"]][0]:
        if f.startswith("opcode"):
            continue
        v = value(f, word)
        note = ""
        if FIELDS[f][1] in ("read 1", "read 2", "read 3", "read 4"):
            note = "  (bank %d, reg %d)" % (v >> REG_SEL_BITS,
                                            v & ((1 << REG_SEL_BITS) - 1))
        print("  %-9s %-18s = %d%s" % (display(f), field_str(f), v, note))


# ------------------------------------------------------------------ tests
class _Tests(unittest.TestCase):
    """Unit tests for the encoding helpers and the generated views.

    The golden vectors are hand-computed from the field map: a failure
    there means the encoding changed, which is an ISA change -- update
    the vector deliberately, never to make the test pass.
    """

    def test_field_widths_match_ranges(self):
        for name in FIELDS:
            self.assertEqual(field_width(name), len(field_bits(name)), name)

    def test_every_field_round_trips(self):
        for name in FIELDS:
            lo, hi = field_limits(name)
            vals = (range(lo, hi + 1) if hi - lo < 4096
                    else (lo, lo + 1, -1, 0, 1, hi - 1, hi))
            for v in vals:
                self.assertEqual(value(name, place(name, v)), v, (name, v))

    def test_split_field_machinery(self):
        # No field is split in the 36-bit map (every immediate is
        # contiguous). Keep the reassembly path covered so a future split
        # encoding cannot regress silently.
        FIELDS["_probe"] = ([(29, 25), (7, 0)], None, "test-only split field")
        SIGNED.add("_probe")
        try:
            lo, hi = field_limits("_probe")              # 13 bits, signed
            self.assertEqual((lo, hi), (-4096, 4095))
            for v in range(lo, hi + 1):
                self.assertEqual(value("_probe", place("_probe", v)), v)
            self.assertEqual(field_str("_probe"), "{[29:25], [7:0]}")
        finally:
            del FIELDS["_probe"]
            SIGNED.discard("_probe")

    def test_place_lands_only_in_own_bits(self):
        for name in FIELDS:
            word = place(name, -1 if name in SIGNED
                         else (1 << field_width(name)) - 1)
            self.assertEqual({b for b in range(SLOT_WIDTH) if word >> b & 1},
                             field_bits(name), name)

    def test_field_str_formats(self):
        self.assertEqual(field_str("rs_base"), "[7:0]")
        self.assertEqual(field_str("imm17"), "[24:8]")

    def test_nop_is_all_zero_word(self):
        self.assertEqual(encode(_inst("NOP")), 0)

    def test_golden_lw(self):
        # LW rd=3, rs_base=bank0:reg20, imm17=64
        # op6=000011 [35:30] | rd=3 [29:25] | imm=64 [24:8] | base=20 [7:0]
        self.assertEqual(
            encode(_inst("LW"), {"rd": 3, "rs_base": 20, "imm17": 64}),
            0xC6004014)

    def test_golden_sw(self):
        # SW rs_data=bank0:reg5, rs_base=bank0:reg20, imm14=-1348 (0x3ABC)
        # op6=001000 [35:30] | imm [29:16] | data=5 [15:8] | base=20 [7:0]
        self.assertEqual(
            encode(_inst("SW"),
                   {"rs_data": 5, "rs_base": 20, "imm14": -1348}),
            0x23ABC0514)

    def test_golden_st2(self):
        # ST2 s0=bank1:reg3, base=bank0:reg20, stride=bank0:reg1, s1=bank2:reg7
        # op4=1000 [35:32] | s0 [31:24] | s1 [23:16] | stride [15:8] | base [7:0]
        self.assertEqual(
            encode(_inst("ST2"), {"s0": (1 << 5) | 3, "rs_base": 20,
                                  "rs_stride": 1, "s1": (2 << 5) | 7}),
            0x823470114)

    def test_ld2_variants_are_distinct_classic_opcodes(self):
        names = ("LD2B", "LD2BU", "LD2H", "LD2HU", "LD2W")
        words = {m: encode(_inst(m), {"d0": 1, "d1": 2, "rs_base": 3,
                                      "rs_stride": 4}) for m in names}
        self.assertEqual(len(set(words.values())), len(words))
        for m, w in words.items():
            self.assertEqual(_inst(m)["tier"], "classic")
            self.assertFalse(w >> TIER_BIT, m)    # classic tier
            self.assertEqual(extract("opcode6", w), _inst(m)["opcode"])

    def test_golden_ld2w(self):
        # LD2W d0=3, d1=7, rs_base=bank0:reg20, rs_stride=bank0:reg1
        # op6=010010 [35:30] | d0 [29:25] | d1 [20:16] | stride [15:8] | base
        self.assertEqual(
            encode(_inst("LD2W"), {"d0": 3, "d1": 7, "rs_base": 20,
                                   "rs_stride": 1}),
            0x486070114)

    def test_only_four_source_ops_use_the_dual_tier(self):
        for inst in INSTRUCTIONS:
            reads = [f for f in FORMATS[inst["format"]][0]
                     if FIELDS[f][1] and "read" in FIELDS[f][1]]
            self.assertEqual(inst["tier"] == "dual", len(reads) == 4,
                             inst["mnemonic"])

    def test_tier_selected_by_top_slot_bit(self):
        for inst in INSTRUCTIONS:
            word = encode(inst)
            self.assertEqual(bool(word >> TIER_BIT), inst["tier"] == "dual",
                             inst["mnemonic"])

    def test_every_instruction_round_trips(self):
        for inst in INSTRUCTIONS:
            fields = FORMATS[inst["format"]][0]
            ops = {f: 1 for f in fields
                   if not f.startswith("opcode") and f not in inst["sub"]}
            word = encode(inst, ops)
            tier = "dual" if word >> TIER_BIT else "classic"
            hits = [c["mnemonic"] for c in INSTRUCTIONS
                    if c["tier"] == tier
                    and c["opcode"] == extract(TIERS[tier][0], word)
                    and all(extract(f, word) == v
                            for f, v in c["sub"].items())]
            self.assertEqual(hits, [inst["mnemonic"]])

    def test_encode_rejects_out_of_range_register(self):
        for bad in (32, 99, -1):                  # rd is 5 bits, unsigned
            with self.assertRaises(ValueError, msg=bad):
                encode(_inst("LW"), {"rd": bad})

    def test_encode_rejects_out_of_range_immediate(self):
        lo, hi = field_limits("imm9")             # XCHW offset: -256..255
        self.assertEqual((lo, hi), (-256, 255))
        encode(_inst("XCHW"), {"imm9": lo})       # bounds are accepted
        encode(_inst("XCHW"), {"imm9": hi})
        for bad in (hi + 1, lo - 1):
            with self.assertRaises(ValueError, msg=bad):
                encode(_inst("XCHW"), {"imm9": bad})

    def test_negative_immediates_round_trip(self):
        for name, mnemonic in (("imm17", "LW"), ("imm14", "SW"),
                               ("imm9", "XCHW")):
            lo, hi = field_limits(name)
            for v in (lo, -4, -1, 0, 1, hi):
                word = encode(_inst(mnemonic), {name: v})
                self.assertEqual(value(name, word), v, (name, v))
                self.assertGreaterEqual(extract(name, word), 0)   # raw bits

    def test_unsigned_fields_are_not_sign_extended(self):
        word = encode(_inst("LW"), {"rs_base": 0xFF})    # bank 7, reg 31
        self.assertEqual(value("rs_base", word), 0xFF)

    def test_source_field_addresses_every_bank(self):
        # 8-bit sources: 3 bits of bank select over 5 populated banks
        self.assertEqual(field_width("rs_base"), SRC_ADDR_BITS)
        for bank in range(NUM_BANKS):
            for reg in (0, (1 << REG_SEL_BITS) - 1):
                addr = (bank << REG_SEL_BITS) | reg
                word = encode(_inst("LW"), {"rs_base": addr})
                self.assertEqual(value("rs_base", word), addr)

    def test_bit_diagram_accounts_for_all_slot_bits(self):
        for inst in INSTRUCTIONS:
            diagram = bit_diagram(inst)
            covered = set()
            for msb, lsb in re.findall(r"\[(\d+):(\d+)\]", diagram):
                covered |= set(range(int(lsb), int(msb) + 1))
            for bit in re.findall(r"\[(\d+)\]", diagram):
                covered.add(int(bit))
            self.assertEqual(covered, set(range(SLOT_WIDTH)),
                             "%s: %s" % (inst["mnemonic"], diagram))

    def test_generated_views_do_not_carry_validator_output(self):
        for emit in (emit_asm, emit_md, emit_sv):
            with contextlib.redirect_stderr(io.StringIO()), \
                 contextlib.redirect_stdout(io.StringIO()) as out:
                check()          # its summary must go to stderr, not here
                emit()
            self.assertNotIn("instructions:", out.getvalue(), emit.__name__)

    def test_asm_and_decode_show_the_operand_name(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            emit_asm()
        text = out.getvalue()
        self.assertIn("rs_data[23:16]", text)     # not the rs_datax rail name
        self.assertNotIn("rs_datax", text)

    def test_decode_reports_a_bad_argument_without_a_traceback(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            emit_decode("not-a-word")
        self.assertIn("is not a 36-bit word", out.getvalue())

    def test_decode_shows_signed_immediates(self):
        word = encode(_inst("LW"), {"rd": 1, "rs_base": 2, "imm17": -4})
        with contextlib.redirect_stdout(io.StringIO()) as out:
            emit_decode("0x%0*X" % (SLOT_HEX, word))
        self.assertIn("= -4", out.getvalue())

    def test_encode_rejects_field_absent_from_format(self):
        with self.assertRaises(KeyError):
            encode(_inst("LW"), {"rs_stride": 1})

    def test_rails_are_shared_not_moved(self):
        rail2 = {"rs_index", "rs_data", "rs_stride"}
        self.assertEqual({field_str(f) for f in rail2}, {"[15:8]"})
        self.assertEqual(field_str("rd"), field_str("d0"))

    def test_common_prefix(self):
        self.assertEqual(common_prefix(["LD2B", "LD2BU", "LD2W"]), "LD2")
        self.assertEqual(common_prefix(["ST2"]), "ST2")

    def test_check_passes_on_shipped_tables(self):
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(check(), 0)

    def test_check_catches_a_broken_table(self):
        saved = FORMATS["L"]
        FORMATS["L"] = (["opcode6", "rd", "rs_base"], [], "truncated")
        try:
            with contextlib.redirect_stderr(io.StringIO()) as err:
                self.assertEqual(check(), 1)
            self.assertIn("covers 19 bits", err.getvalue())
        finally:
            FORMATS["L"] = saved

    def test_check_doc_passes_on_the_shipped_specification(self):
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(check_doc(), 0)

    def test_check_doc_catches_the_drift_classes(self):
        """Each mutation stands for one kind of drift seen in review."""
        good = open(DOC).read()
        mutations = (
            # a stale opcode value in the map
            ("| `010110` | `XCHW`", "| `010111` | `XCHW`", "doc opcode"),
            # a field moved off its rail
            ("| `rs_base`   | `[7:0]`", "| `rs_base`   | `[9:2]`", "field rs_base"),
            # a stale reserved-range count
            ("(7 entries)", "(11 entries)", "classic tier reserved"),
            # an instruction dropped from the doc
            ("| `010101` | `SBX`", "| `010101` | `SBXX`", "SBX"),
        )
        for old, new, needle in mutations:
            self.assertIn(old, good, old)
            path = os.path.join(os.path.dirname(DOC), ".ls_isa_selftest.md")
            with open(path, "w") as fh:
                fh.write(good.replace(old, new, 1))
            try:
                with contextlib.redirect_stderr(io.StringIO()) as err:
                    rc = check_doc(path)
                self.assertEqual(rc, 1, old)
                self.assertIn(needle, err.getvalue(), old)
            finally:
                os.remove(path)

    def test_doc_parser_ignores_unrelated_tables(self):
        fields, ops = _parse_doc(
            "| `LB` | `SB`  | byte (8-bit) | sign-extended to 32 |\n"
            "| -9   | `LOOP_ACTIVE` | 1 | RW | flag |\n"
            "| [35:30] | [29:25] | [24:8] | [7:0] |\n"
            "| `rd` | `[29:25]` | 5 | write A addr | loads |\n"
            "| `000011` | `LW` | `rd, imm(rs_base)` | load word | x |\n")
        self.assertEqual(list(fields), ["rd"])
        self.assertEqual(ops, {"LW": "000011"})

    def test_emitters_produce_expected_content(self):
        for emit, needles in ((emit_asm, ("LD2HU", "reserved", "[35:32]")),
                              (emit_md, ("| `rs_base` |", "opcode map")),
                              (emit_sv, ("package ls_isa_pkg;",
                                         "LS_OP_LD2", "endpackage"))):
            with contextlib.redirect_stdout(io.StringIO()) as out:
                emit()
            for n in needles:
                self.assertIn(n, out.getvalue(), emit.__name__)

    def test_decode_reports_reserved_opcode(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            emit_decode("0xF00000000")
        self.assertIn("illegal-instruction trap", out.getvalue())

    def test_decode_reports_banks_and_registers(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            emit_decode("0x923470114")
        text = out.getvalue()
        self.assertIn("ST2", text)
        self.assertIn("bank 2, reg 7", text)          # s1


def _inst(mnemonic):
    return next(i for i in INSTRUCTIONS if i["mnemonic"] == mnemonic)


def run_tests():
    suite = unittest.TestLoader().loadTestsFromTestCase(_Tests)
    ok = unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful()
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(
        prog="ls_isa.py",
        description="Single source of truth for the VLIW Load/Store slot "
                    "encoding: validates the tables and generates the "
                    "specification, assembler and RTL views of them.",
        epilog="With no action given, the encoding tables are validated.")
    act = ap.add_mutually_exclusive_group()
    act.add_argument("--check", action="store_true",
                     help="validate the encoding tables (default action)")
    act.add_argument("--test", action="store_true",
                     help="run the unit tests for the helpers and emitters")
    act.add_argument("--check-doc", metavar="FILE", nargs="?", const=DOC,
                     help="check LOAD_STORE.md's tables against these "
                          "(default: ../doc/LOAD_STORE.md)")
    act.add_argument("--asm", action="store_true",
                     help="instruction reference, assembly-manual style")
    act.add_argument("--md", action="store_true",
                     help="markdown field and opcode tables for LOAD_STORE.md")
    act.add_argument("--sv", action="store_true",
                     help="SystemVerilog decode package (ls_isa_pkg)")
    act.add_argument("--decode", metavar="WORD",
                     help="decode one instruction word (0x..., 0b... or hex)")
    ap.add_argument("-o", "--output", metavar="FILE",
                    help="write the generated view to FILE instead of stdout")
    args = ap.parse_args()

    if args.test:
        return run_tests()

    if args.check_doc:
        return check() or check_doc(args.check_doc)

    if check():                       # never emit from a broken table
        return 1

    emit = (emit_asm if args.asm else
            emit_md if args.md else
            emit_sv if args.sv else
            (lambda: emit_decode(args.decode)) if args.decode else None)
    if emit is None:                  # --check, or no action
        return 0

    if args.output:
        with open(args.output, "w") as fh, contextlib.redirect_stdout(fh):
            emit()
        print("wrote %s" % args.output)
    else:
        emit()
    return 0


if __name__ == "__main__":
    sys.exit(main())
