MEMORY {
    mrom : ORIGIN = _mrom_start, LENGTH = 4K,
    sram : ORIGIN = _sram_start, LENGTH = 8K
}

ENTRY(_start)
PHDRS { text PT_LOAD; data PT_LOAD; }

SECTIONS {
  . = ORIGIN(mrom);
  .text : {
    *(entry)
    *(.text*)
    *(.rodata*)
  } > mrom AT>mrom : text
  
  .data : {
    _sram_data_begin = .;
    *(.data*)
    *(.sdata*)
    _sram_data_end = .;
  } > sram AT>mrom : data

  _mrom_data_begin = LOADADDR(.data);
  
  .bss : {
	_bss_start = .;
    *(.bss*)
    *(.sbss*)
    *(.scommon)
  } >sram AT>sram

  _stack_top = ALIGN(0x1000);
  . = _stack_top + 0x800;
  _stack_pointer = .;
  end = .;
  _end = .;
  _heap_start = ALIGN(0x1000);
}
