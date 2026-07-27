#!/usr/bin/env python3
"""CRT (prime-interleaved) memory addressing — verification model.

Trade study for the hw/vliw core: M prime banks (default 3), each 2^k words.

Forward map (hardware: per-access, core LS interfaces):
    bank(addr)  = addr mod M          -- digit-sum LUT tree, no divider
    index(addr) = addr mod 2^k        -- low k bits, free

Reverse map (hardware: NI bank-major mode / debug tools):
    addr = t * 2^k + index  ==  {t, index}   (bit concatenation)
    t    = (bank - index) * inv(2^k mod M)  (mod M)
    -- the modular inverse is a DESIGN-TIME CONSTANT (self-inverse for M=3)

Checks performed:
  1. forward map is a bijection [0, M*2^k) -> banks x indices
  2. reverse(forward(a)) == a, and the mod-M inverse constants
  3. hardware-style digit-sum mod trees == Python '%'
  4. dual-access conflict rule: bank collision iff stride % M == 0
  5. NI linear walk with incremental residue (no per-beat mod)
  6. NI bank-major walk with the period-M incremental sequencer (no divide)
  7. out-of-range addresses alias in-range cells (=> must be bound-checked)

Run:  python3 crt_addressing.py            (full suite, M=3 and M=5)
      python3 crt_addressing.py -M 3 -k 10 (single config)
"""

import argparse
import random
import sys

# ----------------------------------------------------------------------------
# Reference maps
# ----------------------------------------------------------------------------

def forward(addr: int, M: int, k: int) -> tuple[int, int]:
    """addr -> (bank, index). Hardware cost: mod-M tree + wire (low bits)."""
    return addr % M, addr & ((1 << k) - 1)


def reverse(bank: int, index: int, M: int, k: int) -> int:
    """(bank, index) -> addr, via CRT reconstruction.

    t = (bank - index) * c_inv (mod M), with c = 2^k mod M.
    c_inv is a constant folded at design time. addr = {t, index}.
    """
    c = pow(2, k, M)
    c_inv = pow(c, -1, M)                 # design-time constant
    t = ((bank - index) * c_inv) % M
    return (t << k) | index


# ----------------------------------------------------------------------------
# Hardware-style mod-M digit trees (emulating the LUT structure)
# ----------------------------------------------------------------------------

def mod_tree_sum(addr: int, M: int, d: int) -> int:
    """Digit-sum tree: valid when 2^d == 1 (mod M) (e.g. M=3,d=2; M=5,d=4).

    Leaves: each d-bit digit reduced mod M. Nodes: (a+b) mod M — one small
    LUT per node. Tree depth = ceil(log2(#digits)).
    """
    assert pow(2, d, M) == 1, "digit base must satisfy 2^d == 1 mod M"
    digits = []
    while addr:
        digits.append((addr & ((1 << d) - 1)) % M)   # leaf LUT
        addr >>= d
    if not digits:
        return 0
    while len(digits) > 1:                            # adder tree
        nxt = [(digits[i] + digits[i + 1]) % M
               for i in range(0, len(digits) - 1, 2)]
        if len(digits) % 2:
            nxt.append(digits[-1])
        digits = nxt
    return digits[0]


def mod_fold_alt(addr: int, M: int, d: int) -> int:
    """Alternating digit fold: valid when 2^d == -1 (mod M) (e.g. M=5,d=2).

    Digits carry weights +1, -1, +1, ... (casting-out-elevens style).
    """
    assert pow(2, d, M) == M - 1, "digit base must satisfy 2^d == -1 mod M"
    acc, sign, i = 0, 1, 0
    while addr:
        acc += sign * ((addr & ((1 << d) - 1)) % M)
        addr >>= d
        sign = -sign
        i += 1
    return acc % M


# ----------------------------------------------------------------------------
# Test 1+2 — bijectivity and reconstruction
# ----------------------------------------------------------------------------

def test_bijection(M: int, k: int) -> None:
    size = M << k
    seen = set()
    per_bank = [set() for _ in range(M)]
    for a in range(size):
        b, i = forward(a, M, k)
        assert (b, i) not in seen, f"collision: addr {a} -> ({b},{i})"
        seen.add((b, i))
        per_bank[b].add(i)
        assert reverse(b, i, M, k) == a, f"reverse broken at addr {a}"
    for b in range(M):
        assert per_bank[b] == set(range(1 << k)), f"bank {b} not fully used"

    c = pow(2, k, M)
    c_inv = pow(c, -1, M)
    if M == 3:
        assert c_inv == c, "mod 3: 2^k must be self-inverse (1 or 2)"
    print(f"  [ok] bijection + reverse map  (M={M}, k={k}, "
          f"{size} addrs; c=2^k mod {M}={c}, c_inv={c_inv})")


# ----------------------------------------------------------------------------
# Test 3 — hardware mod trees
# ----------------------------------------------------------------------------

def test_mod_trees(M: int, k: int) -> None:
    hi = (M << k) - 1
    samples = list(range(min(hi + 1, 4096))) + \
        [random.randrange(hi + 1) for _ in range(2000)]
    if M == 3:
        for a in samples:
            assert mod_tree_sum(a, 3, 2) == a % 3
        print("  [ok] mod-3 digit-sum tree (base-4 digits, 4=1 mod 3)")
    if M == 5:
        for a in samples:
            assert mod_tree_sum(a, 5, 4) == a % 5
            assert mod_fold_alt(a, 5, 2) == a % 5
        print("  [ok] mod-5 nibble-sum tree (16=1) and base-4 "
              "alternating fold (4=-1)")


