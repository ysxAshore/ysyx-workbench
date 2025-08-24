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

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <assert.h>
#include <string.h>

// this should be enough
static char buf[65536] = {};
static char code_buf[65536 + 128] = {}; // a little larger than `buf`
static char *code_format =
    "#include <stdio.h>\n"
    "int main() { "
    "  unsigned result = %s; "
    "  printf(\"%%u\", result); "
    "  return 0; "
    "}";

// position which records current write location
static int position = 0;
static int error = 0;

uint32_t choose(uint32_t n)
{
  return rand() % n;
}

void gen_num()
{
  unsigned n = choose(1000);
  // n needs write the buf + position, return 写回的字符个数
  int need = snprintf(NULL, 0, "%u", n); // 计算需要的字符长度 不包括'\0'
  if (need < 0 || need >= sizeof(buf) - position)
  {
    error = 1;
    return;
  }
  position += sprintf(buf + position, "%u", n);
}

void gen_char(char c)
{
  // 只剩一字节留给了 '\0'
  if (position >= sizeof(buf) - 1)
  {
    error = 1;
    return;
  }
  buf[position++] = c;
}

char *gen_op()
{
  switch (choose(4))
  {
  case 0:
    return "+";
  case 1:
    return "-";
  case 2:
    return "*";
  case 3:
    return "/";
  default:
    return NULL;
  }
}

static void gen_rand_expr()
{
  // 随机生成空格
  int num = choose(10);
  for (int i = 0; i < num; ++i)
    gen_char(' ');
  switch (choose(3))
  {
  case 0:
    gen_num();
    break;
  case 1:
    gen_char('(');
    gen_rand_expr();
    gen_char(')');
    break;
  case 2:
    gen_rand_expr();
    int increment = snprintf(buf + position, sizeof(buf) - position, "%s", gen_op());
    if (increment == -1 || increment >= sizeof(buf) - position)
    {
      error = 1;
      break;
    } // 不改变position 之后可以覆盖存储
    else
      position += increment;
    gen_rand_expr();
    break;
  }
  num = choose(10);
  for (int i = 0; i < num; ++i)
    gen_char(' ');
}

// 静态除以0判断
void has_static_div_zero()
{
  for (int i = 0; buf[i]; ++i)
  {
    if (buf[i] == '/' && buf[i + 1])
    {
      // 跳过空格
      int j = i + 1;
      while (buf[j] == ' ')
        j++;
      if (buf[j] == '0')
        error = 1;
    }
  }
}

int main(int argc, char *argv[])
{
  int seed = time(0);
  srand(seed);
  int loop = 1;
  if (argc > 1)
  {
    sscanf(argv[1], "%d", &loop);
  }
  int i;
  for (i = 0; i < loop; i++)
  {
    position = 0;
    gen_rand_expr();
    // 长度限制不超过1024
    if (position >= 1024)
    {
      --i;
      continue;
    }
    // 生成后检测字符串中是否有静态除以0
    has_static_div_zero();
    if (error != 0)
    {
      --i;
      error = 0;
      continue;
    }

    sprintf(code_buf, code_format, buf);

    FILE *fp = fopen("/tmp/.code.c", "w");
    assert(fp != NULL);
    fputs(code_buf, fp);
    fclose(fp);

    // 若编译遇到警告 认为遇到错误 返回非0 -> 排除动态除以0
    int ret = system("gcc -Wall -Werror /tmp/.code.c -o /tmp/.expr");
    if (ret != 0)
    {
      --i;
      continue;
    }

    fp = popen("/tmp/.expr", "r");
    assert(fp != NULL);

    int result;
    ret = fscanf(fp, "%d", &result);
    pclose(fp);

    printf("%u %s\n", result, buf);
  }
  return 0;
}
