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

void test_memcpy() {
    reset(data);

    // 1. 非重叠区域测试
    memcpy(data + 8, data, 8);    // 将前8个字节复制到位置8开始
    check_seq(data,8, 16, 1);          // 验证复制区域

    // 2. 检查重叠区域的行为
    // 这里我们测试 memcpy 在重叠时会导致数据不一致
    reset(data);
    memcpy(data + 4, data, 12);   // 重叠复制，可能导致不一致
    // 不验证内容，因为重叠区域行为未定义，可能会有不正确数据
}
int main(){
    test_memcpy();
}
