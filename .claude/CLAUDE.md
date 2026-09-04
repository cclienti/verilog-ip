# verilog-ip — working notes

Things that cost time or went wrong here. Everything else is discoverable
from the tree.

## House rules

- **Ask before launch Vivado, and never pattern-kill.** No `pkill
  -f`, ever — it killed User's running sessions once. List PIDs and
  kill only processes you started. He runs synthesis; you prepare it
  and read the reports, unless he asks you to run it.
- **Code, comments and identifiers in English.** Conversation is
  defined by the User; what lands in a file is English.
- **Commit messages carry the reasoning**: the measurements that decided
  it, and the alternatives tried and rejected. Several decisions here
  were reversed after measurement...
- **Commit messages use the Conventional Commits format**.
- **Commit messages must embeds the model used only**, no references
  to session, review, or model vendor email.
- **Say which numbers are measured and which are estimated.** Estimates
  from primitive counts have been wrong by 2× more than once.
- **Never edit a file in place to test a variant.** Copy to `/tmp`,
  synthesize from there, or if the build system forces an in-place swap,
  restore with an absolute path and `diff` afterwards — a `trap` that
  restores with a relative path fires from the wrong cwd and leaves the
  working file replaced.

## Build entry points

Every component has `project/Makefile` — **run make from `project/`**,
never from the component root. `TOP_DEPS` in that Makefile is what
resolves dependencies; overriding `TOP_FILE` on the command line breaks
it and yields "module not found".

Targets are named `<action>.<tool>`: `sim.iverilog`, `check.iverilog`,
`trace.gtkwave`, `trace.surfer`, `lint.verilator`, `synth.vivado`,
`impl.vivado`, `waves.wavedisp`. Several vendors do the same job here, so
the tool is never implicit. `make help` lists what a project provides,
sorted by action. The old bare names — `sim`, `trace`, `lint`,
`verilates`, `msim-sim`, `vivado-gen-post-syn` — no longer exist.

`clean` removes only what rebuilds in seconds. Synthesis and
implementation results are on `distclean`, because `clean` taking a
netlist away cost a re-synthesis once.

Iterating is faster without make:

```sh
cd hw/lib
iverilog -g2012 -o /tmp/tb.out -y dpmemrf/src \
         parmem/parmem3_2/src/parmem3_2_tb.sv parmem/parmem3_2/src/parmem3_2.sv
vvp /tmp/tb.out
```

`-y <dir>` is the module search path.

**That run produces no waveform.** No testbench names its own dump file
any more: `hw/Makefiles/dumper.v` is elaborated as a second root module
beside the bench, and the makefile passes it the name. Add it by hand to
dump from an invocation like the one above:

```sh
iverilog -g2012 -o /tmp/tb.out -y dpmemrf/src \
         -DDUMP_FILE='"/tmp/tb.fst"' -DDUMP_SCOPE=parmem3_2_tb \
         -s parmem3_2_tb -s wave_dumper \
         parmem/parmem3_2/src/parmem3_2_tb.sv parmem/parmem3_2/src/parmem3_2.sv \
         ../Makefiles/dumper.v
IVERILOG_DUMPER=fst vvp /tmp/tb.out
```

The format comes from `IVERILOG_DUMPER`, which the makefile exports and a
bare shell does not. Without it vvp writes VCD content whatever the file
is called — that mismatch is what the switch to FST was fixing.

## Testbenches

Self-checking, with an error counter and a final
`<module>_tb: ALL TESTS PASSED` or `N ERROR(S)`. A bench without a
verdict is a bug in the bench — `$display` on failure with no counter
reports success whatever happens.

**Mutation-test every new or changed bench.** Break the RTL deliberately
in a `/tmp` copy and confirm the bench fails. This caught two blind spots
in one day: an enable-gating check that could not fail by construction,
and READ_FIRST covered on port A only.

**Sweep the configuration space, not one point.** If a parameter changes
a timing path, the bench must drive every combination.

## wavedisp — waveform declarations

