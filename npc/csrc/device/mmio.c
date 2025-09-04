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

#include <device/mmio.h>
#include <cpu/difftest.h>
#include <memory/paddr.h>

/* bus interface */
uint64_t us;
// 总是读取地址为`raddr & ~0x3u`的4字节并返回
word_t mmio_read(paddr_t addr, int len)
{
  assert(len >= 1 && len <= 8);
  IFDEF(CONFIG_DTRACE, printf("read %s device,the addr is " FMT_PADDR ",the size is %d\n", map->name, addr, len));
  // 时钟处理 保持AM不变 因此先读高位得到time
  if (addr == CONFIG_RTC_MMIO + 0x4)
  {
    IFDEF(CONFIG_DIFFTEST, difftest_skip_ref());
    us = get_time();
    return us >> 32;
  }
  if (addr == CONFIG_RTC_MMIO)
  {
    IFDEF(CONFIG_DIFFTEST, difftest_skip_ref());
    return (uint32_t)us;
  }
  panic("The address " FMT_PADDR " reading is not supported", addr);
}

void mmio_write(paddr_t addr, int len, word_t wdata)
{
  assert(len >= 1 && len <= 8);
  IFDEF(CONFIG_DTRACE, printf("write %s device,the addr is " FMT_PADDR ",the size is %d,the data is" FMT_WORD "\n", map->name, addr, len, data));
  // 处理串口
  if (addr == CONFIG_SERIAL_MMIO)
  {
    IFDEF(CONFIG_DIFFTEST, difftest_skip_ref());
    putchar((uint8_t)wdata);
    fflush(stdout);
    return;
  }
  panic("The address " FMT_PADDR " writing is not supported!", addr);
}
