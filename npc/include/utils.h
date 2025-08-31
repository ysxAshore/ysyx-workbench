#ifndef __UTILS_H__
#define __UTILS_H__

#include <common.h>

// ----------- state -----------
enum
{
    NPC_RUNNING,
    NPC_STOP,
    NPC_END,
    NPC_ABORT,
    NPC_QUIT
};
typedef struct
{
    int state;
    vaddr_t halt_pc;
    uint32_t halt_ret;
} NPCState;
// ----------- timer -----------

uint64_t get_time();

// ----------- log -----------

#define ANSI_FG_BLACK "\33[1;30m"
#define ANSI_FG_RED "\33[1;31m"
#define ANSI_FG_GREEN "\33[1;32m"
#define ANSI_FG_YELLOW "\33[1;33m"
#define ANSI_FG_BLUE "\33[1;34m"
#define ANSI_FG_MAGENTA "\33[1;35m"
#define ANSI_FG_CYAN "\33[1;36m"
#define ANSI_FG_WHITE "\33[1;37m"
#define ANSI_BG_BLACK "\33[1;40m"
#define ANSI_BG_RED "\33[1;41m"
#define ANSI_BG_GREEN "\33[1;42m"
#define ANSI_BG_YELLOW "\33[1;43m"
#define ANSI_BG_BLUE "\33[1;44m"
#define ANSI_BG_MAGENTA "\33[1;45m"
#define ANSI_BG_CYAN "\33[1;46m"
#define ANSI_BG_WHITE "\33[1;47m"
#define ANSI_NONE "\33[0m"

#define ANSI_FMT(str, fmt) fmt str ANSI_NONE

// 这里设置log_write专门用于输出到文件
#define log_write(...) IFDEF(CONFIG_TARGET_NATIVE_ELF, do { \
    extern FILE* log_fp; \
    extern bool log_enable(); \
    if (log_enable() && log_fp != stdout) { \
      fprintf(log_fp, __VA_ARGS__); \
      fflush(log_fp); \
    } } while (0))

#define _Log(...)               \
    do                          \
    {                           \
        printf(__VA_ARGS__);    \
        log_write(__VA_ARGS__); \
    } while (0)

#define Elf_Addr MUXDEF(CONFIG_ISA64, Elf64_Addr, Elf32_Addr)
#define Elf_Ehdr MUXDEF(CONFIG_ISA64, Elf64_Ehdr, Elf32_Ehdr)
#define Elf_Shdr MUXDEF(CONFIG_ISA64, Elf64_Shdr, Elf32_Shdr)
#define Elf_Sym MUXDEF(CONFIG_ISA64, Elf64_Sym, Elf32_Sym)
#define ELF_ST_TYPE MUXDEF(CONFIG_ISA64, ELF64_ST_TYPE, ELF32_ST_TYPE)

#endif
