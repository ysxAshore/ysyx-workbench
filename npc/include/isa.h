#ifndef __ISA_H__
#define __ISA_H__

#include <cpu/cpu.h>

//------------------reset and load base img-------------------
extern unsigned char isa_logo[];
void init_isa();

//------------------reg-------------------
void isa_reg_display();
word_t isa_reg_str2val(const char *name, bool *success);

static inline int check_reg_idx(int idx)
{
    IFDEF(CONFIG_RT_CHECK, assert(idx >= 0 && idx < MUXDEF(CONFIG_RVE, 16, 32)));
    return idx;
}

#define gpr(idx) (cpu.gpr[check_reg_idx(idx)])

static inline const char *reg_name(int idx)
{
    extern const char *regs[];
    return regs[check_reg_idx(idx)];
}

#endif
