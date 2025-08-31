#***************************************************************************************
# Copyright (c) 2014-2024 Zihao Yu, Nanjing University
#
# NEMU is licensed under Mulan PSL v2.
# You can use this software according to the terms and conditions of the Mulan PSL v2.
# You may obtain a copy of Mulan PSL v2 at:
#          http://license.coscl.org.cn/MulanPSL2
#
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
# EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
# MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
#
# See the Mulan PSL v2 for more details.
#**************************************************************************************/

CSRCS-y += csrc/npc-main.c
DIRS-y += csrc/cpu csrc/monitor csrc/utils
DIRS-$(CONFIG_MODE_SYSTEM) += csrc/memory
DIRS-BLACKLIST-$(CONFIG_TARGET_AM) += csrc/monitor/sdb

SHARE = $(if $(CONFIG_TARGET_SHARE),1,0)
LDFLAGS += $(if $(CONFIG_TARGET_NATIVE_ELF),-lreadline -ldl -pie,)

ifdef mainargs
ASFLAGS += -DBIN_PATH=\"$(mainargs)\"
endif
SRCS-$(CONFIG_TARGET_AM) += csrc/am-bin.S
.PHONY: csrc/am-bin.S
