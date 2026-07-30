#!/usr/bin/env python3
# SPDX-License-Identifier: CERN-OHL-P-2.0
# Copyright (c) 2026 Christophe Clienti
"""Single source of truth for the VLIW Load/Store slot encoding.

The tables below mirror LOAD_STORE.md sections 2.1 (operand rails), 3.1
(field positions and opcode map) and 10.2 (dual-access tier).  Everything
else -- the specification tables, the assembler reference listing and the
RTL decode parameters -- is generated from them, so the doc, the RTL and
the toolchain cannot drift apart.

Run with --help for the available views (--check, --asm, --md, --sv,
--decode), and -o to write one to a file.

Extending to the other slots (ALU, CTRL) means adding their FIELDS /
FORMATS / INSTRUCTIONS tables; the checkers and emitters are generic.
"""

import argparse
import contextlib
import sys

SLOT_WIDTH = 32

# ---------------------------------------------------------------- fields
# name -> (bit ranges [(msb, lsb), ...], register-file port, description)
# Ranges are listed most-significant chunk first; a field with several
# chunks is split in the encoding but reassembled by fixed wiring.
FIELDS = {
    "opcode6":   ([(31, 26)], None,      "classic-tier opcode (bit 31 = 0)"),
    "opcode4":   ([(31, 28)], None,      "dual-tier opcode (bit 31 = 1)"),
    "rs_base":   ([(20, 14)], "read 1",  "base address register"),
    "rs_index":  ([(13, 7)],  "read 2",  "index register (indexed loads)"),
    "rs_data":   ([(13, 7)],  "read 2",  "store data (classic stores)"),
    "rs_stride": ([(13, 7)],  "read 2",  "signed word stride (dual ops)"),
    "s0":        ([(27, 21)], "read 3",  "lane-0 store data"),
    "s1":        ([(6, 0)],   "read 4",  "lane-1 store data"),
    "rd":        ([(25, 21)], "write A", "load destination (LS-A bank)"),
    "d0":        ([(25, 21)], "write A", "lane-0 destination (LS-A bank)"),
    "d1":        ([(6, 2)],   "write B", "lane-1 destination (LS-B bank)"),
    "imm14":     ([(13, 0)],  None,      "signed byte offset"),
    "imm12":     ([(25, 21), (6, 0)], None, "signed byte offset (split)"),
    "w":         ([(27, 26)], None,      "LD2 access width: 00 B, 01 H, 10 W"),
    "u":         ([(1, 1)],   None,      "LD2 zero-extend (byte/half)"),
}

# ---------------------------------------------------------------- formats
# name -> (field list, reserved bit list, layout note)
FORMATS = {
    "N":     (["opcode6"], list(range(0, 26)), "no operand payload"),
    "L":     (["opcode6", "rd", "rs_base", "imm14"], [], "base + immediate load"),
    "S":     (["opcode6", "imm12", "rs_base", "rs_data"], [], "base + immediate store"),
    "LX":    (["opcode6", "rd", "rs_base", "rs_index"], list(range(0, 7)),
              "base + index load"),
    "LD2":   (["opcode4", "w", "d0", "rs_base", "rs_stride", "d1", "u"], [0],
              "dual load, width/sign in subfields"),
    "ST2":   (["opcode4", "s0", "rs_base", "rs_stride", "s1"], [],
              "dual store, width in opcode"),
    "STLD2": (["opcode4", "s0", "rs_base", "rs_stride", "d1"], [0, 1],
              "lane 0 stores, lane 1 loads"),
    "LDST2": (["opcode4", "d0", "rs_base", "rs_stride", "s1"], [26, 27],
              "lane 0 loads, lane 1 stores"),
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

    # dual tier: LD2 variants share one opcode, selected by w/u subfields
    I("LD2B",  "dual", 0b1000, "LD2", {"w": 0b00, "u": 0},
      "d0, d1, (rs_base, rs_stride)",
      "d0 <- sign_ext(mem8[EA0]); d1 <- sign_ext(mem8[EA1])"),
    I("LD2BU", "dual", 0b1000, "LD2", {"w": 0b00, "u": 1},
      "d0, d1, (rs_base, rs_stride)",
      "d0 <- zero_ext(mem8[EA0]); d1 <- zero_ext(mem8[EA1])"),
    I("LD2H",  "dual", 0b1000, "LD2", {"w": 0b01, "u": 0},
      "d0, d1, (rs_base, rs_stride)",
      "d0 <- sign_ext(mem16[EA0]); d1 <- sign_ext(mem16[EA1])"),
    I("LD2HU", "dual", 0b1000, "LD2", {"w": 0b01, "u": 1},
      "d0, d1, (rs_base, rs_stride)",
      "d0 <- zero_ext(mem16[EA0]); d1 <- zero_ext(mem16[EA1])"),
    I("LD2W",  "dual", 0b1000, "LD2", {"w": 0b10, "u": 0},
      "d0, d1, (rs_base, rs_stride)",
      "d0 <- mem32[EA0]; d1 <- mem32[EA1]"),

    I("ST2",   "dual", 0b1001, "ST2", {}, "(rs_base, rs_stride), s0, s1",
      "mem32[EA0] <- s0; mem32[EA1] <- s1"),
    I("ST2H",  "dual", 0b1010, "ST2", {}, "(rs_base, rs_stride), s0, s1",
      "mem16[EA0] <- s0[15:0]; mem16[EA1] <- s1[15:0]"),
    I("ST2B",  "dual", 0b1011, "ST2", {}, "(rs_base, rs_stride), s0, s1",
      "mem8[EA0] <- s0[7:0]; mem8[EA1] <- s1[7:0]"),

    I("STLD2", "dual", 0b1100, "STLD2", {}, "d1, (rs_base, rs_stride), s0",
      "mem32[EA0] <- s0; d1 <- mem32[EA1]"),
    I("LDST2", "dual", 0b1101, "LDST2", {}, "d0, (rs_base, rs_stride), s1",
      "d0 <- mem32[EA0]; mem32[EA1] <- s1"),
]

