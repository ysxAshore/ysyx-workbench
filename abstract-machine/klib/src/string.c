#include <klib.h>
#include <klib-macros.h>
#include <stdint.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)

// 使用指针处理且在写时都事先确保指针不为NULL
size_t strlen(const char *s)
{
  const char *p = s;
  while (*p++)
    ;
  return p - s - 1;
}

char *strcpy(char *dst, const char *src)
{
  assert(dst != NULL);
  char *p = dst;
  while ((*p++ = *src++))
  {
  }
  return dst;
}

char *strncpy(char *dst, const char *src, size_t n)
{
  assert(dst != NULL);
  char *p = dst;
  while (n-- && (*p++ = *src++)) // while继续拷贝的前提是没拷贝够n字节且也没拷贝到src字符串尾
    ;
  if (n == 0)
    *p++ = '\0'; // 手动补充结束符
  while (n--)
    *p++ = '\0';
  return dst;
}

char *strcat(char *dst, const char *src)
{
  assert(dst != NULL);
  size_t len = strlen(dst);
  strcpy(dst + len, src);
  return dst;
}

// 相等时返回0 不等时返回不等的字符差值
int strcmp(const char *s1, const char *s2)
{
  if (s1 == NULL && s2 == NULL)
    return 0;
  assert(s1 != NULL && s2 != NULL);
  while (*s1 && (*s1 == *s2))
  {
    ++s1;
    ++s2;
  }
  return *s1 - *s2;
}

int strncmp(const char *s1, const char *s2, size_t n)
{
  if (n == 0 || (s1 == NULL && s2 == NULL))
    return 0;
  assert(s1 != NULL && s2 != NULL);
  while (--n && *s1 && (*s1 == *s2))
  {
    ++s1;
    ++s2;
  }
  // n=1时执行这个 不然最后会判断成 '\0' - '\0'
  return *s1 - *s2;
}

void *memset(void *s, int c, size_t n)
{
  unsigned char *p = s;
  while (n--)
    *p++ = (unsigned char)c;
  return s;
}

void *memmove(void *dst, const void *src, size_t n)
{
  // 需要考虑覆盖——解决覆盖的一个方法是全部进行反向复制
  // 但是并不能够全部进行反向复制
  // 这是因为 "正向便利更容易Cache命中" "一些平台会在不重叠时调用性能更好的memcpy" "编译器对0...n的优化比n...0更好"
  unsigned char *d = dst;
  const unsigned char *s = src;

  if (d == s)
    return dst;
  if (d < s || d >= s + n)
    // 可以正向复制 d < s时可能会重叠 但是此时可以进行正向复制
    for (size_t i = 0; i < n; i++)
      d[i] = s[i];
  else
    // 有重叠，反向复制
    for (size_t i = n; i > 0; i--)
      d[i - 1] = s[i - 1];
  return dst;
}

void *memcpy(void *out, const void *in, size_t n)
{
  // 不用考虑覆盖
  unsigned char *d = out;
  const unsigned char *s = in;
  while (n--)
    *d++ = *s++;
  return out;
}

int memcmp(const void *s1, const void *s2, size_t n)
{
  // 类似strncmp
  const unsigned char *p1 = s1;
  const unsigned char *p2 = s2;
  if (n == 0)
    return 0;
  while (--n && *p1 && (*p1 == *p2))
  { // 当n=1时 执行 *s1-*s2 即上面的i=n-1的情况
    ++p1;
    ++p2;
  }
  return *p1 - *p2;
}

#endif
