#include <klib.h>
#include <am.h>
#include <klib-macros.h>
#include<stdint.h>
#define N 32

void reset(uint8_t *data);
void check_seq(uint8_t *data,int l, int r, int val) ;
void check_eq(uint8_t *data,int l, int r, int val) ;
