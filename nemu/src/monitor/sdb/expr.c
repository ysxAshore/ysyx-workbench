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

#include <isa.h>

/* We use the POSIX regex functions to process regular expressions.
 * Type 'man regex' for more information about POSIX regex functions.
 */
#include <regex.h>
#include <memory/paddr.h>

enum
{
  TK_NOTYPE = 256,
  TK_EQ,
  TK_NOTEQ,
  TK_DECNUM,
  TK_POS,
  TK_NEG,
  TK_AND,
  TK_REG,
  TK_HEXNUM,
  TK_REF
  /* TODO: Add more token types */
};

static struct rule
{
  const char *regex;
  int token_type;
} rules[] = {

    /* TODO: Add more rules.
     * Pay attention to the precedence level of different rules.
     * 正则表达式中的 + - * () $都需要转义 而字符串中\为转移字符 所以需要\\表示反斜杠 再组成\+等表示正则表达式中的普通字符
     */

    {" +", TK_NOTYPE},                // spaces
    {"\\+", '+'},                     // plus
    {"==", TK_EQ},                    // equal
    {"!=", TK_NOTEQ},                 // not equal
    {"0[xX][0-9a-fA-F]+", TK_HEXNUM}, // hex number 需要在TK_DEXNUM前不然会把0当做decimal integer
    {"[0-9]+", TK_DECNUM},            // decimal integer
    {"\\-", '-'},                     // sub
    {"\\*", '*'},                     // multiply
    {"/", '/'},                       // div
    {"\\(", '('},                     // left brace
    {"\\)", ')'},                     // right brace
    {"&&", TK_AND},                   // and op
    {"\\$[0-9a-z]{1,3}", TK_REG},     // register name 寄存器从$pc $0 $ra ... $s11
};

#define NR_REGEX ARRLEN(rules)

static regex_t re[NR_REGEX] = {};

/* Rules are used for many times.
 * Therefore we compile them only once before any usage.
 */
void init_regex()
{
  int i;
  char error_msg[128];
  int ret;

  for (i = 0; i < NR_REGEX; i++)
  {
    ret = regcomp(&re[i], rules[i].regex, REG_EXTENDED);
    if (ret != 0)
    {
      regerror(ret, &re[i], error_msg, 128);
      panic("regex compilation failed: %s\n%s", error_msg, rules[i].regex);
    }
  }
}

typedef struct token
{
  int type;
  char str[32];
} Token;

static Token tokens[65536] __attribute__((used)) = {};
static int nr_token __attribute__((used)) = 0;

#define TOKEN_STRLEN ARRLEN(tokens[0].str)

static bool make_token(char *e)
{
  int position = 0;
  int i;
  regmatch_t pmatch;

  nr_token = 0;

  while (e[position] != '\0')
  {
    /* Try all rules one by one. */
    for (i = 0; i < NR_REGEX; i++)
    {
      // 完全按顺序匹配 因此若匹配 pmatch.so = position
      if (regexec(&re[i], e + position, 1, &pmatch, 0) == 0 && pmatch.rm_so == 0)
      {
        char *substr_start = e + position;
        int substr_len = pmatch.rm_eo;

        Log("match rules[%d] = \"%s\" at position %d with len %d: %.*s",
            i, rules[i].regex, position, substr_len, substr_len, substr_start);

        position += substr_len;

        /* TODO: Now a new token is recognized with rules[i]. Add codes
         * to record the token in the array `tokens'. For certain types
         * of tokens, some extra actions should be performed.
         */

        switch (rules[i].token_type)
        {
        case TK_NOTYPE: // if it is brace ,ignore it
          break;
        case '+':
          tokens[nr_token].type = '+';
          tokens[nr_token].str[0] = '\0';
          ++nr_token;
          break;
        case TK_EQ:
          tokens[nr_token].type = TK_EQ;
          tokens[nr_token].str[0] = '\0';
          ++nr_token;
          break;
        case TK_DECNUM:
          tokens[nr_token].type = TK_DECNUM;
          if (substr_len > TOKEN_STRLEN)
          {
            printf("the num %.*s is so big\n", substr_len, substr_start);
            return false;
          }
          strncpy(tokens[nr_token].str, substr_start, substr_len);
          tokens[nr_token].str[substr_len] = '\0';
          ++nr_token;
          break;
        case '-':
          tokens[nr_token].type = '-';
          tokens[nr_token].str[0] = '\0';
          ++nr_token;
          break;
        case '*':
          tokens[nr_token].type = '*';
          tokens[nr_token].str[0] = '\0';
          ++nr_token;
          break;
        case '/':
          tokens[nr_token].type = '/';
          tokens[nr_token].str[0] = '\0';
          ++nr_token;
          break;
        case '(':
          tokens[nr_token].type = '(';
          tokens[nr_token].str[0] = '\0';
          ++nr_token;
          break;
        case ')':
          tokens[nr_token].type = ')';
          tokens[nr_token].str[0] = '\0';
          ++nr_token;
          break;
        case TK_NOTEQ:
          tokens[nr_token].type = TK_NOTEQ;
          tokens[nr_token].str[0] = '\0';
          ++nr_token;
          break;
        case TK_AND:
          tokens[nr_token].type = TK_AND;
          tokens[nr_token].str[0] = '\0';
          ++nr_token;
          break;
        case TK_REG:
          tokens[nr_token].type = TK_REG;
          strncpy(tokens[nr_token].str, substr_start + 1, substr_len - 1); // 去除$字符
          tokens[nr_token].str[substr_len - 1] = '\0';
          ++nr_token;
          break;
        case TK_HEXNUM:
          tokens[nr_token].type = TK_HEXNUM;
          strncpy(tokens[nr_token].str, substr_start, substr_len); // 去除$字符
          tokens[nr_token].str[substr_len] = '\0';
          ++nr_token;
          break;
        default:
          TODO();
        }

        break;
      }
    }

    if (i == NR_REGEX)
    {
      printf("no match at position %d\n%s\n%*.s^\n", position, e, position, "");
      return false;
    }
  }

  return true;
}

