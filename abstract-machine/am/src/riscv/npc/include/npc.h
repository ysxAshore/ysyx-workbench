#ifndef NPC_H__
#define NPC_H__

#include <klib-macros.h>

#include ISA_H

#define npc_trap(code) asm volatile("mv a0, %0; ebreak" : : "r"(code))

extern char _pmem_start;
#define PMEM_SIZE (128 * 1024 * 1024)
#define PMEM_END ((uintptr_t)&_pmem_start + PMEM_SIZE)
#define NPC_PADDR_SPACE                     \
    RANGE(&_pmem_start, PMEM_END),          \
        RANGE(FB_ADDR, FB_ADDR + 0x200000), \
        RANGE(MMIO_BASE, MMIO_BASE + 0x1000) /* serial, rtc, screen, keyboard */

typedef uintptr_t PTE;

#define PGSIZE 4096

#endif