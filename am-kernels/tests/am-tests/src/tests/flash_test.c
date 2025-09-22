#include <amtest.h>

void flash_test()
{
    uintptr_t flash_addr = 0x30000000;
    uint32_t test_size = 10000;
    
    // 读测试阶段
    uint8_t *byte_ptr = (uint8_t *)flash_addr;
    uint16_t *half_ptr = (uint16_t *)flash_addr;
    uint32_t *word_ptr = (uint32_t *)flash_addr;

    putstr("=== Byte Read ===\n");
    for (int i = 0; i < test_size; i++)
    {
         uint8_t data = byte_ptr[i];
         panic_on(data != (uint8_t)i, "error");
    }

    putstr("=== Half Read ===\n");
    for (int i = 0; i < test_size / 2; i++)
    {
         uint16_t data = half_ptr[i];
		 uint16_t expected_value = ((uint8_t)(i * 2 + 1) << 8) | (uint8_t)(i * 2);
         panic_on(data != expected_value, "error");
    }

    putstr("=== Word Read ===\n");
    for (int i = 0; i < test_size / 4; i++)
    {
         uint32_t data = word_ptr[i];
		 uint32_t expected_value = ((uint8_t)(i * 4 + 3) << 24) | ((uint8_t)(i * 4 + 2) << 16) | ((uint8_t)(i * 4 + 1) << 8) | (uint8_t)(i * 4);
         panic_on(data != expected_value, "error");
    }

}

int main()
{
    flash_test();
}
