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
#include <cpu/cpu.h>
#include <difftest-def.h>
#include <memory/paddr.h>

extern CPU_state cpu;
#define NR_GPR MUXDEF(CONFIG_RVE, 16, 32)
typedef struct
{
  word_t gprs[NR_GPR];
  word_t pc;
  word_t inst;
} DutState;

void diff_memcpy(paddr_t addr, void *buf, size_t n)
{
  for (size_t i = 0; i < n; ++i)
    paddr_write(addr + i, 1, *((uint8_t *)buf + i));
}
__EXPORT void difftest_memcpy(paddr_t addr, void *buf, size_t n, bool direction)
{
  if (direction == DIFFTEST_TO_REF)
    diff_memcpy(addr, buf, n);
  else
    assert(0);
}

void diff_set_regs(void *dut)
{
  for (int i = 0; i < NR_GPR; ++i)
    cpu.gpr[i] = ((DutState *)dut)->gprs[i];
  cpu.pc = ((DutState *)dut)->pc;
}

void diff_get_regs(void *dut)
{
  for (int i = 0; i < NR_GPR; ++i)
    ((DutState *)dut)->gprs[i] = cpu.gpr[i];
  ((DutState *)dut)->pc = cpu.pc;
}
__EXPORT void difftest_regcpy(void *dut, bool direction)
{
  if (direction == DIFFTEST_TO_REF)
    diff_set_regs(dut);
  else
    diff_get_regs(dut);
}

__EXPORT void difftest_exec(uint64_t n)
{
  cpu_exec(n);
}

__EXPORT void difftest_raise_intr(word_t NO)
{
  assert(0);
}

__EXPORT void difftest_init(int port)
{
  void init_mem();
  init_mem();
  /* Perform ISA dependent initialization. */
  init_isa();
}
