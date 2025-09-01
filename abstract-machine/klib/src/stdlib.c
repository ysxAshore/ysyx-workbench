#include <am.h>
#include <klib.h>
#include <klib-macros.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)
static unsigned long int next = 1;

int rand(void)
{
  // RAND_MAX assumed to be 32767
  next = next * 1103515245 + 12345;
  return (unsigned int)(next / 65536) % 32768;
}

void srand(unsigned int seed)
{
  next = seed;
}

int abs(int x)
{
  return (x < 0 ? -x : x);
}

int atoi(const char *nptr)
{
  int x = 0;
  while (*nptr == ' ')
  {
    nptr++;
  }
  while (*nptr >= '0' && *nptr <= '9')
  {
    x = x * 10 + *nptr - '0';
    nptr++;
  }
  return x;
}

static uintptr_t hbrk;
static bool firstCall = false;
void *malloc(size_t size)
{
  // On native, malloc() will be called during initializaion of C runtime.
  // Therefore do not call panic() here, else it will yield a dead recursion:
  //   panic() -> putchar() -> (glibc) -> malloc() -> panic()
#if !(defined(__ISA_NATIVE__) && defined(__NATIVE_USE_KLIB__))
  // extern Area heap;
  // static uintptr_t hbrk = (uintptr_t)heap.start; 不能这么写 static变量的初始化只能来自于编译期常量 而heap.start是链接时常量
  if (!firstCall)
  {
    extern Area heap;
    hbrk = (uintptr_t)heap.start;
    firstCall = true;
  }

  size = (size_t)ROUNDUP(size, 8);
  char *old = (char *)hbrk;
  hbrk += size;
  assert((uintptr_t)heap.start <= hbrk && hbrk < (uintptr_t)heap.end); // 不超过heap范围
  memset(old, 0, size);
  return old;
#endif
  return NULL;
}

void free(void *ptr)
{
}

#endif
