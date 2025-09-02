/***************************************************************************************
 * Copyright (c) 2014-2024 Zihao Yu, Nanjing University
 *
 * NPC is licensed under Mulan PSL v2.
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

#include <isa.h>
#include <memory/paddr.h>
#include <readline/readline.h>
#include <readline/history.h>
#include "sdb.h"

extern NPCState npc_state;
static int is_batch_mode = false;

void init_regex();
void init_wp_pool();

/* We use the `readline' library to provide more flexibility to read from stdin. */
static char *rl_gets()
{
  static char *line_read = NULL;

  if (line_read)
  {
    free(line_read);
    line_read = NULL;
  }

  line_read = readline("(npc) ");

  if (line_read && *line_read)
  {
    add_history(line_read);
  }

  return line_read;
}

static int cmd_c(char *args)
{
  cpu_exec(-1);
  return 0;
}

static int cmd_si(char *args)
{
  uint64_t n = 1;
  if (args == NULL)
    cpu_exec(1);
  else
  {
    // strspn(str1, str2) 检测str1起始位置开始有多少字符完全属于str2 --> 可以用来判断是否完全由字母 数字等组成
    if (strspn(args, "0123456789") == strlen(args))
    {
      sscanf(args, "%ld", &n);
      cpu_exec(n);
    }
    else
      printf("Unkown command 'si %s',si could have a num argument\n", args);
  }
  return 0;
}
static int cmd_info(char *args)
{
  char *arg = strtok(NULL, " ");
  if (arg == NULL)
    printf("Unkown command,info must have one argument\n");
  else
  {
    char *tmp = strtok(NULL, " ");
    if (tmp == NULL)
    {
      if (strcmp(arg, "r") == 0)
        isa_reg_display();
      if (strcmp(arg, "w") == 0)
        displayWatchPoint();
    }
    else
      printf("Unkown command 'info %s',info must have one argument\n", args);
  }
  return 0;
}

static int cmd_x(char *args)
{
  if (args == NULL)
    printf("Unknown command 'x',x must have two arguments\n");
  else
  {
    char *arg = strtok(NULL, " ");
    if (strspn(arg, "0123456789") != strlen(arg))
      printf("Unknown command 'x %s',the first argument must be a number\n", args);
    else
    {
      uint64_t N;
      sscanf(arg, "%ld", &N);
      arg = strtok(NULL, " ");
      char *tmp = strtok(NULL, " ");
      if (strspn(arg, "0123456789abcdefx") == strlen(arg) && tmp == NULL)
      {
        paddr_t address;
        sscanf(arg, "%x", &address);
        int i;
        for (i = 0; i < N / 4; ++i)
        {
          printf(FMT_PADDR ":" FMT_WORD "\n", address, paddr_read(address, 4));
          address += 4;
        }
        if (i * 4 < N)
          printf(FMT_PADDR ":" FMT_WORD "\n", address, paddr_read(address, N - i * 4));
      }
      else
        printf("Unknown command 'x %s',the second argument must be a hex number\n", args);
    }
  }
  return 0;
}

static int cmd_test(char *args)
{
  if (args == NULL)
  {
    FILE *f = fopen("tools/gen-expr/build/input.txt", "r");
    assert(f != NULL);
    char buf[65600];
    while (fgets(buf, sizeof(buf), f) != NULL)
    {
      char *ref_result = strtok(buf, " ");
      word_t ref_res;
      sscanf(ref_result, "%u", &ref_res);
      char *ref_expr = strtok(NULL, "\n");
      bool success = true;
      word_t myRes = expr(ref_expr, &success);
      if (success)
      {
        if (myRes == ref_res)
          printf("%s==%s success\n", ref_expr, ref_result);
        else
          printf("%s==%s failed\n", ref_expr, ref_result);
      }
      else
        printf("token failed\n");
    }
  }
  else
    printf("Unknown command 'test %s',test must have no argument\n", args);
  return 0;
}

