# Common Makefile parts
# Copyright (C) 2013 Christophe Clienti - All Rights Reserved

# Each project should declare the following variables:
TOP_MODULE           ?= top
TOP_FILE             ?= $(TOP_MODULE).v
TOP_DEPS             ?=

TESTBENCH_MODULE     ?= top_tb
TESTBENCH_FILE       ?= $(TESTBENCH_MODULE).v
TESTBENCH_DEPS       ?=


# Function to retrieve files
get-file = $(shell \
	     deps=$$(realpath $1); \
	     for dep in $2; do \
	       if [ -f $$dep ]; then \
	         deps="$$deps $$(realpath $$dep)"; \
	       else \
	         deps="$$deps $$($(MAKE) --no-print-directory -C $$(realpath $$dep)/project eval-$3)";\
	       fi \
	     done; \
	     echo "$$deps" | sort -u)

# Gather all module and testbench files
ALL_TOP_FILES    := $(call get-file,$(TOP_FILE),$(TOP_DEPS),ALL_TOP_FILES)
ALL_TEST_FILES   := $(call get-file,$(TESTBENCH_FILE),$(TESTBENCH_DEPS),ALL_TOP_FILES)
ALL_SOURCE_FILES := $(sort $(ALL_TOP_FILES) $(ALL_TEST_FILES))


.PHONY: help clean distclean

# Targets are named <action>.<tool>: the action is what you want done,
# the tool is who does it. Several vendors do the same job here, so the
# tool cannot be left implicit -- that is how one viewer ended up as
# `trace` and the next one as `trace-surfer`.
#
# Each .mk file registers its targets below instead of echoing them from
# its own help:: rule. Echoing put the listing in include order, which
# groups by tool and scatters the same action across the output; one
# rule over one list can sort it, so every sim.* sits next to the others.
#
# An entry is a single shell-quoted word, so a description may contain
# spaces: make drops the list into the command line and the shell splits
# it back on the quotes.
HELP_ENTRIES += 'clean|remove the generated files that rebuild in seconds'
HELP_ENTRIES += 'distclean|also remove project files and tool results (synthesis, place & route)'

help:
	@echo "Targets are named <action>.<tool>. Available here:"
	@echo ""
	@printf '%s\n' $(HELP_ENTRIES) | LC_ALL=C sort -u | awk -F'|' 'NF==2 {printf "  %-25s %s\n", $$1, $$2}'

# Useful to debug makefile variable value
print-%:
	@echo "$* = $($*)"

# Useful to debug makefile variable value
eval-%:
	@echo "$($*)"

# Full Clean rule. The double semicolon allows to call the help target
# in each included .mk file.
distclean:: clean

# Clean rule. The double semicolon allows to call the help target in
# each included .mk file.
clean::
	rm -rf *~ *# ../src/*~ ../src/*# __pycache__
