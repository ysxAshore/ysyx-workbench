#include <klib.h>
#include <am.h>
#include <klib-macros.h>
#include "common.h"
#include <assert.h>

static uint8_t data1[N];
static uint8_t data2[N];

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

void test_memcmp() {
    reset(data1);
    reset(data2);
    // 1. 全部相同
    int result = memcmp(data1, data2, N);
    if(result != 0)     // 检查是否为相同内容
        panic("This should equal\n");

    // 2. 部分相同，尾部不同
    data2[N - 1] = 0;        // 修改 data2 的最后一个字节
    result = memcmp(data1, data2, N);
    if(result <= 0)      // data1 最后一个字节 32 > data2 最后一个字节 0
    	panic("This should bigger\n");
    // 3. 开头不同
    data2[0] = 0;            // 修改 data2 的第一个字节
    result = memcmp(data1, data2, N);
    if(result <= 0)      // data1 第一个字节 1 > data2 第一个字节 0
	panic("This should bigger\n");
    // 4. 中间不同
    data2[0] = 1;            // 恢复第一个字节
    data2[15] = 100;         // 修改中间字节
    result = memcmp(data1, data2, N);
    if(result >= 0)      // data1 第16个字节 16 < data2 第16个字节 100
    	panic("This should smaller\n");
    // 5. 比较前0~14
    result = memcmp(data1, data2, N / 2-1);
    if(result != 0)     // 前0~14相同
    	panic("This should equal\n");
}
int main(){
    test_memcmp();
}
