# Generic VToV Makefile
# Copyright (C) 2016 Christophe Clienti - All Rights Reserved

VTOV           = $(VTOV_PATH)/vtov.py
VTOV_DIR       = vtov
VTOV_FILE      = $(VTOV_DIR)/$(TOP_MODULE).v

ifneq ($(INCLUDE_DIRS),)
VTOV_INCLUDE_DIRS   = -I$(INCLUDE_DIRS)
endif

vtov_icarus_vcd: vtov_inline vtov_lint
	$(MAKE) TOP_FILE=$(VTOV_FILE) vcd

vtov_lint: vtov_inline
	$(MAKE) TOP_FILE=$(VTOV_FILE) lint

vtov_inline: $(VTOV_DIR) $(VTOV_FILE)

$(VTOV_DIR):
	mkdir -p $@

$(VTOV_FILE): $(TOP_FILE) $(TOP_DEPS)
ifeq ($(OBFUSCATE),1)
	@$(VTOV) $(VTOV_INCLUDE_DIRS) -o $(VTOV_FILE).not_obfuscated -t $(TOP_MODULE) inline $^
	@$(VTOV) obfuscate -o $@ $(VTOV_FILE).not_obfuscated
else
	@$(VTOV) $(VTOV_INCLUDE_DIRS) -o $@ -t $(TOP_MODULE) inline $^
endif

clean:: vtov_clean

vtov_clean:
	rm -rf $(VTOV_DIR)
