# Generic Quartus Compilation Flow
# Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved

QUARTUS_TOP_MODULE    ?= top
QUARTUS_PROJECT_NAME  ?= $(QUARTUS_TOP_MODULE)
QUARTUS_FAMILY        ?= "Cyclone IV E"
QUARTUS_PART          ?= "EP4CE22F17C6"
QUARTUS_BOARDFILE     ?=
QUARTUS_CUSTOM_SCRIPT ?= custom.tcl

QUARTUS_PROJECT_FILES  = $(QUARTUS_PROJECT_NAME).qpf $(QUARTUS_PROJECT_NAME).qsf

help::
	@echo "quartus-project - generate the quartus qpf/qsf files"

quartus-project: $(QUARTUS_PROJECT_FILES)

$(QUARTUS_PROJECT_FILES):
	quartus_sh --prepare -f $(QUARTUS_FAMILY) -d $(QUARTUS_PART) -t $(QUARTUS_TOP_MODULE) $(QUARTUS_PROJECT_NAME)
	echo "" >> $(QUARTUS_PROJECT_NAME).qsf # Add empty line
	cat $(QUARTUS_BOARDFILE) >> $(QUARTUS_PROJECT_NAME).qsf
	[ -f $(QUARTUS_CUSTOM_SCRIPT) ] && cat $(QUARTUS_CUSTOM_SCRIPT) >> $(QUARTUS_PROJECT_NAME).qsf || true

quartus-distclean: clean
	rm -rf *.qpf *.qsf *.summary

clean::
	rm -rf *.rpt *.chg smart.log *.htm *.eqn *.pin *.sof *.pof db incremental_db *.qws
	rm -rf *.done *.smsg *.jdi *.sld
