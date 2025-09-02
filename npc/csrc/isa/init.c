#include <isa.h>
#include <memory/paddr.h>

TOP_NAME dut;
int clk_period = 20;        // 时钟周期 10个仿真时间单位
static int reset_time = 33; // 复位时间
vluint64_t sim_time = 0;
#ifdef CONFIG_VCD
VerilatedVcdC *tfp;
#endif
extern CPUState cpu;

// this is not consistent with uint8_t
// but it is ok since we do not access the array directly
static const uint32_t img[] = {
    0x00000297, // auipc t0,0
    0x00028823, // sb  zero,16(t0)
    0x0102c503, // lbu a0,16(t0)
    0x00100073, // ebreak (used as nemu_trap)
    0xdeadbeef, // some data
};

void restart()
{
#ifdef CONFIG_VCD
    tfp = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    dut.trace(tfp, 99);
    tfp->open("wave.vcd");
#endif

    dut.clock = 0;
    dut.reset = 1;

    // 复位保持resertime
    for (sim_time = 0; sim_time < reset_time; ++sim_time)
    {
        Verilated::timeInc(1000);
        // 每半个周期翻转一次时钟
        if (sim_time % (clk_period / 2) == 0)
            dut.clock = !dut.clock;

        dut.eval(); // 更新电路
        DUMP_VCD();
    }

    // 释放rst
    Verilated::timeInc(1000);
    dut.reset = 0;
    dut.eval();
    DUMP_VCD();

    cpu.pc = dut.pc;
}

void init_isa()
{
    /* Load built-in image. */
    memcpy(guest_to_host(RESET_VECTOR), img, sizeof(img));

    /* Initialize this virtual computer system. */
    restart();
}
