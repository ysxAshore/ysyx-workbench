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

// 测试 memmove
void test_memmove() {
    reset(data);

    // 1. 非重叠区域测试
    memmove(data + 8, data, 8);  // 将前8个字节复制到位置8开始
    check_seq(data,8, 16, 1);         // 验证复制区域

    // 2. 目标在源后，存在部分重叠
    reset(data);
    memmove(data + 4, data, 12); // 将前12个字节复制到位置4开始
    check_seq(data,4, 16, 1);         // 验证数据没有因重叠被破坏

    // 3. 目标在源前，存在部分重叠
    reset(data);
    memmove(data, data + 4, 12); // 从位置4复制到开始位置
    check_seq(data,0, 12, 5);         // 验证数据没有因重叠被破坏
}
int main(){
    test_memmove();
}