# ----------------------------------------------------------------------------
# Test 4 — dual-access conflict rule (LD2/ST2: addr and addr+stride)
# ----------------------------------------------------------------------------

def test_conflicts(M: int, k: int) -> None:
    size = M << k
    for s in range(-(3 * M), 3 * M + 1):
        if s == 0:
            continue
        expect = (s % M == 0)
        for a in range(size):
            if 0 <= a + s < size:
                clash = forward(a, M, k)[0] == forward(a + s, M, k)[0]
                assert clash == expect, f"stride {s}, addr {a}"
    # random-pair collision rate ~ 1/M (gather estimate)
    n, hits = 20000, 0
    for _ in range(n):
        a, b = random.randrange(size), random.randrange(size)
        hits += forward(a, M, k)[0] == forward(b, M, k)[0]
    print(f"  [ok] conflict iff stride % {M} == 0 ; random-pair collision "
          f"rate {hits/n:.3f} (theory {1/M:.3f})")


# ----------------------------------------------------------------------------
# Test 5 — NI linear walk, incremental residue (no per-beat mod)
# ----------------------------------------------------------------------------

def test_ni_linear_walk(M: int, k: int) -> None:
    size = M << k
    mask = (1 << k) - 1
    for _ in range(200):
        stride = random.randrange(1, 5 * M)
        beats = random.randrange(1, 200)
        base = random.randrange(size - 1)
        # descriptor setup: ONE full mod (software or one tree pass)
        r = base % M
        s_res = stride % M              # 2-3 bit constant per descriptor
        addr = base
        for _ in range(beats):
            if addr >= size:
                break                    # bound check (aliasing, test 7)
            assert (r, addr & mask) == forward(addr, M, k)
            r = r + s_res               # 2-3 bit accumulator...
            if r >= M:
                r -= M                  # ...with conditional subtract
            addr += stride
    print("  [ok] NI linear walk: incremental residue == direct map "
          "(no per-beat mod)")


# ----------------------------------------------------------------------------
# Test 6 — NI bank-major walk, period-M sequencer (no divide, no inverse
#          at run time: t steps by -c_inv mod M, a constant)
# ----------------------------------------------------------------------------

def test_ni_bank_major(M: int, k: int) -> None:
    c_inv = pow(pow(2, k, M), -1, M)     # design-time constant
    for bank in range(M):
        t = (bank * c_inv) % M           # t at index 0: (b-0)*c_inv
        for i in range(1 << k):
            addr = (t << k) | i
            assert forward(addr, M, k) == (bank, i), \
                f"bank-major sequencer broken at bank {bank}, i {i}"
            t -= c_inv                   # tiny counter, period M
            if t < 0:
                t += M
    print("  [ok] NI bank-major walk: period-"
          f"{M} incremental sequencer == reverse map")


# ----------------------------------------------------------------------------
# Test 7 — out-of-range addresses alias valid cells -> must trap/bound-check
# ----------------------------------------------------------------------------

def test_aliasing(M: int, k: int) -> None:
    size = M << k
    top = 1 << (size - 1).bit_length()   # next power of 2 >= size
    aliased = 0
    for a in range(size, top):
        b, i = forward(a, M, k)
        pre = reverse(b, i, M, k)
        assert pre < size and pre != a
        aliased += 1
    print(f"  [ok] {aliased} out-of-range addrs ({size}..{top-1}) alias "
          "in-range cells -> decoder must bound-check")


# ----------------------------------------------------------------------------
# Demo table (the spec example)
# ----------------------------------------------------------------------------

def demo_table(M: int, k: int) -> None:
    print(f"\n  addr -> (bank, index) for M={M}, k={k} "
          f"(total {M << k} words):")
    for a in range(M << k):
        b, i = forward(a, M, k)
        print(f"    {a:3d} -> bank {b}, index {i}")


def run_suite(M: int, k: int, table: bool) -> None:
    print(f"config: M={M} banks (prime), depth 2^{k} = {1 << k} words/bank, "
          f"total {M << k} words, addr width {((M << k) - 1).bit_length()} bits")
    assert M % 2 == 1, "bank count must be odd (coprime with 2^k)"
    test_bijection(M, k)
    test_mod_trees(M, k)
    test_conflicts(M, k)
    test_ni_linear_walk(M, k)
    test_ni_bank_major(M, k)
    test_aliasing(M, k)
    if table:
        demo_table(M, k)
    print()


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("-M", type=int, help="bank count (odd prime)")
    p.add_argument("-k", type=int, help="log2 of bank depth")
    p.add_argument("--table", action="store_true", help="print full map")
    args = p.parse_args()
    random.seed(42)

    if args.M or args.k:
        run_suite(args.M or 3, args.k or 4, args.table)
    else:
        run_suite(3, 2, table=True)      # the worked example from the spec
        run_suite(3, 4, table=False)
        run_suite(3, 10, table=False)    # realistic: 3 x 1K words
        run_suite(5, 2, table=False)     # the user's 4/5-style config
        run_suite(5, 8, table=False)
    print("ALL TESTS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
