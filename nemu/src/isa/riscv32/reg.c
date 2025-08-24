/***************************************************************************************
 * Copyright (c) 2014-2024 Zihao Yu, Nanjing University
 *
 * NEMU is licensed under Mulan PSL v2.
 * You can use this software according to the terms and conditions of the Mulan PSL v2.
 * You may obtain a copy of Mulan PSL v2 at:
 *          http://license.coscl.org.cn/MulanPSL2
 *
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
 * EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
 * MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
 *
 * See the Mulan PSL v2 for more details.
 ***************************************************************************************/

#include <isa.h>
#include "local-include/reg.h"

const char *regs[] = {
    "$0", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
    "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
    "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
    "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"};

void isa_reg_display()
{
  for (int i = 0; i < sizeof(cpu.gpr) / sizeof(cpu.gpr[0]); i = i + 4)
    printf("%s:" FMT_WORD "\t%s:" FMT_WORD "\t%s:" FMT_WORD "\t%s:" FMT_WORD "\n", regs[i], cpu.gpr[i], regs[i + 1], cpu.gpr[i + 1], regs[i + 2], cpu.gpr[i + 2], regs[i + 3], cpu.gpr[i + 3]);
}

word_t isa_reg_str2val(const char *s, bool *success)
{
  for (int i = 1; i < sizeof(cpu.gpr) / sizeof(cpu.gpr[0]); ++i)
    if (strcmp(s, regs[i]) == 0)
      return cpu.gpr[i];
  if (strcmp(s, "pc") == 0)
    return cpu.pc;
  else
  {
    success = false;
    return 0;
  }
}
