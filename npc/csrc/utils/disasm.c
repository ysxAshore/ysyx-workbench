#include <dlfcn.h>
#include <capstone/capstone.h>
#include <common.h>

static size_t (*cs_disasm_dl)(csh handle, const uint8_t *code,
                              size_t code_size, uint64_t address, size_t count, cs_insn **insn);
static void (*cs_free_dl)(cs_insn *insn, size_t count);

static csh handle;

void init_disasm()
{
  // 获取环境变量 "PATH" 的值
  char *path = getenv("NEMU_HOME");
  if (path == NULL)
    printf("Environment variable PATH not found.Please install nemu first!\n");

  char *capstone_path = (char *)malloc(strlen(path) + strlen("/tools/capstone/repo/libcapstone.so.5") + 1);
  strcpy(capstone_path, path);
  strcat(capstone_path, "/tools/capstone/repo/libcapstone.so.5"); // path是不可写的（那为什么gdb可以运行？） strcat的目标必须是可写的
  /*
  ➤ GDB 下之所以没有立刻段错误，是因为：
  GDB 会改变内存布局，可能让 getenv("NEMU_HOME") 返回的内存 碰巧可写；
  内存保护机制放宽或延后触发，但这种行为是 未定义的（Undefined Behavior）；
  你写入的内容 没有越界或破坏立即敏感的内存区域，所以段错误没发生——但不代表是对的！
  Heisenbug（海森堡 bug）：只有在不调试的时候才出错
  */

  void *dl_handle;
  dl_handle = dlopen(capstone_path, RTLD_LAZY);

  assert(dl_handle);

  cs_err (*cs_open_dl)(cs_arch arch, cs_mode mode, csh *handle) = NULL;
  cs_open_dl = (cs_err (*)(cs_arch, cs_mode, csh *))dlsym(dl_handle, "cs_open");

  assert(cs_open_dl);

  cs_disasm_dl = (size_t (*)(csh, const uint8_t *, size_t, uint64_t, size_t, cs_insn **))dlsym(dl_handle, "cs_disasm");

  assert(cs_disasm_dl);

  cs_free_dl = (void (*)(cs_insn *, size_t))dlsym(dl_handle, "cs_free");
  assert(cs_free_dl);

  cs_arch arch = MUXDEF(CONFIG_ISA_x86, CS_ARCH_X86,
                        MUXDEF(CONFIG_ISA_mips32, CS_ARCH_MIPS,
                               MUXDEF(CONFIG_ISA_riscv, CS_ARCH_RISCV,
                                      MUXDEF(CONFIG_ISA_loongarch32r, CS_ARCH_LOONGARCH, -1))));
  cs_mode mode = (cs_mode)(MUXDEF(CONFIG_ISA_riscv, MUXDEF(CONFIG_ISA64, CS_MODE_RISCV64, CS_MODE_RISCV32) | CS_MODE_RISCVC, 0));
  int ret = cs_open_dl(arch, mode, &handle);
  assert(ret == CS_ERR_OK);

#ifdef CONFIG_ISA_x86
  cs_err (*cs_option_dl)(csh handle, cs_opt_type type, size_t value) = NULL;
  cs_option_dl = dlsym(dl_handle, "cs_option");
  assert(cs_option_dl);

  ret = cs_option_dl(handle, CS_OPT_SYNTAX, CS_OPT_SYNTAX_ATT);
  assert(ret == CS_ERR_OK);
#endif
}

void disassemble(char *str, int size, uint64_t pc, uint8_t *code, int nbyte)
{
  cs_insn *insn;
  size_t count = cs_disasm_dl(handle, code, nbyte, pc, 0, &insn);
  assert(count == 1);
  int ret = snprintf(str, size, "%s", insn->mnemonic);
  if (insn->op_str[0] != '\0')
  {
    snprintf(str + ret, size - ret, "\t%s", insn->op_str);
  }
  cs_free_dl(insn, count);
}
