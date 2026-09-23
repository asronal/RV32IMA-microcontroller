# System Memory Map

The microcontroller implements a 32-bit flat physical address space.

---

## 1. Physical Address Allocations

| Address Range | Region Size | Target Device | Bus Attributes |
| :--- | :--- | :--- | :--- |
| `0x0000_0000 - 0x0000_7FFF` | 32 KB | Boot ROM | Read-only, un-cached, zero-wait |
| `0x1000_0000 - 0x1000_7FFF` | 32 KB | SRAM (Data / Code) | Read/Write, zero-wait |
| `0x2000_0000 - 0x2000_0FFF` | 4 KB | UART Controller | Memory-mapped I/O |
| `0x2000_1000 - 0x2000_1FFF` | 4 KB | GPIO Controller | Memory-mapped I/O |
| `0x2000_2000 - 0x2000_2FFF` | 4 KB | Timer (Reserved) | Reserved placeholder |

---

## 2. Peripheral Register Maps

### UART (`0x2000_0000`)
| Offset | Name | Access | Description |
| :--- | :--- | :--- | :--- |
| `+0x00` | `TXDATA` | W | Transmit byte (bits [7:0]) |
| `+0x04` | `RXDATA` | R | Receive byte (bits [7:0]) |
| `+0x08` | `STATUS` | R | `STATUS[0]` = TX_READY, `STATUS[1]` = RX_VALID |
| `+0x0C` | `BAUD` | R/W | Clock divisor = `CLK_HZ / BAUD_RATE` |

### GPIO (`0x2000_1000`)
| Offset | Name | Access | Description |
| :--- | :--- | :--- | :--- |
| `+0x00` | `DATA` | R/W | GPIO pin states (bits [GPIO_WIDTH-1:0]) |
| `+0x04` | `DIR` | R/W | Output enable direction (1=Output, 0=Input) |
