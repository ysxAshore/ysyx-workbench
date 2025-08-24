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

#include "sdb.h"

#define NR_WP 32

typedef struct watchpoint
{
  int NO;
  struct watchpoint *next;

  /* TODO: Add more members if necessary */
  /* watchpoint find the record expression value change,output it
   so needs the watchpoint expression and the current value*/
  char *expression;
  word_t value;
} WP;

static WP wp_pool[NR_WP] = {};

// head: record the has traced the expression, head->next is valid
// free: record the free watchpoint, free->next is valid
// both with the header pointer list
static WP *head = NULL, *free_ = NULL;

void init_wp_pool()
{
  int i;
  for (i = 0; i < NR_WP; i++)
  {
    wp_pool[i].NO = i;
    wp_pool[i].next = (i == NR_WP - 1 ? NULL : &wp_pool[i + 1]);
  }

  head = calloc(1, sizeof(WP));
  head->next = NULL;
  free_ = calloc(1, sizeof(WP));
  free_->next = wp_pool;
}

/* TODO: Implement the functionality of watchpoint */
WP *new_wp()
{
  if (free_->next == NULL)
  {
    printf("No entry for use\n");
    return NULL;
  }
  else
  {
    WP *wp = free_->next;
    free_->next = wp->next;
    wp->next = head->next;
    head->next = wp;
    return wp;
  }
}

void free_wp(WP *wp)
{
  if (wp == NULL)
    return;

  // 找到wp在head中的位置
  WP *p = head;
  while (p->next)
  {
    if (p->next == wp)
      break;
    p = p->next;
  }
  p->next = wp->next;
  wp->next = free_->next;
  free_->next = wp;
}

void createWatchPoint(char *args)
{
  WP *wp = new_wp();
  word_t value;
  bool sign = true;
  value = expr(args, &sign);
  if (wp != NULL && sign)
  {
    wp->expression = (char *)calloc(strlen(args) + 1, sizeof(char));
    strcpy(wp->expression, args);
    wp->value = value;
    printf("The %d watch has created,%s = " FMT_WORD "\n", wp->NO, wp->expression, wp->value);
  }
  else
    printf("The %s watch creates failed\n", wp->expression);
}

void checkWatchPoint()
{
  WP *p = head->next;
  while (p)
  {
    bool sign = true;
    word_t value = expr(p->expression, &sign);
    if (sign && value != p->value)
    {
      printf("The %d watch watches the expression %s has changed,from " FMT_WORD " to " FMT_WORD "\n", p->NO, p->expression, p->value, value);
      p->value = value;
      nemu_state.state = NEMU_STOP; // 暂停
    }
    p = p->next;
  }
}

void displayWatchPoint()
{
  WP *p = head->next;
  while (p)
  {
    printf("The %d watch is %s = " FMT_WORD "\n", p->NO, p->expression, p->value);
    p = p->next;
  }
}

void deleteWatchPoint(int NO)
{
  WP *p = head->next;
  while (p)
  {
    if (p->NO == NO)
      break;
    p = p->next;
  }
  free_wp(p);
  printf("The %d watch %s = " FMT_WORD " has deleted\n", p->NO, p->expression, p->value);
}
