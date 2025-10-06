#ifndef YSYXSOC_H__
#define YSYXSOC_H__

#include <klib-macros.h>

#include ISA_H

#define nemu_trap(code) asm volatile("mv a0, %0; ebreak" : : "r"(code))

#define UART_ADDR 0x10000000        // 0x1000_0000~0x1000_0fff
#define KBD_ADDR 0x10011000         // 0x1001_1000~0x1001_1007
#define TIME_UPTIME_ADDR 0x20001000 // 0x2000_1000~0x2000_1010
#define TIME_RTC_ADDR 0x20001008    // 0x2000_1000~0x2000_1010
#define FB_ADDR 0x21000000          // 0x2100_0000~0x211f_ffff

extern char _sdram_start;

// define heap size
#define PMEM_SIZE (64 * 1024 * 1024)
#define PMEM_END ((uintptr_t)&_sdram_start + PMEM_SIZE)

typedef uintptr_t PTE;

#define PGSIZE 4096

#endif
