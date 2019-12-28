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


# Display list of targets. The double semicolon allows to call the
# help target in each included .mk file.
help::
	@echo "distclean - remove generated files and project files"
	@echo "clean - remove generated files"

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
