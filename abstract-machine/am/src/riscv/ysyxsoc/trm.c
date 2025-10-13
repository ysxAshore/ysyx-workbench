#include <am.h>
#include <ysyxsoc.h>
#include <klib-macros.h>

extern char _heap_start;

int main(const char *args);

Area heap = RANGE(&_heap_start, PMEM_END);
static const char mainargs[MAINARGS_MAX_LEN] = TOSTRING(MAINARGS_PLACEHOLDER); // defined in CFLAGS

static inline void init_uart16550()
{
    // 设置波特率除数: 波特率 = UART 输入时钟 / (16 × 除数) -> 除数 = 频率(HZ) / (16 × 预设置波特率)
    // 这里假设UART输入时钟为1.8432MHz, 波特率设置为115200 除数=1

    outb(UART_ADDR + 0x03, 0x83); // LCR bit7 set DLAB
    outb(UART_ADDR + 0x01, 0x00); // 除数高字节
    outb(UART_ADDR + 0x00, 0x1b); // 除数低字节

    outb(UART_ADDR + 0x03, 0x03); // LCR 8N1 模式
}

void putch(char ch)
{
    // LSR[5]为1时 表示 THR空
    while ((inb(UART_ADDR + 0x05) & (1 << 5)) == 0)
        ;
    // THR不空时即可然后写入字符
    outb(UART_ADDR + 0x00, ch);
}

void halt(int code)
{
    nemu_trap(code);
    while (1)
        ;
}

void _trm_init()
{
    // uart init
    init_uart16550();

    int ret = main(mainargs);
    halt(ret);
}