static int error = 0;
// 检查是否有(表达式)
bool check_parentheses(int p, int q)
{
  // use stack method
  // encouter a left brace, ++eq, a right brace --eq
  if (tokens[p].type != '(')
    return false;
  else
  {
    int eq = 1;
    for (int i = p + 1; i <= q; ++i)
    {
      if (tokens[i].type == '(')
        ++eq;
      if (tokens[i].type == ')')
        --eq;
      if (eq < 0)
      {
        error = 1;
        return false;
      }
      else if (eq == 0 && i != q) // eg:"(a+b) + c" the left brace which refered by p has encoutered the right brace before q
        return false;
    }
    if (eq == 0)
      return true;
    return false;
  }
}

// 定义运算符优先级 主运算符选择优先级低的
int precedence(int op)
{
  if (op == TK_AND)
    return 1;
  if (op == TK_EQ || op == TK_NOTEQ)
    return 2;
  if (op == '+' || op == '-')
    return 3;
  if (op == '*' || op == '/')
    return 4;
  if (op == TK_POS || op == TK_NEG || op == TK_REF)
    return 5;
  return 0;
}

// 检查是否为运算符
int is_operator(int c)
{
  return c == '+' || c == '-' || c == '*' || c == '/' || c == TK_POS || c == TK_NEG || c == TK_EQ || c == TK_NOTEQ || c == TK_AND || c == TK_REF;
}

int find_main_operator(int p, int q)
{
  int main_op = -1;
  int min_precedence = 6; // 初始化为一个未使用的较大的值

  // 用于计算括号内的表达式的栈
  int *paren_stack = (int *)malloc(sizeof(int) * nr_token);
  int stack_size = 0;

  for (int i = p; i <= q; i++)
  {
    int type = tokens[i].type;
    if (type == '(')
    {
      // 遇到左括号，记录位置
      paren_stack[stack_size++] = i;
    }
    else if (type == ')')
    {
      // 遇到右括号，弹出栈
      if (stack_size > 0)
      {
        --stack_size;
      }
    }
    else if (is_operator(type) && stack_size == 0) // 该运算符不在()中
    {
      // 只考虑顶层（栈为空时）的运算符
      int op_precedence = precedence(type);
      if (op_precedence <= min_precedence && !(min_precedence == 5 && op_precedence == 5))
      { // 除正负号外多个相同优先级运算符时 根据结合律取最右侧的
        min_precedence = op_precedence;
        main_op = i;
      }
    }
  }

  free(paren_stack);
  return main_op;
}

word_t eval(int p, int q)
{
  if (p > q)
    return 0;
  else if (p == q)
  {
    word_t num = 0;
    switch (tokens[p].type)
    {
    case TK_DECNUM:
      sscanf(tokens[p].str, "%d", &num);
      break;
    case TK_HEXNUM:
      sscanf(tokens[p].str, "%x", &num);
      break;
    case TK_REG:
      bool success = true;
      if (strcmp(tokens[p].str, "0") == 0)
        return 0;
      num = isa_reg_str2val(tokens[p].str, &success);
      if (!success)
      {
        printf("unknown register name %s\n", tokens[p].str);
        error = 1;
      }
      break;
    default:
      Assert(false, "No matched %d", tokens[p].type);
    }
    return num;
  }
  else if (check_parentheses(p, q))
    return eval(p + 1, q - 1);
  else
  {
    int mainOp = find_main_operator(p, q);
    // 中间值a和b 如果使用无符号类型 那么对于负值会变成极大值 影响计算结果
    MUXDEF(CONFIG_ISA64, long, int)
    a = eval(p, mainOp - 1);
    MUXDEF(CONFIG_ISA64, long, int)
    b = eval(mainOp + 1, q);
    switch (tokens[mainOp].type)
    {
    case '+':
      return a + b;
    case '-':
      return a - b;
    case '*':
      return a * b;
    case '/':
      return a / b;
    case TK_POS:
      return b;
    case TK_NEG:
      return -1 * b;
    case TK_AND:
      return a && b;
    case TK_EQ:
      return a == b;
    case TK_NOTEQ:
      return a != b;
    case TK_REF:
      return paddr_read(b, sizeof(uint32_t));
    default:
      return 0;
    }
  }
}

word_t expr(char *e, bool *success)
{
  if (!make_token(e))
  {
    *success = false;
    return 0;
  }

  for (int i = 0; i < nr_token; ++i)
  {
    if (tokens[i].type == '+' && (i == 0 || (tokens[i - 1].type != ')' && tokens[i - 1].type != TK_DECNUM && tokens[i - 1].type != TK_HEXNUM)))
      tokens[i].type = TK_POS;
    if (tokens[i].type == '-' && (i == 0 || (tokens[i - 1].type != ')' && tokens[i - 1].type != TK_DECNUM && tokens[i - 1].type != TK_HEXNUM)))
      tokens[i].type = TK_NEG;
    if (tokens[i].type == '*' && (i == 0 || (tokens[i - 1].type != ')' && tokens[i - 1].type != TK_DECNUM && tokens[i - 1].type != TK_HEXNUM)))
      tokens[i].type = TK_REF;
  }

  /* TODO: Insert codes to evaluate the expression. */
  error = 0;
  if (error == 1)
  {
    *success = false;
    return 0;
  }
  return eval(0, nr_token - 1);
}
