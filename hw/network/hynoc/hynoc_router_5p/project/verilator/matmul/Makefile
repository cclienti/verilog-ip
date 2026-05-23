VERILATOR_ROOT = /usr/share/verilator
LIB_DIR        = ../lib

CXX      = g++
CXXFLAGS = -std=c++17 -O2 \
           -I$(LIB_DIR) \
           -I$(VERILATOR_ROOT)/include

TARGET = matmul

$(TARGET): matmul.o
	$(CXX) $(CXXFLAGS) $< \
		-Wl,--whole-archive $(LIB_DIR)/Vhynoc_router_5p__ALL.a -Wl,--no-whole-archive \
		$(LIB_DIR)/libverilated.a \
		-pthread -o $@

matmul.o: matmul.cpp $(LIB_DIR)/Vhynoc_router_5p.h
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(TARGET) matmul.o

.PHONY: clean
