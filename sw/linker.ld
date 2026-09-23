/* =============================================================================
 * File: linker.ld
 * Description: Linker script for Minimal RV32IMA Microcontroller
 *
 * Memory Map:
 *   FLASH (ROM) : ORIGIN = 0x0000_0000, LENGTH = 32K  (Boot ROM)
 *   RAM         : ORIGIN = 0x1000_0000, LENGTH = 32K  (SRAM)
 *
 * Section Layout:
 *   .text   -> FLASH : executable code (loaded & runs from ROM)
 *   .rodata -> FLASH : read-only constants
 *   .data   -> RAM   : initialized variables (image stored in ROM, copied at boot)
 *   .bss    -> RAM   : zero-initialized variables (zeroed by startup.S)
 *   STACK   -> Top of RAM (descending)
 * ============================================================================= */

OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY {
  FLASH (rx)  : ORIGIN = 0x00000000, LENGTH = 32K
  RAM   (rwx) : ORIGIN = 0x10000000, LENGTH = 32K
}

SECTIONS {
  /* -------------------------------------------------------------------------
   * .text : Code section (lives in Boot ROM, executed from address 0)
   * ------------------------------------------------------------------------- */
  .text : {
    KEEP(*(.text.start))   /* _start entry point must be first */
    *(.text .text.*)
    *(.rodata .rodata.*)
    . = ALIGN(4);
  } > FLASH

  /* LMA load address in FLASH for .data initialization image */
  _data_lma = LOADADDR(.data);

  /* -------------------------------------------------------------------------
   * .data : Initialized data (stored in FLASH, copied to RAM by startup.S)
   * ------------------------------------------------------------------------- */
  .data : {
    _data_start = .;
    PROVIDE(__global_pointer$ = . + 0x800);
    *(.data .data.*)
    . = ALIGN(4);
    _data_end = .;
  } > RAM AT > FLASH

  /* -------------------------------------------------------------------------
   * .bss : Zero-initialized data (zeroed by startup.S, lives in RAM)
   * ------------------------------------------------------------------------- */
  .bss : {
    _bss_start = .;
    *(.bss .bss.*)
    *(COMMON)
    . = ALIGN(4);
    _bss_end = .;
  } > RAM

  /* -------------------------------------------------------------------------
   * Stack: Top of RAM (grows downward)
   * ------------------------------------------------------------------------- */
  _stack_top = ORIGIN(RAM) + LENGTH(RAM);

  /* -------------------------------------------------------------------------
   * Discard debug sections for synthesis/simulation hex generation
   * ------------------------------------------------------------------------- */
  /DISCARD/ : {
    *(.comment)
    *(.note*)
    *(.eh_frame*)
  }
}
