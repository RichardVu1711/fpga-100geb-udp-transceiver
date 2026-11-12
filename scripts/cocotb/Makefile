#user-define directories
ENTRY       ?=$(PWD)
TEST_DIR    :=$(ENTRY)/tests
HDL_DIR     :=$(ENTRY)/src
PKG_DIR     :=$(ENTRY)/include
SIM_DIR     :=$(ENTRY)/build/sim

$(info ENTRY: $(ENTRY))
#user custom parameters
FILTER   ?= .*
UUT      ?= RXTop
UUT_LC   := $(shell echo $(UUT) | tr A-Z a-z)
# Potential UUTs that are used for integration tests
INT_UUTS := RXTop TXTop
INTEGRATION_TBS     := $(basename $(notdir $(wildcard $(TEST_DIR)/rtl_sim/integration/$(UUT)*_tb.py)))
INTEGRATION_TBS     += $(basename $(notdir $(wildcard $(TEST_DIR)/rtl_sim/integration/$(UUT_LC)*_tb.py)))
$(info INTEGRATION_TBS: $(INTEGRATION_TBS))
empty               :=
space               := $(empty) $(empty)
comma               := ,
INTEGRATION_MODULES := $(subst $(space),$(comma),$(INTEGRATION_TBS))
# If the UUT is on the list of integration, they will be used with integration modules
UUT_TB              ?= $(if $(filter $(UUT),$(INT_UUTS)),$(INTEGRATION_MODULES), $(UUT)_tb)
#cocotb parameters
SIM                 ?= verilator
TOPLEVEL_LANG       ?= verilog
VERILOG_SOURCES     := $(wildcard $(PKG_DIR)/*.sv)
VERILOG_SOURCES     += $(wildcard $(HDL_DIR)/*.sv)
VERILOG_SOURCES     += $(wildcard $(HDL_DIR)/*.v)
SIM_BUILD           := $(SIM_DIR)
export PYTHONPATH   := $(TEST_DIR)/common:$(TEST_DIR)/rtl_sim:$(TEST_DIR)/rtl_sim/unit:$(TEST_DIR)/rtl_sim/integration:$(PYTHONPATH)

COCOTB_TOPLEVEL     := $(UUT)
COCOTB_TEST_MODULES := $(UUT_TB)
COCOTB_RESULTS_FILE := $(SIM_BUILD)/results.xml
COCOTB_TEST_FILTER  := $(FILTER)

#verilator waveform enable
WAVES := 1
EXTRA_ARGS += --trace --trace-structs -Wall --public --top-module $(UUT)
COMPILE_ARGS += --public
#include cocotb's make rules
#include cocotb configs
include $(shell cocotb-config --makefiles)/Makefile.sim