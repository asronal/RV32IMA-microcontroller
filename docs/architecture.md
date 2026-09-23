# Microcontroller Architecture Specification

This document details the microarchitecture of the **Minimal RV32IMA 5-Stage Microcontroller**.

---

## 1. Top-Level Overview

The processor is a 32-bit single-issue, in-order microcontroller targeting ASIC synthesis using Synopsys Design Compiler and SAED PDK standard cells.

```
       +-----------------------------------------------------------+
       |                       rv32ima_mcu                         |
       |                                                           |
       |   +---------------+            +----------------------+   |
       |   |   rv32_core   | <=======>  |      bus_decoder     |   |
       |   +---------------+            +----------+-----------+   |
       |                                           |               |
       |               +---------------------------+               |
       |               |             |             |               |
       |               v             v             v               |
       |          +---------+   +---------+   +---------+          |
       |          | BootROM |   |  SRAM   |   | Periphs |          |
       |          | (32 KB) |   | (32 KB) |   |UART/GPIO|          |
       |          +---------+   +---------+   +---------+          |
       +-----------------------------------------------------------+
```

---

## 2. Core Architecture (`rv32_core.sv`)

The core is structured around a classic 5-stage pipeline with full data forwarding, hardware stall logic, and atomic execution.

```
  +--------+     +-------+     +--------+     +-------+     +--------+     +--------+     +--------+     +--------+     +--------+
  | PC Reg | --> |  IF   | --> | IF/ID  | --> |  ID   | --> | ID/EX  | --> |   EX   | --> | EX/MEM | --> |  MEM   | --> | MEM/WB | --> WB
  | pc_reg |     | Fetch |     | if_id  |     |Decode |     | id_ex  |     |Execute |     | ex_mem |     | Memory |     | mem_wb |
  +--------+     +-------+     +-------+     +--------+     +-------+     +--------+     +--------+     +--------+     +--------+
```

---

## 3. Centralized Bus Decoder (`bus_decoder.sv`)

All address decoding is centralized in `bus_decoder.sv`:
- `0x0000_0000 - 0x0000_7FFF`: Boot ROM (32 KB)
- `0x1000_0000 - 0x1000_7FFF`: SRAM (32 KB)
- `0x2000_0000 - 0x2000_0FFF`: UART (4 KB)
- `0x2000_1000 - 0x2000_1FFF`: GPIO (4 KB)
- `0x2000_2000 - 0x2000_2FFF`: Reserved Timer Placeholder

---

## 4. Memory Macro Abstraction Layer (`memory_wrapper.sv`)

Per Section 8 of the Master Specification:
- Generic synthesizable RAM (`ram.sv`) is used during RTL simulation.
- When compiling for ASIC synthesis with SAED PDK, define `USE_SAED_MEMORY`.
- `saed_sram_wrapper.sv` isolates the ASIC SRAM macro pins, ensuring the CPU core and bus stay completely vendor-neutral.
