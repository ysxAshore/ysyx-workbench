#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include <stdarg.h>
#include <limits.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)

// 支持2~36进制的数字字符
static const char digits_l[] = "0123456789abcdefghijklmnopqrstuvwxyz";
static const char digits_u[] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

/**
 * 通用整数转字符串函数
 *
 * @param buf      输出缓冲区，需足够大
 * @param num      数值（可以是有符号或无符号的 64 位）
 * @param is_signed 是否是有符号数
 * @param base     进制（2~36）
 * @param upper    是否使用大写（用于16进制）
 * @return 返回转换的字符串长度
 */
int num2str(char *buf, uint64_t num, bool is_signed, int base, bool upper)
{
  // 使用指针原地计算 尽量不用栈
  char *p = buf;
  char *start = buf;
  const char *digits = upper ? digits_u : digits_l;

  if (base < 2 || base > 36)
  {
    *p = '\0';
    return 0;
  }

  // 特殊处理0
  if (num == 0)
  {
    *p++ = '0';
    *p = '\0';
    return 1;
  }

  // 负数处理
  if (is_signed && (int64_t)num < 0)
  {
    *p++ = '-';
    start++; // 从 '-' 后面开始反转
    if ((int64_t)num == LLONG_MIN)
      num = (uint64_t)9223372036854775808ULL; // |INT64_MIN|
    else
      num = (uint64_t)(-(int64_t)num);
  }

  // 生成数字字符串，但顺序是反的
  while (num > 0)
  {
    *p++ = digits[num % base];
    num /= base;
  }
  *p = '\0';

  // 反转
  char *end = p - 1;
  while (start < end)
  {
    char temp = *start;
    *start = *end;
    *end = temp;
    start++;
    end--;
  }
  return p - buf;
}

int vsprintf(char *out, const char *fmt, va_list ap)
{
  char *p = out;
  const char *fmt_ptr = fmt;
  char tmp_str[65] = {'\0'};
  while (*fmt_ptr)
  {
    if (*fmt_ptr == '%' && *(fmt_ptr + 1) != '\0')
    {
      // width padding处理
      int width = 0;
      char padding_char = ' ';
      ++fmt_ptr;

      if (*fmt_ptr == '0')
      {
        padding_char = '0';
        ++fmt_ptr;
      }

      // 字符串转数值 得到width
      while (*fmt_ptr >= '0' && *fmt_ptr <= '9')
      {
        width = width * 10 + *fmt_ptr - '0';
        if (width > INT_MAX) // 最大宽度
          width = INT_MAX;
        ++fmt_ptr;
      }

      int l_num = 0;
      // 处理ll和l
      if (*fmt_ptr == 'l')
      {
        ++fmt_ptr;
        ++l_num;
        if (*fmt_ptr == 'l')
        {
          ++fmt_ptr;
          ++l_num;
        }
      }
      char spec = *fmt_ptr;

      if (spec == 'd' || spec == 'u' || spec == 'o' || spec == 'O' || spec == 'x' || spec == 'X')
      {
        int base = 0;
        bool upper = false, issigned = false;
        uint64_t temp;
        switch (spec)
        {
        case 'd':
          base = 10;
          issigned = true;
          temp = l_num == 2 ? va_arg(ap, long long) : l_num == 1 ? va_arg(ap, long)
                                                                 : va_arg(ap, int);
          break;
        case 'u':
          base = 10;
          issigned = false;
          temp = l_num == 2 ? va_arg(ap, unsigned long long) : l_num == 1 ? va_arg(ap, unsigned long)
                                                                          : va_arg(ap, unsigned int);
          break;
        case 'O':
          upper = true;
        case 'o':
          base = 8;
          issigned = false;
          temp = va_arg(ap, unsigned int);
          break;
        case 'X':
          upper = true;
        case 'x':
          base = 16;
          issigned = false;
          temp = va_arg(ap, unsigned int);
          break;
        }
        int len = num2str(tmp_str, temp, issigned, base, upper);

        if (len < width)
        {
          int rem = width - len;
          while (rem--)
            *p++ = padding_char;
        }
        for (int i = 0; i < len; ++i)
          *p++ = tmp_str[i];
      }
      else
      {
        if (l_num == 2)
        {
          *p++ = 'l';
          *p++ = 'l';
        }
        else if (l_num == 1)
          *p++ = 'l';

        switch (spec)
        {
        case 'c':
          char c = va_arg(ap, int); // char会被提升为int
          *p++ = c;
          break;
        case 's':
          char *tmp_s = va_arg(ap, char *);
          while ((*p++ = *tmp_s++))
            ;
          break;
        default:
          *p++ = spec;
          break;
        }
      }
      ++fmt_ptr;
    }
    else
      *p++ = *fmt_ptr++;
  }
  *p = '\0';
  va_end(ap);
  return p - out; // 返回这次转换的字符数
}

int printf(const char *fmt, ...)
{
  char s[strlen(fmt) + 256];
  va_list ap;
  va_start(ap, fmt);
  int n = vsprintf(s, fmt, ap);
  putstr(s);
  return n;
}

int sprintf(char *out, const char *fmt, ...)
{
  va_list arglist;
  va_start(arglist, fmt);
  int n = vsprintf(out, fmt, arglist);
  return n;
}

int snprintf(char *out, size_t n, const char *fmt, ...)
{
  panic("Not implemented");
}

int vsnprintf(char *out, size_t n, const char *fmt, va_list ap)
{
  panic("Not implemented");
}

#endif
