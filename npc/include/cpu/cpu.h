#ifndef __CPU_CPU_H__
#define __CPU_CPU_H__

#include <common.h>
#include _HDR(TOP_NAME)
#include _HDR(TOP_NAME, __Dpi)

#ifdef CONFIG_VCD
#include <verilated_vcd_c.h>
#endif

#define NR_GPR MUXDEF(CONFIG_RVE, 16, 32)

typedef struct
{
    word_t gprs[NR_GPR];
    word_t pc;
    word_t dnpc;
    word_t inst;
} CPUState;

void cpu_exec(uint64_t n);

void set_npc_state(int state, vaddr_t pc, int halt_ret);
void invalid_inst(vaddr_t thispc);

#define NPCTRAP(thispc, code) set_npc_state(NPC_END, thispc, code)
#define INV(thispc) invalid_inst(thispc)
#define DUMP_VCD() IFDEF(CONFIG_VCD, do {\
    extern VerilatedVcdC *tfp;\
    if (Verilated::time() >= CONFIG_VCD_START &&\
        Verilated::time() <= CONFIG_VCD_END)\
        tfp->dump(Verilated::time()); } while (0))

#endif
