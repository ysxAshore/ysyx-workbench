#include <am.h>
#include <ysyxsoc.h>
#include <stdio.h>

void __am_uart_config(AM_UART_CONFIG_T *cfg)
{
    cfg->present = true;
}

void __am_uart_tx(AM_UART_TX_T *t)
{
    putch(t->data);
}

void __am_uart_rx(AM_UART_RX_T *r)
{
    // LSR[0] 为1时 表示receiver fifo中有数据
    if (inb(UART_ADDR + 0x05) & (1 << 0))
        r->data = inb(UART_ADDR + 0x0);
    else
        r->data = 0xff;
}
