#include <klib.h>
#include <am.h>
#include <klib-macros.h>
#include "common.h"
static uint8_t data[N];

#include <assert.h>
void reset(uint8_t *data) {
  int i;
  for (i = 0; i < N; i++) {
    data[i] = i + 1;
  }
}

// 检查 [l, r) 区间中的值是否依次为 val, val + 1, val + 2...
void check_seq(uint8_t *data,int l, int r, int val) {
  int i;
  for (i = l; i < r; i++) {
    if(data[i] != val + i - l)
    	panic("check_seq check error\n");
  }
}

// 检查 [l, r) 区间中的值是否均为 val
void check_eq(uint8_t *data,int l, int r, int val) {
  int i;
  for (i = l; i < r; i++) {
    if(data[i] != val)
    	panic("check_eq check error\n");
  }
}

void test_memset() {
  int l, r;
  for (l = 0; l < N; l ++) {
    for (r = l + 1; r <= N; r ++) {
      reset(data);
      uint8_t val = (l + r) / 2;
      memset(data + l, val, r - l);
      check_seq(data,0, l, 1);
      check_eq(data,l, r, val);
      check_seq(data,r, N, r + 1);
    }
  }
}
int main(){
    test_memset();
}
