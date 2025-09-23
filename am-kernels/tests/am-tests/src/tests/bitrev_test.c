#include <amtest.h>
#define SPI_BASE 0x10001000
#define SPI_REG_TX (SPI_BASE + 0x0)
#define SPI_REG_RX (SPI_BASE + 0x0)
#define SPI_REG_CTRL (SPI_BASE + 0x10)
#define SPI_REG_DIV (SPI_BASE + 0x14)
#define SPI_REG_SS (SPI_BASE + 0x18)

int main(const char *args) {
	int32_t a = 0x57;
	
	// 1. 设置TX发送数据
	*(volatile uint32_t *)SPI_REG_TX = a;
	
	// 2. 设置 SCK 分频（尽可能快）不过仿真没关系
    *(volatile uint32_t *)SPI_REG_DIV = 1;

	// 3. 设置 slave 号为 7
	*(volatile uint32_t *)SPI_REG_SS = 1 << 7;
	
	// 4. 设置CTRL 
	// CHAR_LEN = 10
	// GO_BSY = 1
	// Rx_NEG:0 上升沿锁存miso
	// Tx_NEG:0 上升沿发送mosi
	// LSB=1
	// IE=0
	// ASS=1
	*(volatile uint32_t *)SPI_REG_CTRL = 0x10 | 0x1 << 8 | 0x5 << 11;

	// 5. 检测GO_BSY是否为0
	while(*(volatile uint32_t *)SPI_REG_CTRL & 0x1 << 8);

	// 6. 读出数据Rx
	uint16_t rx_data = *(volatile uint32_t *)SPI_REG_RX;

    panic_on(0xea != (rx_data >> 8), "error");

	return 0;
}
