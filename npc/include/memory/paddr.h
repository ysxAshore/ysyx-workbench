#ifndef __MEMORY_PADDR_H__
#define __MEMORY_PADDR_H__

#include <common.h>

#define PMEM_LEFT ((paddr_t)CONFIG_MBASE)
#define PMEM_RIGHT ((paddr_t)CONFIG_MBASE + CONFIG_MSIZE - 1)
#define RESET_VECTOR (PMEM_LEFT + CONFIG_PC_RESET_OFFSET)

#ifdef CONFIG_YSYXSOC

#ifdef CONFIG_USE_MROM
#define YSYXSOC_RESET_VECTOR 0x20000000
#else
#ifdef CONFIG_USE_FLASH
#define YSYXSOC_RESET_VECTOR 0x30000000
#endif
#endif

#define MROM_BASE 0x20000000
#define MROM_SIZE 0x1000
#define FLASH_BASE 0x30000000
#define FLASH_SIZE 0x10000000

uint8_t *guestAddr_to_hostAddr(paddr_t paddr);
paddr_t hostAddr_to_guestAddr(uint8_t *haddr);

#endif

/* convert the guest physical address in the guest program to host virtual address in NEMU */
uint8_t *guest_to_host(paddr_t paddr);
/* convert the host virtual address in NEMU to guest physical address in the guest program */
paddr_t host_to_guest(uint8_t *haddr);

static inline bool in_pmem(paddr_t addr)
{
  return addr - CONFIG_MBASE < CONFIG_MSIZE;
}

word_t paddr_read(paddr_t addr, int len);
void paddr_write(paddr_t addr, int len, word_t data);

#endif
