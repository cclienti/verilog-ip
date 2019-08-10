libverilator.a: verilated.d verilated_save.d verilated_vcd_c.d verilated_vpi.d \
		verilated.o verilated_save.o verilated_vcd_c.o verilated_vpi.o
	$(AR) rcs $@ verilated.o verilated_save.o verilated_vcd_c.o verilated_vpi.o

verilated.d: $(VERILATOR_ROOT)/include/verilated.cpp
	$(CXX) $(CXXFLAGS) -MM -MF $@ $<

verilated.o: $(VERILATOR_ROOT)/include/verilated.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

verilated_save.d: $(VERILATOR_ROOT)/include/verilated_save.cpp
	$(CXX) $(CXXFLAGS) -MM -MF $@ $<

verilated_save.o: $(VERILATOR_ROOT)/include/verilated_save.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

verilated_vcd_c.d: $(VERILATOR_ROOT)/include/verilated_vcd_c.cpp
	$(CXX) $(CXXFLAGS) -MM -MF $@ $<

verilated_vcd_c.o: $(VERILATOR_ROOT)/include/verilated_vcd_c.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

verilated_vpi.d: $(VERILATOR_ROOT)/include/verilated_vpi.cpp
	$(CXX) $(CXXFLAGS) -MM -MF $@ $<

verilated_vpi.o: $(VERILATOR_ROOT)/include/verilated_vpi.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

-include verilated.d
-include verilated_save.d
-include verilated_vcd_c.d
-include verilated_vpi.d