# EA_i = rs_base + i * rs_stride (words) for the dual tier; EA = rs_base +
# sign_ext(imm) (bytes) for the classic tier -- LOAD_STORE.md 3.5 / 10.
LATENCY = ("Loads retire at W + 2 (W + 3 with BRAM_OUT_REG); a conflicting "
           "dual access (stride = 0 mod 3) costs one extra cycle and "
           "returns d1 one cycle after d0 -- LOAD_STORE.md 5.1 / 10.4.")


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


def place(name, value):
    """Place a field value into its (possibly split) bit positions."""
    word, rest = 0, value
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

    # tier prefixes must be disjoint (bit 31 discriminates)
    if TIERS["classic"][3] >> 5 != 0 or TIERS["dual"][2] >> 3 != 1:
        err.append("tier prefixes overlap on bit 31")

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
            ops[f] = ((k + 1) * 0x2B) & ((1 << field_width(f)) - 1)
        word = encode(inst, ops)
        tier = "dual" if (word >> 31) & 1 else "classic"
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
            if extract(f, word) != v:
                err.append("%s: field %s does not round trip (%d -> %d)"
                           % (inst["mnemonic"], f, v, extract(f, word)))

    for e in err:
        print("error: " + e)
    print("%d fields, %d formats, %d instructions: %s"
          % (len(FIELDS), len(FORMATS), len(INSTRUCTIONS),
             "OK" if not err else "%d ERROR(S)" % len(err)))
    return 1 if err else 0


# -------------------------------------------------------------- emit: asm
def bit_diagram(inst):
    """'[31:26]=000011 rd[25:21] rs_base[20:14] imm14[13:0]'"""
    fields, reserved, _ = FORMATS[inst["format"]]
    parts = []
    for f in fields:
        if f in ("opcode6", "opcode4"):
            parts.append("%s=%s" % (field_str(f), format(
                inst["opcode"], "0%db" % field_width(f))))
        elif f in inst["sub"]:
            parts.append("%s%s=%s" % (f, field_str(f), format(
                inst["sub"][f], "0%db" % field_width(f))))
        else:
            parts.append("%s%s" % (f, field_str(f)))
    if reserved:
        parts.append("rsvd")
    return "  ".join(parts)


def emit_asm():
    print("VLIW Load/Store slot -- instruction reference")
    print("=" * 76)
    print("\nEvery instruction is one 32-bit slot of the 128-bit VLIW word.")
    print("Sources are 7-bit global register addresses (3-bit bank + 5-bit")
    print("register, any bank); destinations are 5-bit with the bank implicit")
    print("(rd/d0 -> LS-A, d1 -> LS-B).\n")
    print(LATENCY.replace(". ", ".\n") + "\n")

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
            print("%s %s" % (i["mnemonic"], i["syntax"]))
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
    print("   // LD2 width/extension subfields")
    for nm, val in (("W_BYTE", 0), ("W_HALF", 1), ("W_WORD", 2)):
        print("   localparam logic [1:0] LS_%-6s = 2'b%s;"
              % (nm, format(val, "02b")))
    print("   localparam logic       LS_U_ZERO = 1'b1;   // zero-extend\n")
    print("   // field extraction (constant slices -- no address mux)")
    for n in FIELDS:
        if n.startswith("opcode"):
            continue
        chunks = ", ".join("inst[%d:%d]" % (m, l) if m != l else "inst[%d]" % m
                           for m, l in FIELDS[n][0])
        body = chunks if len(FIELDS[n][0]) == 1 else "{%s}" % chunks
        print("   function automatic logic [%d:0] ls_%s"
              "(input logic [31:0] inst);" % (field_width(n) - 1, n))
        print("      return %s;" % body)
        print("   endfunction\n")
    print("   /* verilator lint_on UNUSEDSIGNAL */")
    print("   /* verilator lint_on UNUSEDPARAM */")
    print("\nendpackage")


# ------------------------------------------------------------ emit: decode
def emit_decode(text):
    word = int(text, 0) if text.startswith(("0x", "0b")) else int(text, 16)
    word &= 0xFFFFFFFF
    tier = "dual" if (word >> 31) & 1 else "classic"
    opf, width, _, _ = TIERS[tier]
    op = extract(opf, word)
    hits = [i for i in INSTRUCTIONS
            if i["tier"] == tier and i["opcode"] == op
            and all(extract(f, word) == v for f, v in i["sub"].items())]
    print("word     0x%08X  (%s tier, opcode %s)"
          % (word, tier, format(op, "0%db" % width)))
    if not hits:
        print("         reserved opcode -> illegal-instruction trap")
        return
    inst = hits[0]
    print("mnemonic %s %s" % (inst["mnemonic"], inst["syntax"]))
    for f in FORMATS[inst["format"]][0]:
        if f.startswith("opcode"):
            continue
        v = extract(f, word)
        note = ""
        if FIELDS[f][1] in ("read 1", "read 2", "read 3", "read 4"):
            note = "  (bank %d, reg %d)" % (v >> 5, v & 0x1F)
        print("  %-9s %-18s = %d%s" % (f, field_str(f), v, note))


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
        print()
        emit()
    return 0


if __name__ == "__main__":
    sys.exit(main())
