#include <Vtop.h>
#include <Vtop__Dpi.h>
#include <verilated.h>
#include "verilated_vcd_c.h"

// TOP_NAME是宏,展开为Vtop
static TOP_NAME dut;
VerilatedVcdC *tfp = new VerilatedVcdC;
vluint64_t sim_time = 0;

// 时钟边沿模拟，模拟了从低电平到高电平的时钟跳变
static void single_cycle()
{
  dut.clk = 0;
  dut.eval();
  tfp->dump(sim_time++);
  dut.clk = 1;
  dut.eval();
  tfp->dump(sim_time++);
}

static void reset(int n)
{
  dut.rst = 1;
  // rst电平复位 复位n个cycle
  while (n-- > 0)
    single_cycle();
  dut.rst = 0;
}

static bool isFinish = false;
void callEbreak()
{
  isFinish = true;
}

int main(int argc, const char *argv[])
{
  uint32_t inst[] = {
      0x02a00293,
      0x00000293,
      0xf8000333,
      0x07b00013,
      0x00450513,
      0x00100073,
      0xdeadbeef};

  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);
  dut.trace(tfp, 99);
  tfp->open("wave.vcd");

  reset(10);

  while (1)
  {
    // dut.inst迟一拍 是在下降沿才更新
    dut.inst = *(uint32_t *)((uint8_t *)inst + dut.pc - 0x80000000);
    single_cycle();
    if (isFinish)
      break;
  }
  tfp->close();
}