Python, in `project/`, two files per component: `<module>.wave.py`
returns a `Block` of the module's own `Disp` signals; `<module>_tb.wave.py`
returns a `Hierarchy('<tb>')` with one `Hierarchy('<instance>')` per DUT
that `.include()`s the module file.

Three things that are not guessable:

- Relative includes resolve **against the directory of the including
  file** — a cross-component include from `hw/lib/parmem/x/project/` is
  `'../../../dpmemrf/project/dpmemrf.wave.py'` (one `..` more than for a
  component sitting directly under `hw/lib/`).
- Generate blocks are addressed by elaborated path:
  `Hierarchy(f'gen_bank[{b}].bank_inst')`.
- wavedisp joins its input path onto its own directory, so it must be run
  **from `project/`** with a bare filename.

```sh
cd hw/lib/<component>/project
make waves.wavedisp
```

The first invocation creates a venv under `hw/Makefiles/.venv` and
pip-installs wavedisp from PyPI — that one run needs network access.
Every later run reuses it, and `make venv.wavedisp` creates it on its
own. Use that venv for direct calls too, from `project/`:

```sh
../../../Makefiles/.venv/bin/wavedisp -t gtkwave -o out.tcl <module>_tb.wave.py
```

**Keep the default view small.** GTKWave crawls once a bench declares a
few hundred traces, which is easy to reach: a testbench with several DUTs,
each pulling in its sub-hierarchies, ran to 541 signals for a three-bank
memory. Show ports by default and put detail behind keywords the
testbench opts into:

```python
def generator(nb_banks=3, internals=False, banks=False):
    ...
inst.include('parmem3_2.wave.py', internals=True)   # one DUT, not all
```

Instances that only need a couple of signals get them directly —
`inst.add(Disp(['doa', 'freeze']))` — rather than the whole module file.

**Wave files are not generated from the RTL and nothing checks them** —
when ports or instances change, update them in the same edit.

## Vivado

Vivado 2026.1 is the version in use; 2025.1 is still installed. Not on
`PATH`: the user's shell has a `load-xilinx` function that sets it up,
and shell functions do not reach the Bash tool, so replicate its three
lines. The `LD_LIBRARY_PATH` entry is not optional on this Fedora host.

```sh
export LM_LICENSE_FILE=~/Xilinx/Xilinx.lic
export LD_LIBRARY_PATH=$HOME/.local/vivado-libs:$LD_LIBRARY_PATH
source $HOME/Xilinx/2026.1/Vivado/settings64.sh
cd hw/lib/<component>/project
make impl.vivado VIVADO_PART="xc7z020clg484-1" \
     VIVADO_SYNTH_OPTIONS='"-flatten_hierarchy full -no_iobuf -generic ADRREG=1"'
```

Reports in `project/vivado-post-impl/post_impl_{timing,util}.rpt` — `Setup :`
for worst slack, `Slice LUTs` / `CLB LUTs` / `RAMB36` for area.

An I/O property change (SLEW, DRIVE, IOSTANDARD) needs no re-run: open
the routed `.dcp` with `open_checkpoint`, `set_property` it, and read
`get_timing_paths` — about 15 s, and it reproduced the full run to the
picosecond on paths with no placement freedom. Board projects: a
`hw_server` launched by `program.vivado` outlives the Vivado session;
one born while the Platform Cable was re-enumerating keeps a stale
target list until stopped by PID.

Licensed and installed parts: `xc7z020clg484-1` (z7020-1),
`xc7k160tfbg484-2` (k160-2), `xcku5p-ffvb676-2-e` (ku5p-2).

Reading the numbers: out-of-context, 5 ns, `-no_iobuf`, no I/O delays, so
about 1 ns of any critical path is an unconstrained-port artefact.
Compare configurations against each other, never against an absolute
budget. LUT counts are stable run to run; slacks within a few tens of
picoseconds are placement noise on a routing-dominated design. One run
takes minutes — six exceed the 10-minute tool timeout, so batch them.

`project/results/<device>-<option>/` holds kept reports and is
deliberately untracked, as are `vivado-post-impl/`, `*.fst` and generated
`.tcl`. `make clean` leaves `vivado-post-impl/` alone — only `distclean`
removes it.
