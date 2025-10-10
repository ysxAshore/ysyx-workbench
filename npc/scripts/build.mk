.DEFAULT_GOAL = app

ifneq ($(CONFIG_YSYXSOC),)
TOPNAME = ysyxSoCFull
else
TOPNAME = npc_top
endif

WORK_DIR  = $(shell pwd)
BUILD_DIR = $(WORK_DIR)/build
$(shell mkdir -p $(BUILD_DIR))

# import nxdc constr
NXDC_FILES = constr/ysyxSoCFull.nxdc

# auto_bind.cpp 
SRC_AUTO_BIND = $(abspath $(BUILD_DIR)/auto_bind.cpp)
$(SRC_AUTO_BIND): $(NXDC_FILES)
	python3 $(NVBOARD_HOME)/scripts/auto_pin_bind.py $^ $@

OBJ_DIR  = $(BUILD_DIR)/obj-dir
BINARY   = $(BUILD_DIR)/$(TOPNAME)
INC_PATH += $(WORK_DIR)/include

INCFLAGS = $(addprefix -I, $(INC_PATH))
CXXFLAGS += -g $(INCFLAGS) -DTOP_NAME="\"V$(TOPNAME)\"" -D__GUEST_ISA__=$(GUEST_ISA)
CSRCS += $(SRC_AUTO_BIND)

# rules for NVBoard
include $(NVBOARD_HOME)/scripts/nvboard.mk

.PHONY: app clean

app: $(BINARY)

$(BINARY): $(VSRCS) $(CSRCS) $(NVBOARD_ARCHIVE)
	$(VERILATOR) $(VERILATOR_CFLAGS) \
		--top-module $(TOPNAME) $^ \
		$(addprefix -CFLAGS , $(CXXFLAGS)) \
		$(addprefix -LDFLAGS , $(LDFLAGS)) \
		--Mdir $(OBJ_DIR) \
		-o $(abspath $(BINARY))

clean:
	-rm -rf $(BUILD_DIR)
