# System Memory Map & Peripheral Register Specification

<div align="center">

**[← Back to README](../README.md)** • **[Architecture](architecture.md)** • **[ISA Reference](isa.md)** • **[Verification](verification.md)** • **[SAED Integration](saed_integration.md)**

</div>

---

## 1. Physical Address Space Allocation

The **Minimal RV32IMA Microcontroller** implements a 32-bit flat, un-paged physical address map. All memory regions and peripheral control registers are mapped into a single unified space.

```
  +-----------------------+ 0xFFFF_FFFF
  |                       |
  |       Unmapped        | (Decodes to 0x0 / Bus fault)
  |                       |
  +-----------------------+ 0x2000_3000
  |   Reserved (Timer)    | 0x2000_2000 (4 KB)
  +-----------------------+ 0x2000_2000
  |    GPIO Controller    | 0x2000_1000 (4 KB)
  +-----------------------+ 0x2000_1000
  |    UART Controller    | 0x2000_0000 (4 KB)
  +-----------------------+ 0x2000_0000
  |       Unmapped        |
  +-----------------------+ 0x1000_8000
  |      System SRAM      | 0x1000_0000 (32 KB, Data / Code)
  +-----------------------+ 0x1000_0000
  |       Unmapped        |
  +-----------------------+ 0x0000_8000
  |       Boot ROM        | 0x0000_0000 (32 KB, Reset Vector)
  +-----------------------+ 0x0000_0000
```

### 1.1 Memory Region Properties

| Address Range | Size | Region Name | Access | Wait States | Description |
| :--- | :---: | :--- | :---: | :---: | :--- |
| `0x0000_0000 – 0x0000_7FFF` | 32 KB | **Boot ROM** | R / X | 0 | Non-volatile code storage containing reset vector and startup routines. |
| `0x1000_0000 – 0x1000_7FFF` | 32 KB | **SRAM** | R / W / X | 0 | Synchronous single-cycle read/write memory for stack, heap, and BSS. |
| `0x2000_0000 – 0x2000_0FFF` | 4 KB | **UART** | R / W | 0 | Memory-mapped 8N1 serial communication interface. |
| `0x2000_1000 – 0x2000_1FFF` | 4 KB | **GPIO** | R / W | 0 | Memory-mapped 8-bit bidirectional general-purpose I/O port. |
| `0x2000_2000 – 0x2000_2FFF` | 4 KB | **Timer** | R / W | 0 | *Reserved address space for future timer/counter peripheral.* |

---

## 2. Peripheral Register Definitions

### 2.1 UART Controller (`0x2000_0000`)
The UART provides asynchronous 8N1 serial transmission and reception with configurable baud rate division.

| Offset | Name | Type | Reset Value | Description |
| :--- | :--- | :---: | :---: | :--- |
| `+0x00` | `UART_TXDATA` | W | `0x0000_0000` | Transmit Data Register (`[7:0]` data byte to transmit) |
| `+0x04` | `UART_RXDATA` | R | `0x0000_0000` | Receive Data Register (`[7:0]` received data byte; reading clears `RX_VALID`) |
| `+0x08` | `UART_STATUS` | R | `0x0000_0001` | Controller Status Register (Bit 0: `TX_READY`, Bit 1: `RX_VALID`) |
| `+0x0C` | `UART_BAUD` | R/W | `CLK_HZ/115200`| Clock Divisor Register ($\text{Divisor} = \frac{f_{\text{CLK}}}{\text{Baud Rate}}$) |

#### UART_STATUS Register Bitfields:
```
  31                                              2     1          0
 +-----------------------------------------------+-----+----------+----------+
 |                   Reserved (0)                | ... | RX_VALID | TX_READY |
 +-----------------------------------------------+-----+----------+----------+
```
- **`Bit 0 (TX_READY)`**: `1` = Transmitter is idle and ready to accept the next byte. `0` = Transmit in progress.
- **`Bit 1 (RX_VALID)`**: `1` = Unread byte available in `UART_RXDATA`. `0` = No new data available.

#### Baud Rate Calculation Example:
$$\text{Divisor} = \frac{50\,000\,000\text{ Hz}}{115\,200\text{ Baud}} \approx 434\text{ (0x01B2)}$$

---

