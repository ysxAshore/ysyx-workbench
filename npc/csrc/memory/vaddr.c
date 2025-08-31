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
#include <memory/paddr.h>
#include _HDR(TOP_NAME, __Dpi)

word_t vaddr_ifetch(vaddr_t addr, int len)
{
  return paddr_read(addr, len);
}

extern "C" svBitVecVal vaddr_read(const svBitVecVal *addr, const svBitVecVal *len)
{
  return paddr_read(*addr, *len);
}

extern "C" void vaddr_write(const svBitVecVal *addr, const svBitVecVal *len, const svBitVecVal *data)
{
  paddr_write(*addr, *len, *data);
}