static int cmd_expr(char *args)
{
  if (args == NULL)
    printf("Unknown command 'expr',test must have no argument\n");
  else
  {
    bool success = true;
    word_t val = expr(args, &success);
    if (success)
      printf(FMT_WORD "\n", val);
    else
      printf("The %s expression evals failed\n", args);
  }
  return 0;
}

static int cmd_d(char *args)
{
  if (args == NULL)
    printf("the command d needs a parameter reprented the WatchPoint Number\n");
  else
  {
    char *number = strtok(NULL, " ");
    char *temp = strtok(NULL, " ");
    if (temp == NULL)
    {
      int N;
      int tag = sscanf(number, "%d", &N);
      if (tag == 0 || tag == EOF)
        printf("the %s must be a integer\n", args);
      else
        deleteWatchPoint(N);
    }
    else
      printf("the %s must be only a parameter\n", args);
  }
  return 0;
}

static int cmd_w(char *args)
{
  if (args == NULL)
    printf("the command w needs a parameter reprented the expression watched\n");
  else
    createWatchPoint(args);
  return 0;
}

static int cmd_q(char *args)
{
  if (args == NULL)
  {
    npc_state.state = NPC_QUIT;
    cpu_exec(0); // 复用cpu_exec函数中最后的switch状态处理
  }
  else
    printf("Unkown command 'q %s',q must have zero argument\n", args);
  return -1;
}

static int cmd_help(char *args);

static struct
{
  const char *name;
  const char *description;
  int (*handler)(char *);
} cmd_table[] = {
    {"help", "Display information about all supported commands", cmd_help},
    {"c", "Continue the execution of the program", cmd_c},
    {"q", "Exit NPC", cmd_q},
    {"si", "Excute cpu n steps", cmd_si},
    {"info", "Print the information which prefered by args,supported r and w", cmd_info},
    {"x", "print the N elements in memory that begin with address", cmd_x},
    {"test", "test the expr function", cmd_test},
    {"expr", "get the expr value", cmd_expr},
    {"d", "delete the Number N watchpoint", cmd_d},
    {"w", "add a watchpoint,the argument refers the expression", cmd_w},
    /* TODO: Add more commands */

};

#define NR_CMD ARRLEN(cmd_table)

static int cmd_help(char *args)
{
  /* extract the first argument */
  char *arg = strtok(NULL, " ");
  int i;

  if (arg == NULL)
  {
    /* no argument given */
    for (i = 0; i < NR_CMD; i++)
    {
      printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
    }
  }
  else
  {
    char *tmp = strtok(NULL, " ");
    for (i = 0; i < NR_CMD; i++)
    {
      if (strcmp(arg, cmd_table[i].name) == 0 && tmp == NULL)
      {
        printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
        return 0;
      }
    }
    printf("Unknown command '%s'\n", arg);
  }
  return 0;
}

void sdb_set_batch_mode()
{
  is_batch_mode = true;
}

void sdb_mainloop()
{
  if (is_batch_mode)
  {
    cmd_c(NULL);
    return;
  }

  for (char *str; (str = rl_gets()) != NULL;)
  {
    char *str_end = str + strlen(str);

    /* extract the first token as the command */
    char *cmd = strtok(str, " ");
    if (cmd == NULL)
    {
      continue;
    }

    /* treat the remaining string as the arguments,
     * which may need further parsing
     */
    char *args = cmd + strlen(cmd) + 1;
    if (args >= str_end)
    {
      args = NULL;
    }

#ifdef CONFIG_DEVICE
    // extern void sdl_clear_event_queue();
    // sdl_clear_event_queue();
#endif

    int i;
    for (i = 0; i < NR_CMD; i++)
    {
      if (strcmp(cmd, cmd_table[i].name) == 0)
      {
        if (cmd_table[i].handler(args) < 0)
        {
          return;
        }
        break;
      }
    }

    if (i == NR_CMD)
    {
      printf("Unknown command '%s'\n", cmd);
    }
  }
}

void init_sdb()
{
  /* Compile the regular expressions. */
  init_regex();

  /* Initialize the watchpoint pool. */
  init_wp_pool();
}
