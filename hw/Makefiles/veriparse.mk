VERIFLAT          ?= veriflat
VERIFLAT_FLAGS    += --seed 0
VERIOBF           ?= veriobf
VERIOBF_FLAGS     += --id-length 16 --seed 0

REPO_PATH	   = $(shell git rev-parse --show-toplevel)
VERIFLAT_PP_DIR    = preproc

VERIFLAT_INPUTS    = $(ALL_TOP_FILES)
VERIFLAT_PP        = $(subst $(REPO_PATH),$(VERIFLAT_PP_DIR),$(abspath $(VERIFLAT_INPUTS:.v=.pp)))

VERIFLAT_OUTPUT    = $(TOP_MODULE)_flat.v
VERIOBF_INPUT      = $(VERIFLAT_OUTPUT)
VERIOBF_OUTPUT     = $(TOP_MODULE)_obf.v


help::
	@echo "veriobf - obfuscate flattened design using veriparse"
	@echo "veriflat - flatten design using veriparse"

veriobf: $(VERIOBF_OUTPUT)

veriflat: $(VERIFLAT_OUTPUT)

$(VERIOBF_OUTPUT): $(VERIOBF_INPUT)
	@$(VERIOBF) $(VERIOBF_FLAGS) --output $@ $^

$(VERIFLAT_OUTPUT): $(VERIFLAT_PP)
	@$(VERIFLAT) $(VERIFLAT_FLAGS) --output $@ --top-module $(TOP_MODULE) $^

preproc/%.pp: $(REPO_PATH)/%.v
	@echo "Preprocessing $<"
	@mkdir -p $(dir $@)
	@$(IVERILOG) $(IVFLAGS) -E $< -o $@

clean:: veriobf-clean veriflat-clean

veriobf-clean:
	rm -rf $(VERIOBF_OUTPUT) $(VERIOBF_TESTBENCH) veriobf.log

veriflat-clean:
	rm -rf $(VERIFLAT_PP_DIR) $(VERIFLAT_OUTPUT) $(VERIFLAT_TESTBENCH) veriflat.log
