# Generic Quartus Compilation Flow
# Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved

QUARTUS_TOP_MODULE      ?= $(TOP_MODULE)
QUARTUS_PROJECT_NAME    ?= $(QUARTUS_TOP_MODULE)
QUARTUS_FAMILY          ?= "Cyclone IV E"
QUARTUS_PART            ?= "EP4CE22F17C6"
QUARTUS_BOARDFILE       ?= ../boards/de0_nano/de0_nano_pin.tcl
QUARTUS_CONSTFILE       ?= ../boards/de0_nano/de0_nano.sdc
QUARTUS_CUSTOM_SCRIPT   ?= custom.tcl

QUARTUS_PROJECT_FILES    = quartus-project/$(QUARTUS_PROJECT_NAME).qpf quartus-project/$(QUARTUS_PROJECT_NAME).qsf


help::
	@echo "quartus-project - generate the quartus qpf/qsf files"

quartus-project: $(QUARTUS_PROJECT_FILES)

$(QUARTUS_PROJECT_FILES):
	@echo mkdir -p quartus-project
	@quartus_sh --prepare -f $(QUARTUS_FAMILY) -d $(QUARTUS_PART) \
	    -t $(QUARTUS_TOP_MODULE) $(QUARTUS_PROJECT_NAME)
	@echo "" >> $(QUARTUS_PROJECT_NAME).qsf # Add empty line
	@[ -f $(QUARTUS_BOARDFILE) ] && cat $(QUARTUS_BOARDFILE) >> $(QUARTUS_PROJECT_NAME).qsf || true
	@[ -f $(QUARTUS_CUSTOM_SCRIPT) ] && cat $(QUARTUS_CUSTOM_SCRIPT) >> $(QUARTUS_PROJECT_NAME).qsf || true
	@[ -f $(QUARTUS_CONSTFILE) ] && cat $(QUARTUS_CONSTFILE) >> $(QUARTUS_PROJECT_NAME).qsf || true
	@for vfile in $(ALL_TOP_FILES); do \
	    echo "set_global_assignment -name SYSTEMVERILOG_FILE $${vfile}" >> $(QUARTUS_PROJECT_NAME).qsf; \
	done

distclean:: quartus-distclean

quartus-distclean: clean
	rm -rf quartus-project

clean::
	cd quartus-project > /dev/null 2>&1 && rm -rf *.rpt *.chg smart.log *.htm *.eqn *.pin *.sof *.pof db incremental_db *.qws || true
	cd quartus-project > /dev/null 2>&1 && rm -rf *.done *.smsg *.jdi *.sld *.cdf 2> /dev/null 2>&1 || true
