# Generic Xilinx Compilation with a Non-Project Flow
# Copyright (C) 2013-2014 Christophe Clienti - All Rights Reserved

XIL_PART           ?= "xc7z020clg484-1"
XIL_SYNTH_OPTIONS  ?= -flatten_hierarchy full -no_iobuf
XIL_TCL_SCRIPT      = vivado.tcl


help::
	@echo "xilinx_syn - synthesize using the vivado synthesizer (XIL_PART=$(XIL_PART))"

xilinx_syn: $(XIL_TCL_SCRIPT)
	vivado -mode tcl -source $(XIL_TCL_SCRIPT)

$(XIL_TCL_SCRIPT): $(ALL_TOP_FILES)
	@echo "Generating $(XIL_TCL_SCRIPT)"
	@echo "### Xilinx $(TOP_MODULE) project" > $(XIL_TCL_SCRIPT)
	@echo "set outputDir ./xilinx/$(TOP_MODULE)" >> $(XIL_TCL_SCRIPT)
	@echo 'file mkdir $$outputDir' >> $(XIL_TCL_SCRIPT)

	@for dep in $^ ; do \
	    echo "read_verilog -sv $$dep" >> $(XIL_TCL_SCRIPT)  ; \
	done

	@echo "synth_design -top $(TOP_MODULE) -part $(XIL_PART) $(XIL_SYNTH_OPTIONS) -include_dirs \"$(INCLUDE_DIRS)\"" >> $(XIL_TCL_SCRIPT)
	@echo 'write_verilog -force -include_xilinx_libs -mode funcsim $$outputDir/$(TOP_MODULE)_simsyn.v' >> $(XIL_TCL_SCRIPT)
	@echo 'write_verilog -force -mode design $$outputDir/$(TOP_MODULE)_syn.v' >> $(XIL_TCL_SCRIPT)
	@echo 'report_utilization -file $$outputDir/post_synth_util.rpt' >> $(XIL_TCL_SCRIPT)
	@echo "quit" >> $(XIL_TCL_SCRIPT)

clean:: xilinx_clean

xilinx_clean:
	rm -rf *.log *.jou tmp .Xil xilinx vivado.tcl


# # STEP#1: define the output directory area.
# #
# set outputDir ./Tutorial_Created_Data/cpu_output
# file mkdir $outputDir
# #
# # STEP#2: setup design sources and constraints
# #
# read_vhdl -library bftLib [ glob ./Sources/hdl/bftLib/*.vhdl ]
# read_vhdl ./Sources/hdl/bft.vhdl
# read_verilog [ glob ./Sources/hdl/*.v ]
# read_verilog [ glob ./Sources/hdl/mgt/*.v ]
# read_verilog [ glob ./Sources/hdl/or1200/*.v ]
# read_verilog [ glob ./Sources/hdl/usbf/*.v ]
# read_verilog [ glob ./Sources/hdl/wb_conmax/*.v ]
# read_xdc ./Sources/top_full.xdc
# #
# # STEP#3: run synthesis, write design checkpoint, report timing,
# # and utilization estimates
# #
# synth_design -top top -part xc7k70tfbg676-2
# write_checkpoint -force $outputDir/post_synth.dcp
# report_timing_summary -file $outputDir/post_synth_timing_summary.rpt
# report_utilization -file $outputDir/post_synth_util.rpt
# #
# # Run custom script to report critical timing paths
# Using Tcl Scripting
# UG894 (v2013.2) June 19, 2013
# www.xilinx.com
# 10Compilation and Reporting Example Scripts
# reportCriticalPaths $outputDir/post_synth_critpath_report.csv
# #
# # STEP#4: run logic optimization, placement and physical logic optimization,
# # write design checkpoint, report utilization and timing estimates
# #
# opt_design
# reportCriticalPaths $outputDir/post_opt_critpath_report.csv
# place_design
# report_clock_utilization -file $outputDir/clock_util.rpt
# #
# # Optionally run optimization if there are timing violations after placement
# if {[get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]] < 0} {
# puts "Found setup timing violations => running physical optimization"
# phys_opt_design
# }
# write_checkpoint -force $outputDir/post_place.dcp
# report_utilization -file $outputDir/post_place_util.rpt
# report_timing_summary -file $outputDir/post_place_timing_summary.rpt
# #
# # STEP#5: run the router, write the post-route design checkpoint, report the routing
# # status, report timing, power, and DRC, and finally save the Verilog netlist.
# #
# route_design
# write_checkpoint -force $outputDir/post_route.dcp
# report_route_status -file $outputDir/post_route_status.rpt
# report_timing_summary -file $outputDir/post_route_timing_summary.rpt
# report_power -file $outputDir/post_route_power.rpt
# report_drc -file $outputDir/post_imp_drc.rpt
# write_verilog -force $outputDir/cpu_impl_netlist.v -mode timesim -sdf_anno true
# #
# # STEP#6: generate a bitstream
# #
# write_bitstream -force $outputDir/cpu.bit
