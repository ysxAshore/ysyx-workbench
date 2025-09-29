MEMORY {
    flash (rx)  : ORIGIN = 0x30000000, LENGTH = 16M
    sram  (rwx) : ORIGIN = 0x0f000000, LENGTH = 8K
}

ENTRY(_start)

PHDRS {
  text PT_LOAD FLAGS(0x5); /* R+X */
  data PT_LOAD FLAGS(0x6); /* R+W */
}

SECTIONS {
  . = ORIGIN(flash);

  .text : ALIGN(0x4) {
    *(entry)
    *(.text*)
    *(.rodata*)
  } > flash :text   /* 运行在 flash, LMA 也在 flash */
  
  /* 这里要进行对齐 不然_flash_data_begin可能会是不对齐的 导致 copy时得到错误地址 */
  /* 比如string.c中 _flash_data_begin=300000dd 得到的是000d7c00 就少读了一字节 导致访存错误*/
  .data : ALIGN(0x4){
    _sram_data_begin = .;
    *(.data*)
    *(.sdata*)
    _sram_data_end = .;
  } > sram AT> flash :data  /* VMA 在 SRAM, LMA 在 flash */

  _flash_data_begin = LOADADDR(.data);

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
  .bss(NOLOAD) : ALIGN(0x4) {
    _bss_start = .;
    *(.bss*)
    *(.sbss*)
    *(.scommon)
    _bss_end = .;
  } > sram

  _stack_top = ALIGN(0x4);
  . = _stack_top + 0x1000;
  _stack_pointer = .;
  end = .;
  _end = .;
  _heap_start = ALIGN(0x4);
}
