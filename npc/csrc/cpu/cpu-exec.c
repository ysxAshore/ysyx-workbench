#include <cpu/cpu.h>
#include <cpu/difftest.h>
#include <memory/paddr.h>

#define MAX_INST_TO_PRINT 16

CPUState cpu{};
#ifdef CONFIG_VCD
extern VerilatedVcdC *tfp;
#endif
uint64_t g_nr_guest_inst = 0;

static uint64_t g_timer = 0; // unit: us

extern TOP_NAME dut;
extern bool isFinish;
extern const int clk_period;
extern NPCState npc_state;
extern vluint64_t sim_time;

#ifdef CONFIG_ITRACE
char logbuf[128];
char *iringbuf[MAX_INST_TO_PRINT];
static int header = 0;
static bool g_print_step = false;

void printIringBuf()
{
    int errorIndex = header - 1 < 0 ? MAX_INST_TO_PRINT - 1 : header - 1;
    for (int i = 0; i < MAX_INST_TO_PRINT; ++i)
    {
        if (i == errorIndex)
        {
            printf("\033[1;31;40m--> \033[0m");
            printf("\033[1;31;40m%s\n\033[0m", iringbuf[i]);
        }
        else
            printf("    %s\n", iringbuf[i]);
    }
}
#endif

void checkWatchPoint();
void printFtrace();

static void trace_and_difftest()
{
#ifdef CONFIG_ITRACE_COND
    log_write("%s\n", logbuf);
#endif
#ifdef CONFIG_ITRACE
    if (g_print_step)
        puts(logbuf);
#endif
    IFDEF(CONFIG_DIFFTEST, difftest_step(cpu.pc, cpu.dnpc));
    IFDEF(CONFIG_WATCHPOINT, checkWatchPoint());
}

static void statistic()
{
    IFNDEF(CONFIG_TARGET_AM, setlocale(LC_NUMERIC, ""));
#define NUMBERIC_FMT MUXDEF(CONFIG_TARGET_AM, "%", "%'") PRIu64
    Log("host time spent = " NUMBERIC_FMT " us", g_timer);
    Log("total guest instructions = " NUMBERIC_FMT, g_nr_guest_inst);
    if (g_timer > 0)
        Log("simulation frequency = " NUMBERIC_FMT " inst/s", g_nr_guest_inst * 1000000 / g_timer);
    else
        Log("Finish running in less than 1 us and can not calculate the simulation frequency");

#ifdef CONFIG_VCD
    tfp->close();
    delete tfp;
#endif
}

void assert_fail_msg()
{
    extern void isa_reg_display();
    isa_reg_display();
    statistic();
}

static bool exec_exit = false;
static void exec_once()
{
    while (!Verilated::gotFinish())
    {
        Verilated::timeInc(1000);
        ++sim_time;
        if (sim_time % (clk_period / 2) == 0)
        {
            dut.clock = !dut.clock;
            dut.eval();

            if (dut.clock && dut.update_dut)
            {
                cpu.pc = dut.pc;
                cpu.dnpc = dut.dnpc;
                cpu.inst = dut.inst;
                exec_exit = true;
            }
            if (exec_exit && !dut.clock)
            {
                exec_exit = false;
                break;
            }
        }
        dut.eval();

        DUMP_VCD();
    }

#ifdef CONFIG_ITRACE
    char *p = logbuf;
    p += snprintf(p, sizeof(logbuf), FMT_WORD ":", cpu.pc);
    int ilen = 4;
    int i;
    uint8_t *inst = (uint8_t *)&cpu.inst;
    for (i = ilen - 1; i >= 0; i--)
        p += snprintf(p, 4, " %02x", inst[i]);
    int ilen_max = MUXDEF(CONFIG_ISA_x86, 8, 4);
    int space_len = ilen_max - ilen;
    if (space_len < 0)
        space_len = 0;
    space_len = space_len * 3 + 1;
    memset(p, ' ', space_len);
    p += space_len;

    void disassemble(char *str, int size, uint64_t pc, uint8_t *code, int nbyte);
    disassemble(p, logbuf + sizeof(logbuf) - p,
                cpu.pc, (uint8_t *)&cpu.inst, ilen);
    iringbuf[header] = (char *)realloc(iringbuf[header], strlen(logbuf) + 1);
    strcpy(iringbuf[header], logbuf);
    ++header;
    if (header == MAX_INST_TO_PRINT)
        header = 0;
#endif
}

static void execute(uint64_t n)
{
    for (; n > 0; n--)
    {
        exec_once();
        ++g_nr_guest_inst;
        trace_and_difftest();
        if (npc_state.state != NPC_RUNNING)
            break;
        // IFDEF(CONFIG_DEVICE, device_update());
    }
}

void cpu_exec(uint64_t n)
{
    IFDEF(CONFIG_ITRACE, g_print_step = (n < MAX_INST_TO_PRINT));

    switch (npc_state.state)
    {
    case NPC_END:
    case NPC_ABORT:
    case NPC_QUIT:
        printf("Program execution has ended. To restart the program, exit NPC and run again.\n");
        return;
    default:
        npc_state.state = NPC_RUNNING;
    }

    uint64_t timer_start = get_time();

    execute(n);

    uint64_t timer_end = get_time();
    g_timer += timer_end - timer_start;

    switch (npc_state.state)
    {
    case NPC_RUNNING:
        npc_state.state = NPC_STOP;
        break;

    case NPC_END:
    case NPC_ABORT:
#ifdef CONFIG_ITRACE
        if (npc_state.halt_ret != 0)
            printIringBuf();
#endif
        IFDEF(CONFIG_FTRACE, printFtrace());
        Log("npc: %s at pc = " FMT_WORD,
            (npc_state.state == NPC_ABORT ? ANSI_FMT("ABORT", ANSI_FG_RED) : (npc_state.halt_ret == 0 ? ANSI_FMT("HIT GOOD TRAP", ANSI_FG_GREEN) : ANSI_FMT("HIT BAD TRAP", ANSI_FG_RED))),
            npc_state.halt_pc);
        // fall through
    case NPC_QUIT:
        statistic();
    }
}