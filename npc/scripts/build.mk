.DEFAULT_GOAL = app

TOPNAME = top
WORK_DIR  = $(shell pwd)
BUILD_DIR = $(WORK_DIR)/build
$(shell mkdir -p $(BUILD_DIR))

OBJ_DIR  = $(BUILD_DIR)/obj-dir
BINARY   = $(BUILD_DIR)/$(TOPNAME)
INC_PATH := $(WORK_DIR)/include $(INC_PATH)

INCFLAGS = $(addprefix -I, $(INC_PATH))
CXXFLAGS += -g $(INCFLAGS) -DTOP_NAME="\"V$(TOPNAME)\"" -D__GUEST_ISA__=$(GUEST_ISA)
# Some convenient rules

.PHONY: app clean

app: $(BINARY)

$(BINARY): $(VSRCS) $(CSRCS)
	$(VERILATOR) $(VERILATOR_CFLAGS) \
		--top-module $(TOPNAME) $^ \
		$(addprefix -CFLAGS , $(CXXFLAGS)) \
		$(addprefix -LDFLAGS , $(LDFLAGS)) \
		--Mdir $(OBJ_DIR) \
		-o $(abspath $(BINARY))

clean:
	-rm -rf $(BUILD_DIR)
