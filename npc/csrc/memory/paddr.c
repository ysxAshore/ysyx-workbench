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

#include <memory/host.h>
#include <memory/paddr.h>
#include <device/mmio.h>
#include <isa.h>

extern CPUState cpu;

#if defined(CONFIG_PMEM_MALLOC)
static uint8_t *pmem = NULL;
#else // CONFIG_PMEM_GARRAY
static uint8_t pmem[CONFIG_MSIZE] PG_ALIGN = {};
#endif

#ifdef CONFIG_YSYXSOC
void init_flash();
#endif

uint8_t *guest_to_host(paddr_t paddr) { return pmem + paddr - CONFIG_MBASE; }
paddr_t host_to_guest(uint8_t *haddr) { return haddr - pmem + CONFIG_MBASE; }

static word_t pmem_read(paddr_t addr, int len)
{
  word_t ret = host_read(guest_to_host(addr), len);
  return ret;
}

static void pmem_write(paddr_t addr, int len, word_t data)
{
  host_write(guest_to_host(addr), len, data);
}

static void out_of_bound(paddr_t addr)
{
  panic("address = " FMT_PADDR " is out of bound of pmem [" FMT_PADDR ", " FMT_PADDR "] at pc = " FMT_WORD,
        addr, PMEM_LEFT, PMEM_RIGHT, cpu.pc);
}

void init_mem()
{
  // 使用FLASH存储程序时 就不需要这样了
#ifdef CONFIG_USE_MROM
  init_flash();
#endif

#if defined(CONFIG_PMEM_MALLOC)
  pmem = malloc(CONFIG_MSIZE);
  assert(pmem);
#endif
  IFDEF(CONFIG_MEM_RANDOM, memset(pmem, rand(), CONFIG_MSIZE));
  Log("physical memory area [" FMT_PADDR ", " FMT_PADDR "]", PMEM_LEFT, PMEM_RIGHT);
}

word_t paddr_read(paddr_t addr, int len)
{
  IFDEF(CONFIG_MTRACE, printf("This is a paddr_read,read " FMT_PADDR " address and %d size\n", addr, len));
  if (likely(in_pmem(addr)))
    return pmem_read(addr, len);
  IFDEF(CONFIG_DEVICE, return mmio_read(addr, len));
  out_of_bound(addr);
  return 0;
}

void paddr_write(paddr_t addr, int len, word_t data)
{
  IFDEF(CONFIG_MTRACE, printf("This is a paddr_write,write " FMT_PADDR " address and %d size and " FMT_WORD " data\n", addr, len, data));
  if (likely(in_pmem(addr)))
  {
    pmem_write(addr, len, data);
    return;
  }
  IFDEF(CONFIG_DEVICE, mmio_write(addr, len, data); return);
  out_of_bound(addr);
}

#ifdef CONFIG_YSYXSOC

static uint8_t mrom[MROM_SIZE] PG_ALIGN = {};

extern "C" void mrom_read(int32_t addr, int32_t *data)
{
  *data = *(int32_t *)((uintptr_t)mrom + addr - MROM_BASE);
}

static uint8_t flash[FLASH_SIZE] PG_ALIGN = {};
extern "C" void flash_read(int32_t addr, int32_t *data)
{
  // addr是4字节对齐的,低2位为0 这里地址已经做差了
  // 因此需要强转数组类型
  *data = *(int32_t *)((uintptr_t)flash + addr);
}

void init_flash()
{
  /* 随机数值测试
      for (int i = 0; i < 100000; ++i)
        flash[i] = i;
  */

  /* 存储char-test程序 将其读入SRAM 跳转并执行 注意这里的相对路径是相对于npc下的 因为在npc下执行make*/
  FILE *fp = fopen("../ysyxSoC/perip/uart16550/test/test.bin", "rb");
  Assert(fp, "Can not open '../ysyxSoC/perip/uart16550/test/test.bin'");

  fseek(fp, 0, SEEK_END);
  long size = ftell(fp);
  fseek(fp, 0, SEEK_SET);

  /* XIP方式就不需要拷贝程序 也就不需要知道程序的大小了
  // 让软件知道要拷贝多少字节
  *(uint32_t *)flash = size;
  int ret = fread(flash + 0x4, size, 1, fp);
  */

  int ret = fread(flash, size, 1, fp);
  assert(ret == 1);

  fclose(fp);
}

static uint8_t psram[PSRAM_SIZE] PG_ALIGN = {};
extern "C" void psram_read(int32_t addr, int32_t *data)
{
  // addr是4字节对齐的,低2位为0 这里地址已经做差了
  // 因此需要强转数组类型
  *data = *(int32_t *)((uintptr_t)psram + addr);
}

extern "C" void psram_write(int32_t addr, int32_t data, int32_t wsize)
{
  if (wsize == 1)
    psram[addr] = (uint8_t)data;
  else if (wsize == 2)
    *(uint16_t *)(psram + addr) = (uint16_t)data;
  else
    *(uint32_t *)(psram + addr) = (uint32_t)data;
}

uint8_t *guestAddr_to_hostAddr(paddr_t paddr)
{
#ifdef CONFIG_USE_MROM
  return mrom + paddr - MROM_BASE;
#endif

#ifdef CONFIG_USE_FLASH
  return flash + paddr - FLASH_BASE;
#endif
}
paddr_t hostAddr_to_guestAddr(uint8_t *haddr)
{
#ifdef CONFIG_USE_MROM
  return haddr - mrom + MROM_BASE;
#endif

#ifdef CONFIG_USE_FLASH
  return haddr - flash + FLASH_BASE;
#endif
}

extern "C" void time_read(int32_t addr, int32_t *data)
{
  static uint64_t us;
  if ((addr & 0xf) == 0xc)
  {
    us = get_time();
    *data = (uint32_t)(us >> 32);
  }
  else
    *data = (uint32_t)us;
}

#endif
