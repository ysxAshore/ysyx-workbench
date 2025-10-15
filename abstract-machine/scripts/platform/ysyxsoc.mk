AM_SRCS := riscv/ysyxsoc/start.S \
           riscv/ysyxsoc/trm.c \
           riscv/ysyxsoc/ioe.c \
		   riscv/ysyxsoc/uart.c \
		   riscv/ysyxsoc/timer.c \
		   riscv/ysyxsoc/input.c \
		   riscv/ysyxsoc/gpu.c \
           riscv/ysyxsoc/cte.c \
           riscv/ysyxsoc/trap.S \
           platform/dummy/vme.c \
           platform/dummy/mpe.c

CFLAGS    += -I$(AM_HOME)/am/src/riscv/ysyxsoc/include
CFLAGS    += -fdata-sections -ffunction-sections
LDSCRIPTS += $(AM_HOME)/scripts/ysyxsoc_linker.ld
LDFLAGS   += --defsym=_flash_start=0x30000000 \
			 --defsym=_sram_start=0x0f000000 \
			 --defsym=_psram_start=0x80000000 \
			 --defsym=_sdram_start=0xa0000000
LDFLAGS   += --gc-sections -e _fsbl

CONFIG_TIME_ZONE := $(shell grep ^CONFIG_TIME_ZONE= $(NPC_HOME)/include/config/auto.conf | cut -d= -f2)
CFLAGS += -DCONFIG_TIME_ZONE=$(CONFIG_TIME_ZONE)

MAINARGS_MAX_LEN = 64
MAINARGS_PLACEHOLDER = the_insert-arg_rule_in_Makefile_will_insert_mainargs_here
CFLAGS += -DMAINARGS_MAX_LEN=$(MAINARGS_MAX_LEN) -DMAINARGS_PLACEHOLDER=$(MAINARGS_PLACEHOLDER)

YSYXSOC_FLAGS += -l $(shell dirname $(IMAGE).elf)/ysyxsoc-log.txt -e $(shell realpath $(IMAGE).elf) -b

insert-arg: image
	@python $(AM_HOME)/tools/insert-arg.py $(IMAGE).bin $(MAINARGS_MAX_LEN) $(MAINARGS_PLACEHOLDER) "$(mainargs)"

image: image-dep
	@$(OBJDUMP) -d $(IMAGE).elf > $(IMAGE).txt
	@echo + OBJCOPY "->" $(IMAGE_REL).bin
	@$(OBJCOPY) -O binary -j .fsbl -j .ssbl -j .user_program $(IMAGE).elf $(IMAGE).bin

run: insert-arg
	$(MAKE) -C $(NPC_HOME) ISA=$(ISA) run ARGS="$(YSYXSOC_FLAGS)" IMG=$(IMAGE).bin

gdb: insert-arg
	$(MAKE) -C $(NPC_HOME) ISA=$(ISA) gdb ARGS="$(NEMUFLAGS)" IMG=$(IMAGE).bin

.PHONY: insert-arg
