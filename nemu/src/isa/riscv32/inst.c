/***************************************************************************************
 * Copyright (c) 2014-2024 Zihao Yu, Nanjing University
 *
 * NEMU is licensed under Mulan PSL v2.
 * You can use this software according to the terms and conditions of the Mulan PSL v2.
 * You may obtain a copy of Mulan PSL v2 at:
 *          http://license.coscl.org.cn/MulanPSL2
 *
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
 * EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
 * MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
 *
 * See the Mulan PSL v2 for more details.
 ***************************************************************************************/

#include "local-include/reg.h"
#include <cpu/cpu.h>
#include <cpu/ifetch.h>
#include <cpu/decode.h>

#define R(i) gpr(i)
#define Mr vaddr_read
#define Mw vaddr_write

enum
{
  TYPE_I,
  TYPE_U,
  TYPE_S,
  TYPE_J,
  TYPE_B,
  TYPE_R,
  TYPE_N, // none
};

#define src1R()     \
  do                \
  {                 \
    *src1 = R(rs1); \
  } while (0)
#define src2R()     \
  do                \
  {                 \
    *src2 = R(rs2); \
  } while (0)
#define immI()                        \
  do                                  \
  {                                   \
    *imm = SEXT(BITS(i, 31, 20), 12); \
  } while (0)
#define immU()                              \
  do                                        \
  {                                         \
    *imm = SEXT(BITS(i, 31, 12), 20) << 12; \
  } while (0)
#define immS()                                               \
  do                                                         \
  {                                                          \
    *imm = (SEXT(BITS(i, 31, 25), 7) << 5) | BITS(i, 11, 7); \
  } while (0)
#define immJ()                                                                                                      \
  do                                                                                                                \
  {                                                                                                                 \
    *imm = (SEXT(BITS(i, 31, 31), 1) << 20) | BITS(i, 30, 21) << 1 | BITS(i, 20, 20) << 11 | BITS(i, 19, 12) << 12; \
  } while (0)
#define immB()                                                                                                  \
  do                                                                                                            \
  {                                                                                                             \
    *imm = (SEXT(BITS(i, 31, 31), 1) << 12) | BITS(i, 30, 25) << 5 | BITS(i, 11, 8) << 1 | BITS(i, 7, 7) << 11; \
  } while (0) // 只用一次SEXT

void insertFtraceNode(int callType, vaddr_t from_pc, vaddr_t to_pc);

static void
decode_operand(Decode *s, int *rd, word_t *src1, word_t *src2, word_t *imm, int type)
{
  uint32_t i = s->isa.inst;
  int rs1 = BITS(i, 19, 15);
  int rs2 = BITS(i, 24, 20);
  *rd = BITS(i, 11, 7);
  switch (type)
  {
  case TYPE_I:
    src1R();
    immI();
    break;
  case TYPE_U:
    immU();
    break;
  case TYPE_S:
    src1R();
    src2R();
    immS();
    break;
  case TYPE_J:
    immJ();
    break;
  case TYPE_B:
    src1R();
    src2R();
    immB();
    break;
  case TYPE_R:
    src1R();
    src2R();
    break;
  case TYPE_N:
    break;
  default:
    panic("unsupported type = %d", type);
  }
}

// 负数转为正数计算
word_t mulh(sword_t a, sword_t b)
{
  int sign = ((a < 0) ^ (b < 0)) ? -1 : 1;
  uint64_t ua = a < 0 ? -(word_t)a : (word_t)a;
  uint64_t ub = b < 0 ? -(word_t)b : (word_t)b;
  uint64_t res = ua * ub;
  if (sign < 0)
    res = -res;
  return (word_t)(res >> 32);
}

word_t mulhsu(sword_t a, word_t b)
{
  int neg = a < 0;
  uint64_t ua = a < 0 ? -(word_t)a : (sword_t)a;
  uint64_t res = ua * b;
  if (neg)
    res = -res;
  return (word_t)(res >> 32);
}

void insertFtrace(int rd, word_t imm, int rs1, word_t pc, word_t dnpc)
{
#ifdef CONFIG_FTRACE
  if (rd == 1)
    insertFtraceNode(0, pc, dnpc);
  else if (rd == 0 && imm == 0 && rs1 == 1)
    insertFtraceNode(1, pc, dnpc);
#endif
}

word_t ecallFunction(word_t epc) // riscv32中保存的是自陷指令的pc
{
  bool success = true; // 失败时才会设置false
  word_t no;
#ifdef CONFIG_RVE
  no = isa_reg_str2val("a5", &success); // rv32e是保存在a5
#else
  no = isa_reg_str2val("a7", &success); // rv32/64是保存在a7
#endif
  Assert(success, "The reg not is recognized!");
  return isa_raise_intr(no, epc);
}

word_t mretFunction()
{
  if (cpu.mcause == 0xb) // m-mode传来的系统调用
  {
    // trap指令不应该再返回原PC了, 所以需要返回epc+4
    // 而DIFFTEST并没有实现这个+4 所以需要跳过一次ref
    IFDEF(CONFIG_DIFFTEST, difftest_skip_ref());
    return cpu.mepc + 0x4;
  }
  return cpu.mepc;
}

