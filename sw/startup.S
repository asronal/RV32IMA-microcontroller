/* =============================================================================
 * File: startup.S
 * Description: RISC-V RV32IMA bare-metal startup entry point
 *
 * Responsibilities:
 *   1. Set machine-mode trap vector (mtvec) to a minimal trap handler
 *   2. Initialize stack pointer to top of RAM
 *   3. Copy .data section image from ROM to RAM
 *   4. Zero-initialize .bss section
 *   5. Call main()
 *   6. Infinite loop on main() return (should never happen)
 *
 * ABI: RISC-V unprivileged calling convention (ra, sp, gp, tp, a0-a7, etc.)
 * Standard: RV32IMA Machine Mode Only
 * ============================================================================= */

    .section .text.start
    .global  _start
    .type    _start, @function

_start:
    /* -----------------------------------------------------------------------
     * Step 1: Disable all interrupts and set trap vector to trap_handler
     * ----------------------------------------------------------------------- */
    csrw    mie, zero                   /* Disable all machine-mode interrupts */
    la      t0, trap_handler
    csrw    mtvec, t0                   /* Set machine trap vector */

    /* -----------------------------------------------------------------------
     * Step 2: Initialize stack pointer to top of RAM
     * ----------------------------------------------------------------------- */
    la      sp, _stack_top

    /* -----------------------------------------------------------------------
     * Step 3: Initialize global pointer (gp) for linker relaxation
     * ----------------------------------------------------------------------- */
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop

    /* -----------------------------------------------------------------------
     * Step 4: Copy .data section from ROM load address to RAM
     *         Source: _data_lma  (Load Memory Address in Flash)
     *         Dest:   _data_start .. _data_end (Virtual Memory Address in RAM)
     * ----------------------------------------------------------------------- */
    la      a0, _data_lma              /* Source: .data image in ROM */
    la      a1, _data_start            /* Destination start in RAM */
    la      a2, _data_end              /* Destination end in RAM */
    beq     a1, a2, .Lcopy_done       /* Skip if .data is empty */
.Lcopy_loop:
    lw      t0, 0(a0)
    sw      t0, 0(a1)
    addi    a0, a0, 4
    addi    a1, a1, 4
    blt     a1, a2, .Lcopy_loop
.Lcopy_done:

    /* -----------------------------------------------------------------------
     * Step 5: Zero-initialize .bss section
     *         Region: _bss_start .. _bss_end
     * ----------------------------------------------------------------------- */
    la      a0, _bss_start
    la      a1, _bss_end
    beq     a0, a1, .Lbss_done
.Lbss_loop:
    sw      zero, 0(a0)
    addi    a0, a0, 4
    blt     a0, a1, .Lbss_loop
.Lbss_done:

    /* -----------------------------------------------------------------------
     * Step 6: Call main() with no arguments (argc=0, argv=NULL)
     * ----------------------------------------------------------------------- */
    li      a0, 0
    li      a1, 0
    call    main

    /* -----------------------------------------------------------------------
     * Step 7: main() returned — spin forever (should never happen)
     * ----------------------------------------------------------------------- */
.Lhalt:
    wfi
    j       .Lhalt


/* =============================================================================
 * Minimal Machine-Mode Trap Handler
 * Reads mcause, records in a0, then spins (no OS to report to)
 * ============================================================================= */
    .section .text
    .global  trap_handler
    .align   4
trap_handler:
    csrr    a0, mcause                 /* Read trap cause */
    csrr    a1, mepc                   /* Read faulting PC */
    /* Infinite fault spin — in a real system this would report to a debugger */
.Ltrap_spin:
    wfi
    j       .Ltrap_spin
