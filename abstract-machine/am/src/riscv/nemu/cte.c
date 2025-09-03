#include <am.h>
#include <riscv/riscv.h>
#include <klib.h>

static Context *(*user_handler)(Event, Context *) = NULL;

Context *__am_irq_handle(Context *c)
{
  if (user_handler)
  {
    Event ev = {0};
    switch (c->mcause)
    {
    case 0xb:
      ev.event = EVENT_YIELD;
      break;
      ;
    default:
      ev.event = EVENT_ERROR;
      break;
    }

    c = user_handler(ev, c);
    assert(c != NULL);
  }

  return c;
}

extern void __am_asm_trap(void);

bool cte_init(Context *(*handler)(Event, Context *))
{
  // initialize exception entry 将异常程序服务地址入口 写入mtvec
  asm volatile("csrw mtvec, %0" : : "r"(__am_asm_trap));

  // register event handler
  user_handler = handler;

  return true;
}

extern void __am_asm_helper(uintptr_t entry, uintptr_t arg);
Context *kcontext(Area kstack, void (*entry)(void *), void *arg)
{
  Context *cp = (Context *)(kstack.end - sizeof(Context));

  // 设置cp
  // 1. cp->mstatus
#ifdef __riscv_e
  cp->mstatus = 0x1800;
#else
  cp->mstatus = 0xa0001800;
#endif
  // 2. cp->mepc
  // cp->mepc = (uintptr_t)entry; //直接跳转到入口
  cp->mepc = (uintptr_t)__am_asm_helper - 0x4; // 陷入指令会给mepc+0x4 从而设置进程的起始PC
  // 3. 设置参数 a0~a7存放参数 a0~a1存放返回值
  // cp->gpr[10] = (uintptr_t)arg; //直接跳到entry的只需要保存一个参数
  cp->gpr[10] = (uintptr_t)entry;
  cp->gpr[11] = (uintptr_t)arg;
  return cp;
}

void yield()
{
  // 这里不应该是-1 在M-mode下 yield的cause是0xb
#ifdef __riscv_e
  asm volatile("li a5, 0xb; ecall");
#else
  asm volatile("li a7, 0xb; ecall");
#endif
}

bool ienabled()
{
  return false;
}

void iset(bool enable)
{
}
