#include <amtest.h>

/* Fast_Flash test
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

}*/

#define SPI_BASE 0x10001000
#define SPI_REG_TX (SPI_BASE + 0x0)
#define SPI_REG_RX (SPI_BASE + 0x0)
#define SPI_REG_CTRL (SPI_BASE + 0x10)
#define SPI_REG_DIV (SPI_BASE + 0x14)
#define SPI_REG_SS (SPI_BASE + 0x18)

uint32_t flash_read(uint32_t addr)
{
    // 1. 设置传输给Flash的命令
    // 8位命令03h表示从flash颗粒中读出数据, 命令后紧跟24位的存储单元地址
    // 读地址4B对齐
    *(volatile uint64_t *)SPI_REG_TX = (uint64_t)0x03 << 56 | (uint64_t)(addr & 0xfffffc) << 32;

    // 2. 设置 SCK 分频（尽可能快）
    *(volatile uint32_t *)SPI_REG_DIV = 1;

    // 3. 设置 slave 号为 0
    *(volatile uint32_t *)SPI_REG_SS = 1;

    // 4. 设置CTRL
    // CHAR_LEN = 40 (32bits data 32bits (cmd+addr)
    // GO_BSY = 1
    // Rx_NEG:0 上升沿锁存miso
    // Tx_NEG:0 上升沿发送mosi
    // LSB=0
    // IE=0
    // ASS=1
    *(volatile uint32_t *)SPI_REG_CTRL = 0x40 | 0x1 << 8 | 0x4 << 11;

    // 5. 检测GO_BSY是否为0
    while (*(volatile uint32_t *)SPI_REG_CTRL & 0x1 << 8)
        ;

    // 6. 读出数据Rx
    uint32_t rx_data = *(volatile uint64_t *)SPI_REG_RX;

    return rx_data;
}

/* flash_read function test
void flash_test()
{
    uintptr_t read_addr = 0x30000000;
    uint32_t test_size = 10000;

    putstr("=== Byte Read ===\n");
    uintptr_t fetch_addr = read_addr;
    for (int i = 0; i < test_size; i++)
    {
        uint32_t data = flash_read(fetch_addr);
        uint8_t this_data = (fetch_addr & 0x3) == 0x0 ? data : (fetch_addr & 0x3) == 0x1 ? data >> 8
                                                           : (fetch_addr & 0x3) == 0x2   ? data >> 16
                                                                                         : data >> 24;
        panic_on(this_data != (uint8_t)i, "error");
        ++fetch_addr;
    }

    putstr("=== Half Read ===\n");
    fetch_addr = read_addr;
    for (int i = 0; i < test_size / 2; i++)
    {
        uint32_t data = flash_read(fetch_addr);
        uint16_t this_data = (fetch_addr & 0x3) == 0x0 ? data : data >> 16;
        uint16_t expected_value = ((uint8_t)(i * 2 + 1) << 8) | (uint8_t)(i * 2);
        panic_on(this_data != expected_value, "error");
        fetch_addr += 0x2;
    }

    putstr("=== Word Read ===\n");
    fetch_addr = read_addr;
    for (int i = 0; i < test_size / 4; i++)
    {
        uint32_t data = flash_read(fetch_addr);
        uint32_t expected_value = ((uint8_t)(i * 4 + 3) << 24) | ((uint8_t)(i * 4 + 2) << 16) | ((uint8_t)(i * 4 + 1) << 8) | (uint8_t)(i * 4);
        panic_on(data != expected_value, "error");
        fetch_addr += 0x4;
    }
}
*/

/* 从flash中加载程序并执行 通过flash_read软件函数
void (*entry)(void);
void flash_test()
{
    uintptr_t read_addr = 0x30000000;
    uint32_t size = flash_read(read_addr);
    uint8_t func[size];
    read_addr += 0x4;
    for (int i = 0; i < size; ++i)
    {

        uint32_t data = flash_read(read_addr);
        uint8_t this_data = (read_addr & 0x3) == 0x0 ? data : (read_addr & 0x3) == 0x1 ? data >> 8
                                                          : (read_addr & 0x3) == 0x2   ? data >> 16
                                                                                       : data >> 24;
        func[i] = this_data;
        ++read_addr;
    }
    entry = (void (*)(void))func;
    entry();
}
*/

/* 从flash中加载程序并执行 通过硬件直接读取
void flash_test()
{
    uintptr_t read_addr = 0x30000000;
    uint32_t size = *(uint32_t *)read_addr;
    uint8_t func[size];
    read_addr += 0x4;
    for (int i = 0; i < size; ++i)
    {

        uint32_t data = *(uint32_t *)read_addr;
        uint8_t this_data = (read_addr & 0x3) == 0x0 ? data : (read_addr & 0x3) == 0x1 ? data >> 8
                                                          : (read_addr & 0x3) == 0x2   ? data >> 16
                                                                                       : data >> 24;
        func[i] = this_data;
        ++read_addr;
    }
    void (*entry)(void);
    entry = (void (*)(void))func;
    entry();
}
*/

/* XIP方式跳转到flash 执行程序*/
void flash_test(){
    uintptr_t flash_addr = 0x30000000;
    void (*entry)(void);
    entry = (void (*)(void))flash_addr;
    entry();
}
