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
.globl _fsbl
.type _fsbl, @function

_fsbl:
  mv s0, zero
  la sp, _stack_pointer

  # first stage bootloader: load ssbl program from flash to sram
  la t0, _sram_copy_begin
  la t1, _sram_copy_end
  la t2, _ssbl_program_begin

copy2sram:
  LOAD s0, 0(t2)
  STORE s0, 0(t0)
  addi t0, t0, XLEN
  addi t2, t2, XLEN

  blt t0, t1, copy2sram

  la t0, _ssbl
  jr t0

.section ssbl, "ax"
.globl _ssbl
.type _ssbl, @function

_ssbl:
  # second stage bootloader: load user program and data from flash to psram
  la t0, _sdram_copy_begin
  la t1, _sdram_copy_end
  la t2, _user_program_begin

copy2psram:
  LOAD s0, 0(t2)
  STORE s0, 0(t0)
  addi t0, t0, XLEN
  addi t2, t2, XLEN

  blt t0, t1, copy2psram

  la t0, _trm_init
  jr t0
