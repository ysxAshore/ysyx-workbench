#include <amtest.h>

#define GPIO_BASE 0x10002000
#define GPIO_LED 0x0
#define GPIO_SW 0x4
#define GPIO_SEG 0x8

void gpio_test(){
	int wait_time = 1;
	
	uint16_t passwd_c = 0x0420;
	//从开关验证密码是否正确
	while(*(volatile uint16_t *)(GPIO_BASE + GPIO_SW) != passwd_c) ;
	
	*(volatile uint32_t *)(GPIO_BASE + GPIO_SEG) = 0x20020308;
	
	uint16_t led_data = 0x1;
	while(1){
		uint64_t now = io_read(AM_TIMER_UPTIME).us;
		*(volatile uint16_t *)(GPIO_BASE + GPIO_LED) = led_data;
		while((io_read(AM_TIMER_UPTIME).us - now) < wait_time) ;
		led_data = led_data << 1 == 0 ? 0x1 : led_data << 1;
		wait_time += 1;
	}
}