void csrrw_excute(word_t src1, word_t imm, int rd)
{
  switch (imm)
  {
  case 0x300:
    R(rd) = cpu.mstatus;
    cpu.mstatus = src1;
    break;
  case 0x305:
    R(rd) = cpu.mtvec;
    cpu.mtvec = src1;
    break;
  case 0x341:
    R(rd) = cpu.mepc;
    cpu.mepc = src1;
    break;
  case 0x342:
    R(rd) = cpu.mcause;
    cpu.mcause = src1;
    break;
  default:
    panic("The " FMT_WORD " csr not implemented", imm);
    break;
  }
}
void csrrs_excute(word_t src1, word_t imm, int rd)
{
  switch (imm)
  {
  case 0x300:
    R(rd) = cpu.mstatus;
    cpu.mstatus |= src1;
    break;
  case 0x305:
    R(rd) = cpu.mtvec;
    cpu.mtvec |= src1;
    break;
  case 0x341:
    R(rd) = cpu.mepc;
    cpu.mepc |= src1;
    break;
  case 0x342:
    R(rd) = cpu.mcause;
    cpu.mcause |= src1;
    break;
  default:
    panic("The " FMT_WORD " csr not implemented", imm);
    break;
  }
}

static int decode_exec(Decode *s)
{
  s->dnpc = s->snpc;

#define INSTPAT_INST(s) ((s)->isa.inst)
#define INSTPAT_MATCH(s, name, type, ... /* execute body */)         \
  {                                                                  \
    int rd = 0;                                                      \
    word_t src1 = 0, src2 = 0, imm = 0;                              \
    decode_operand(s, &rd, &src1, &src2, &imm, concat(TYPE_, type)); \
    __VA_ARGS__;                                                     \
  }

  INSTPAT_START();
  INSTPAT("??????? ????? ????? 000 ????? 00000 11", lb, I, R(rd) = SEXT(BITS(Mr(src1 + imm, 1), 7, 0), 8));
  INSTPAT("??????? ????? ????? 001 ????? 00000 11", lh, I, R(rd) = SEXT(BITS(Mr(src1 + imm, 2), 15, 0), 16));
  INSTPAT("??????? ????? ????? 010 ????? 00000 11", lw, I, R(rd) = SEXT(BITS(Mr(src1 + imm, 4), 31, 0), 32));
  INSTPAT("??????? ????? ????? 100 ????? 00000 11", lbu, I, R(rd) = Mr(src1 + imm, 1));
  INSTPAT("??????? ????? ????? 101 ????? 00000 11", lhu, I, R(rd) = Mr(src1 + imm, 2));

  INSTPAT("??????? ????? ????? 000 ????? 00100 11", addi, I, R(rd) = src1 + imm);
  INSTPAT("000000? ????? ????? 001 ????? 00100 11", slli, I, R(rd) = src1 << BITS(imm, 5, 0));
  INSTPAT("??????? ????? ????? 010 ????? 00100 11", slti, I, R(rd) = (sword_t)src1 < (sword_t)imm);
  INSTPAT("??????? ????? ????? 011 ????? 00100 11", sltiu, I, R(rd) = src1 < imm);
  INSTPAT("??????? ????? ????? 100 ????? 00100 11", xori, I, R(rd) = src1 ^ imm);
  INSTPAT("000000? ????? ????? 101 ????? 00100 11", srli, I, R(rd) = src1 >> BITS(imm, 5, 0));
  INSTPAT("010000? ????? ????? 101 ????? 00100 11", srai, I, R(rd) = (sword_t)src1 >> BITS(imm, 5, 0));
  INSTPAT("??????? ????? ????? 111 ????? 00100 11", andi, I, R(rd) = src1 & imm);
  INSTPAT("??????? ????? ????? 110 ????? 00100 11", ori, I, R(rd) = src1 | imm);

  INSTPAT("??????? ????? ????? ??? ????? 00101 11", auipc, U, R(rd) = s->pc + imm);

  INSTPAT("??????? ????? ????? 000 ????? 01000 11", sb, S, Mw(src1 + imm, 1, src2));
  INSTPAT("??????? ????? ????? 001 ????? 01000 11", sh, S, Mw(src1 + imm, 2, src2));
  INSTPAT("??????? ????? ????? 010 ????? 01000 11", sw, S, Mw(src1 + imm, 4, src2));

  INSTPAT("0000000 ????? ????? 000 ????? 01100 11", add, R, R(rd) = src1 + src2);
  INSTPAT("0100000 ????? ????? 000 ????? 01100 11", sub, R, R(rd) = src1 - src2);
  INSTPAT("0000000 ????? ????? 001 ????? 01100 11", sll, R, R(rd) = src1 << BITS(src2, 5, 0));
  INSTPAT("0000000 ????? ????? 010 ????? 01100 11", slt, R, R(rd) = (sword_t)src1 < (sword_t)src2);
  INSTPAT("0000000 ????? ????? 011 ????? 01100 11", sltu, R, R(rd) = src1 < src2);
  INSTPAT("0000000 ????? ????? 100 ????? 01100 11", xor, R, R(rd) = src1 ^ src2);
  INSTPAT("0000000 ????? ????? 101 ????? 01100 11", srl, R, R(rd) = src1 >> BITS(src2, 5, 0));
  INSTPAT("0100000 ????? ????? 101 ????? 01100 11", sra, R, R(rd) = (sword_t)src1 >> BITS(src2, 5, 0));
  INSTPAT("0000000 ????? ????? 110 ????? 01100 11", or, R, R(rd) = src1 | src2);
  INSTPAT("0000000 ????? ????? 111 ????? 01100 11", and, R, R(rd) = src1 & src2);
  INSTPAT("0000001 ????? ????? 000 ????? 01100 11", mul, R, R(rd) = (sword_t)src1 * (sword_t)src2);
  INSTPAT("0000001 ????? ????? 001 ????? 01100 11", mulh, R, R(rd) = mulh((sword_t)src1, (sword_t)src2));
  INSTPAT("0000001 ????? ????? 010 ????? 01100 11", mulhsu, R, R(rd) = mulhsu((sword_t)src1, src2));
  INSTPAT("0000001 ????? ????? 011 ????? 01100 11", mulhu, R, R(rd) = ((uint64_t)src1 * (uint64_t)src2) >> 32);
  INSTPAT("0000001 ????? ????? 100 ????? 01100 11", div, R, R(rd) = src2 == 0 ? -1 : (sword_t)src2 == -1 && (sword_t)src1 == INT32_MIN ? INT32_MIN
                                                                                                                                       : (sword_t)src1 / (sword_t)src2);
  INSTPAT("0000001 ????? ????? 101 ????? 01100 11", divu, R, R(rd) = src2 == 0 ? UINT32_MAX : src1 / src2);
  INSTPAT("0000001 ????? ????? 110 ????? 01100 11", rem, R, R(rd) = (sword_t)src2 == 0 ? (sword_t)src1 : ((sword_t)src1) == INT32_MIN && (sword_t)src2 == -1 ? 0
                                                                                                                                                             : (sword_t)src1 % (sword_t)src2);
  INSTPAT("0000001 ????? ????? 111 ????? 01100 11", remu, R, R(rd) = src2 == 0 ? src1 : src1 % src2);

  INSTPAT("??????? ????? ????? ??? ????? 01101 11", lui, U, R(rd) = imm);

  INSTPAT("??????? ????? ????? 000 ????? 11000 11", beq, B, s->dnpc = (src1 == src2) ? s->pc + imm : s->dnpc);
  INSTPAT("??????? ????? ????? 001 ????? 11000 11", bne, B, s->dnpc = (src1 != src2) ? s->pc + imm : s->dnpc);
  INSTPAT("??????? ????? ????? 100 ????? 11000 11", blt, B, s->dnpc = ((sword_t)src1 < (sword_t)src2) ? s->pc + imm : s->dnpc);
  INSTPAT("??????? ????? ????? 101 ????? 11000 11", bge, B, s->dnpc = ((sword_t)src1 >= (sword_t)src2) ? s->pc + imm : s->dnpc);
  INSTPAT("??????? ????? ????? 110 ????? 11000 11", bltu, B, s->dnpc = (src1 < src2) ? s->pc + imm : s->dnpc);
  INSTPAT("??????? ????? ????? 111 ????? 11000 11", bgeu, B, s->dnpc = (src1 >= src2) ? s->pc + imm : s->dnpc);
  INSTPAT("??????? ????? ????? 000 ????? 11001 11", jalr, I, s->dnpc = (src1 + imm) & ~1, R(rd) = s->snpc, insertFtrace(rd, imm, BITS(s->isa.inst, 19, 15), s->pc, s->dnpc));
  INSTPAT("??????? ????? ????? ??? ????? 11011 11", jal, J, s->dnpc = s->pc + imm, R(rd) = s->snpc, insertFtrace(rd, imm, BITS(s->isa.inst, 19, 15), s->pc, s->dnpc));

  INSTPAT("0000000 00000 00000 000 00000 11100 11", ecall, N, s->dnpc = ecallFunction(s->pc)); // 触发系统调用的pc
  INSTPAT("0011000 00010 00000 000 00000 11100 11", mret, N, s->dnpc = mretFunction());
  INSTPAT("??????? ????? ????? 001 ????? 11100 11", csrrw, I, csrrw_excute(src1, imm, rd));
  INSTPAT("??????? ????? ????? 010 ????? 11100 11", csrrs, I, csrrs_excute(src1, imm, rd));

  INSTPAT("0000000 00001 00000 000 00000 11100 11", ebreak, N, NEMUTRAP(s->pc, R(10))); // R(10) is $a0

  INSTPAT("??????? ????? ????? ??? ????? ????? ??", inv, N, INV(s->pc));
  INSTPAT_END();

  R(0) = 0; // reset $zero to 0

  return 0;
}

int isa_exec_once(Decode *s)
{
  s->isa.inst = inst_fetch(&s->snpc, 4);
  return decode_exec(s);
}
