MEMORY {
    flash (rx)  : ORIGIN = _flash_start, LENGTH = 16M
    sdram (rwx) : ORIGIN = _sdram_start, LENGTH = 64M
    psram (rwx) : ORIGIN = _psram_start, LENGTH = 4M
    sram  (rwx) : ORIGIN = _sram_start,  LENGTH = 8K
}

ENTRY(_fsbl)

PHDRS {
  fsbl PT_LOAD FLAGS(0x5); /* R+X */
  ssbl PT_LOAD FLAGS(0x5); /* R+X */
  user_program PT_LOAD FLAGS(0x6); /* R+X+W */
}

SECTIONS {

  .fsbl : {
    *(entry)
  } > flash :fsbl /* 运行在 flash, LMA 也在 flash */

  .ssbl : ALIGN(0x8){
    _sram_copy_begin = .;
    *(ssbl)
    _sram_copy_end = .;
  } > sram AT> flash :ssbl /* 运行在sram LMA在flash*/

  _ssbl_program_begin = LOADADDR(.ssbl);

  .user_program : ALIGN(0x8) {
    _sdram_copy_begin = .;
    *(entry)
    *(.text*)
    *(.rodata*)
    *(.data*)
    *(.sdata*)

    /* bsp 中的 extra.ld */
    /* section information for finsh shell */
    __fsymtab_start = .;
    KEEP(*(FSymTab))
    __fsymtab_end = .;
    . = ALIGN(8);
    __vsymtab_start = .;
    KEEP(*(VSymTab))
    __vsymtab_end = .;
    . = ALIGN(8);

    /* section information for initial. */
    . = ALIGN(8);
    __rt_init_start = .;
    KEEP(*(SORT(.rti_fn*)))
    __rt_init_end = .;
    . = ALIGN(8);

    __rt_utest_tc_tab_start = .;
    KEEP(*(UtestTcTab))
    __rt_utest_tc_tab_end = .;

    . = ALIGN(8);
    __am_apps_data_start = .;
    *(__am_apps.data*)
    *(__am_apps.sdata*)
    __am_apps_data_end = .;
    . = ALIGN(8);
    _sdram_copy_end = .;
  } >sdram AT> flash :user_program /* 运行在sdram LMA在flash */

  /* 这里要进行对齐 不然_flash_data_begin可能会是不对齐的 导致 copy时得到错误地址 */
  /* 比如string.c中 _flash_data_begin=300000dd 得到的是000d7c00 就少读了一字节 导致访存错误*/
  /*在 RV32 上，即使寄存器是 32 位，链接脚本也必须保证 8B 对齐，否则涉及 uint64_t / double 的程序一定会崩。*/

  _user_program_begin = LOADADDR(.user_program);

  /*这里不能给.bss指定LMA 但 .bss 本来就是 未初始化段，它在 LMA 是不需要占空间的，只需要运行时清零（VMA 有空间就行）
    如果给了会导致bin很大
    对于 有内容的段（比如 .text、.data）：
    LMA = VMA（默认情况下，文件里有数据，加载的时候就需要把这些字节搬到内存）。

    对于 NOBITS 段（比如 .bss）：
    它在 ELF 文件里本来就没有存储内容，所以根本没有 LMA 这个概念。
    链接器即使你不写 AT，也不会给 .bss 分配 LMA，而是让它“只存在于运行时内存中”。
    启动代码（crt0.S 里）负责根据 _bss_start ~ _bss_end 把这块清零。
  */
  /*这里还需要设置.bss(NOLOAD) 不然会报错section '.bss' can't be allocated in segment 1*/
  .bss(NOLOAD) : ALIGN(0x8) {
    _bss_start = .;
    *(.bss*)
    *(.sbss*)
    *(.scommon)
    _bss_end = .;
  } > sdram

  _stack_top = ALIGN(0x8);
  . = _stack_top + 0x10000;
  _stack_pointer = .;
  end = .;
  _end = .;
  _heap_start = ALIGN(0x8);
}
