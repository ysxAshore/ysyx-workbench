#include <klib.h>
#include <am.h>
#include <klib-macros.h>
#include <limits.h>
__attribute__((noinline))
void check(bool cond) {
  if (!cond) halt(1);
}
void test_sprintf(){
    int data[] = {
        0, 
        INT_MAX / 17, 
        INT_MAX, 
        INT_MIN, 
        INT_MIN + 1,
        UINT_MAX / 17, 
        INT_MAX / 17, 
        UINT_MAX
    };
    char ref[][30] = {
    	"0",
	"126322567",
	"2147483647",
	"-2147483648",
	"-2147483647",
	"252645135",
	"126322567",
	"-1",
    };
    char dut[64]={0};
    for (size_t i = 0; i < sizeof(data) / sizeof(data[0]); i++) {
			sprintf(dut,"%d",data[i]);
			check(strcmp(dut,ref[i])==0);	
    }
}
int main(){
    test_sprintf();
}
