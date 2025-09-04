#include <am.h>
#include <klib.h>
#include <rtthread.h>

// 使用全局变量保存
// bool has_from;
// Context *from_context;
// Context *to_context;

typedef struct
{
  void (*tentry)(void *);
  void *parameter;
  void (*texit)();
} thread_args_t;

static Context *ev_handler(Event e, Context *c)
{
  switch (e.event)
  {
  case EVENT_YIELD:
    // if (has_from)
    //   from_context = c;
    // c = to_context;
    Context **context = (Context **)rt_thread_self()->user_data;
    if (context[0])
      context[0] = c;
    c = context[1];
    break;
  case EVENT_IRQ_TIMER:
    // native默认开启中断 因此需要支持timer 目前不处理即可
    break;
  default:
    printf("Unhandled event ID = %d\n", e.event);
    assert(0);
  }
  return c;
}

void __am_cte_init()
{
  cte_init(ev_handler);
}

void rt_hw_context_switch_to(rt_ubase_t to)
{
  //  to_context = *(Context **)to;
  //  has_from = false;
  //  yield();

  // 使用PCB中的user_data
  rt_thread_t pcb = rt_thread_self();
  rt_ubase_t prev_data = pcb->user_data;

  // 构造Context *数组 和之前使用malloc分配thread_args_t一样 这里不能malloc 只能静态数组
  Context *context[2];
  context[0] = NULL;
  context[1] = *(Context **)to;

  // 将Context *数组地址保存在user_data
  pcb->user_data = (rt_ubase_t)context;
  yield();

  // 恢复
  pcb->user_data = prev_data;
}

void rt_hw_context_switch(rt_ubase_t from, rt_ubase_t to)
{
  // from_context = *(Context **)from;
  // to_context = *(Context **)to;
  // yield();

  // 使用PCB中的user_data
  rt_thread_t pcb = rt_thread_self();
  rt_ubase_t prev_data = pcb->user_data;

  // 构造Context *数组 和之前使用malloc分配thread_args_t一样 这里不能malloc 只能静态数组
  Context *context[2];
  context[0] = *(Context **)from;
  context[1] = *(Context **)to;

  // 将Context *数组地址保存在user_data
  pcb->user_data = (rt_ubase_t)context;
  yield();

  // 恢复
  pcb->user_data = prev_data;
}

void rt_hw_context_switch_interrupt(void *context, rt_ubase_t from, rt_ubase_t to, struct rt_thread *to_thread)
{
  assert(0);
}

void rt_hw_stack_package(void *args)
{
  thread_args_t *thread_args = (thread_args_t *)args;
  thread_args->tentry(thread_args->parameter);
  thread_args->texit();

  /* 比较复杂的可以使用汇编 类似NEMU中的__am_asm_helper实现
    asm volatile(
        "addi sp,sp,-16\n"
        "sd %[exit], 8(sp)\n" // 要用栈保存下来exit 不然从entry返回时会破坏
        "sd t0,0(sp)\n"
        "mv t0, %[entry]\n"
        "mv a0, %[param]\n"
        "jalr ra,0(t0)\n"
        "ld t0, 8(sp)\n"
        "addi sp,sp,16\n"
        "jalr ra,0(t0)\n"
        :
        : [param] "r"(args->parameter),
          [entry] "r"(args->tentry),
          [exit] "r"(args->texit)
        : "a0", "t0");

  */
}

rt_uint8_t *rt_hw_stack_init(void *tentry, void *parameter, rt_uint8_t *stack_addr, void *texit)
{
  /* 栈空间
   +--------------------+  <- stack_addr
   |   (空的栈区)        |
   +--------------------+  <- bottom（对齐后）
   |  thread_arg_t      |
   +--------------------+  <- 储存分配的参数
   |  Context           |
   +--------------------+  <- cp
  */

  // 1. 将stack_addr对齐到sizeof(uintptr_t)
  rt_uint8_t *bottom = (rt_uint8_t *)RT_ALIGN_DOWN((uintptr_t)stack_addr, sizeof(uintptr_t));

  // 2. 构造结构体传参 tentry texit paramter 这里需要使用栈的空间 原因如下
  // thread_args_t *args = (thread_args_t *)malloc(sizeof(thread_args_t)); //这里不能使用malloc 因为thread_args_t并不是rt对象 会malloc失败
  // (rt_object_get_type(&m->parent) == RT_Object_Class_Memory) assertion failed at function:rt_smem_alloc, line number:288
  rt_uint8_t *arg = bottom - sizeof(thread_args_t);
  thread_args_t *args = (thread_args_t *)arg;
  args->tentry = (void (*)(void *))tentry;
  args->texit = (void (*)())texit;
  args->parameter = parameter;

  // 3. 调用context函数
  Area area;
  area.end = (void *)arg;
  Context *cp = kcontext(area, rt_hw_stack_package, (void *)args);
  return (rt_uint8_t *)cp;
}
