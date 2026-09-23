/* =============================================================================
 * File: main.c
 * Description: Bare-metal application for Minimal RV32IMA MCU
 *
 * Demonstrates:
 *   - Memory-mapped UART output ("Hello RISC-V!\n")
 *   - Memory-mapped GPIO output (LED blink pattern 0xAA)
 *   - Polling-based UART transmit (busy-wait on TX_READY)
 *
 * Memory Map:
 *   UART BASE : 0x2000_0000
 *   GPIO BASE : 0x2000_1000
 * ============================================================================= */

#include <stdint.h>

/* ---------------------------------------------------------------------------
 * UART Register Map (Section 11)
 * --------------------------------------------------------------------------- */
#define UART_BASE       ((volatile uint32_t *)0x20000000U)
#define UART_TXDATA     (UART_BASE[0])   /* W: Transmit byte [7:0] */
#define UART_RXDATA     (UART_BASE[1])   /* R: Receive byte [7:0], clears RX_VALID */
#define UART_STATUS     (UART_BASE[2])   /* R: bit[0]=TX_READY, bit[1]=RX_VALID */
#define UART_BAUD       (UART_BASE[3])   /* R/W: clock divisor */

#define UART_TX_READY   (1U << 0)
#define UART_RX_VALID   (1U << 1)

/* ---------------------------------------------------------------------------
 * GPIO Register Map (Section 12)
 * --------------------------------------------------------------------------- */
#define GPIO_BASE       ((volatile uint32_t *)0x20001000U)
#define GPIO_DATA       (GPIO_BASE[0])   /* R/W: Pin data */
#define GPIO_DIR        (GPIO_BASE[1])   /* R/W: Direction (1=output, 0=input) */

/* ---------------------------------------------------------------------------
 * UART Transmit Functions
 * --------------------------------------------------------------------------- */

/**
 * uart_putc - Transmit a single character (blocking poll on TX_READY)
 */
static void uart_putc(char c) {
    while (!(UART_STATUS & UART_TX_READY)) {
        /* Busy-wait: poll TX_READY until the transmitter is free */
        __asm__ volatile("nop");
    }
    UART_TXDATA = (uint32_t)(unsigned char)c;
}

/**
 * uart_puts - Transmit a null-terminated string
 */
static void uart_puts(const char *s) {
    while (*s) {
        uart_putc(*s++);
    }
}

/**
 * uart_puthex - Print a 32-bit value as 8 hex digits
 */
static void uart_puthex(uint32_t val) {
    const char hex[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 7; i >= 0; i--) {
        uart_putc(hex[(val >> (i * 4)) & 0xFU]);
    }
}

/* ---------------------------------------------------------------------------
 * Spin-delay (rough cycle counter, not clock-accurate)
 * --------------------------------------------------------------------------- */
static void spin_delay(uint32_t count) {
    volatile uint32_t c = count;
    while (c--) {
        __asm__ volatile("nop");
    }
}

/* ---------------------------------------------------------------------------
 * Application Entry Point
 * --------------------------------------------------------------------------- */
int main(void) {

    /* -----------------------------------------------------------------------
     * 1. Configure GPIO: All 8 pins as outputs
     * ----------------------------------------------------------------------- */
    GPIO_DIR  = 0xFFU;   /* All pins output */
    GPIO_DATA = 0x00U;   /* Start with all low */

    /* -----------------------------------------------------------------------
     * 2. Print firmware banner
     * ----------------------------------------------------------------------- */
    uart_puts("Hello RISC-V!\r\n");
    uart_puts("Minimal RV32IMA MCU booted successfully.\r\n");
    uart_puts("UART @ 0x20000000 | GPIO @ 0x20001000\r\n");

    /* -----------------------------------------------------------------------
     * 3. Print UART STATUS register value (sanity check)
     * ----------------------------------------------------------------------- */
    uart_puts("UART STATUS = ");
    uart_puthex(UART_STATUS);
    uart_puts("\r\n");

    /* -----------------------------------------------------------------------
     * 4. GPIO LED Blink Loop
     *    Alternates 0xAA and 0x55 patterns on output pins
     * ----------------------------------------------------------------------- */
    uint32_t pattern = 0xAAU;
    while (1) {
        GPIO_DATA = pattern;
        spin_delay(100000U);

        /* Toggle between 0xAA and 0x55 */
        pattern = (pattern == 0xAAU) ? 0x55U : 0xAAU;
    }

    /* Should never reach here */
    return 0;
}
