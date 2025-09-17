#if __riscv_xlen == 32
#define LOAD  lw
#define STORE sw
#define XLEN  4
#else
#define LOAD  ld
#define STORE sd
#define XLEN  8
#endif

.section entry, "ax"
.globl _start
.type _start, @function

_start:
  mv s0, zero
  la sp, _stack_pointer

  # bootloader: load mrom data to sram
  la a0, _sram_data_begin
  la a1, _sram_data_end
  la a2, _mrom_data_begin

copy:
  LOAD s0, 0(a2)
  STORE s0, 0(a0)
  addi a0, a0, XLEN
  addi a2, a2, XLEN

  blt a0, a1, copy

  jal _trm_init