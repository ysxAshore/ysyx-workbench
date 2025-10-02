#include <amtest.h>

/* PSRAM test */
void psram_test()
{
    uintptr_t psram_addr = 0x80000000;
    uint32_t test_size = 10000;
	// 写测试
    uint8_t *byte_ptr = (uint8_t *)psram_addr;
    //putstr("=== Byte Write ===\n");
	//for(int i = 0; i < test_size; ++i){
	//	byte_ptr[i] = i;
	//}
    uint16_t *half_ptr = (uint16_t *)psram_addr;
    putstr("=== Half Write ===\n");
	for(int i = 0; i < test_size/2; ++i){
		half_ptr[i] = ((uint8_t)(i * 2 + 1) << 8) | (uint8_t)(i * 2);
	}

    // 读测试阶段
    byte_ptr = (uint8_t *)psram_addr;
    half_ptr = (uint16_t *)psram_addr;
    uint32_t *word_ptr = (uint32_t *)psram_addr;

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
int main(){
	psram_test();
}