### 2.2 GPIO Controller (`0x2000_1000`)
The GPIO controller provides 8 bidirectional pins with independent input sampling and output-drive control.

| Offset | Name | Type | Reset Value | Description |
| :--- | :--- | :---: | :---: | :--- |
| `+0x00` | `GPIO_DATA` | R/W | `0x0000_0000` | Pin State Register (`[7:0]` driven output values or sampled input values) |
| `+0x04` | `GPIO_DIR` | R/W | `0x0000_0000` | Direction / Output Enable Register (`1` = Output mode, `0` = Input mode) |

#### GPIO_DIR Register Bitfields:
```
  31                                              8  7                    0
 +-------------------------------------------------+-----------------------+
 |                   Reserved (0)                  |   DIR_MASK [7:0]      |
 +-------------------------------------------------+-----------------------+
```
- Setting bit `i` to `1` asserts `gpio_oe[i] = 1`, driving `gpio_out[i]` onto the pin.
- Setting bit `i` to `0` sets `gpio_oe[i] = 0` (high-impedance / input mode), allowing external input to be sampled.

---

## 3. Bus Access Rules & Byte Strobes

The bus decoder decomposes store instructions into memory write strobes (`wstrb[3:0]`):

| Instruction | Target Address Offset | Active `wstrb[3:0]` | Write Data Alignment |
| :--- | :--- | :---: | :--- |
| `SB` (Byte Store) | `addr[1:0] == 2'b00` | `4'b0001` | `wdata[7:0]` |
| `SB` (Byte Store) | `addr[1:0] == 2'b01` | `4'b0010` | `wdata[15:8]` |
| `SB` (Byte Store) | `addr[1:0] == 2'b10` | `4'b0100` | `wdata[23:16]` |
| `SB` (Byte Store) | `addr[1:0] == 2'b11` | `4'b1000` | `wdata[31:24]` |
| `SH` (Halfword Store) | `addr[1:0] == 2'b00` | `4'b0011` | `wdata[15:0]` |
| `SH` (Halfword Store) | `addr[1:0] == 2'b10` | `4'b1100` | `wdata[31:16]` |
| `SW` (Word Store) | `addr[1:0] == 2'b00` | `4'b1111` | `wdata[31:0]` |

---

## 4. Bare-Metal C Header (`soc_regs.h`)

This C header file provides convenient macros and pointer bindings for embedded firmware:

```c
#ifndef SOC_REGS_H
#define SOC_REGS_H

#include <stdint.h>

// Base Addresses
#define ROM_BASE        0x00000000UL
#define RAM_BASE        0x10000000UL
#define UART_BASE       0x20000000UL
#define GPIO_BASE       0x20001000UL

// UART Peripheral Struct
typedef struct {
    volatile uint32_t TXDATA;   // +0x00: Transmit data register
    volatile uint32_t RXDATA;   // +0x04: Receive data register
    volatile uint32_t STATUS;   // +0x08: Status (bit 0: TX_READY, bit 1: RX_VALID)
    volatile uint32_t BAUD;     // +0x0C: Baud rate clock divisor
} uart_t;

// GPIO Peripheral Struct
typedef struct {
    volatile uint32_t DATA;     // +0x00: Pin data register
    volatile uint32_t DIR;      // +0x04: Direction mask (1 = Out, 0 = In)
} gpio_t;

#define UART    ((uart_t *) UART_BASE)
#define GPIO    ((gpio_t *) GPIO_BASE)

// Status Bitmasks
#define UART_STATUS_TX_READY    (1U << 0)
#define UART_STATUS_RX_VALID    (1U << 1)

// Helper Inline Functions
static inline void uart_putc(char c) {
    while (!(UART->STATUS & UART_STATUS_TX_READY));
    UART->TXDATA = (uint32_t)(uint8_t)c;
}

static inline void uart_puts(const char *str) {
    while (*str) {
        uart_putc(*str++);
    }
}

static inline void gpio_set_dir(uint8_t dir_mask) {
    GPIO->DIR = dir_mask;
}

static inline void gpio_write(uint8_t value) {
    GPIO->DATA = value;
}

static inline uint8_t gpio_read(void) {
    return (uint8_t)(GPIO->DATA & 0xFF);
}

#endif // SOC_REGS_H
```
