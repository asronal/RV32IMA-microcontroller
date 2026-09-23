# Minimal RV32IMA Microcontroller

A complete, synthesizable **RV32IMA 5-Stage RISC-V Microcontroller** implemented in IEEE 1800-2017 SystemVerilog, targeting **Synopsys Design Compiler** with the **SAED PDK**.

---

## Architecture

```
       +-----------------------------------------------------------+
       |                     rv32ima_mcu.sv                        |
       |                                                           |
       |   +---------------+    +------------------------------+   |
       |   |   rv32_core   | -> |        bus_decoder           |   |
       |   | (5-stage pipe)|    +--+----------+-------+--------+   |
       |   +---------------+       |          |       |            |
       |                           v          v       v            |
       |                    +-----------+ +------+ +------+        |
       |                    |  memory   | | uart | | gpio |        |
       |                    |  wrapper  | |      | |      |        |
       |                    | ROM + RAM | | 8N1  | | 8pin |        |
       |                    +-----------+ +------+ +------+        |
       +-----------------------------------------------------------+
```

### ISA
- **RV32I**: Full base integer instruction set
- **RV32M**: Integer multiply and divide (M-extension)
- **RV32A**: Atomic memory operations — LR/SC, AMOADD, AMOSWAP, AMOXOR, AMOAND, AMOOR, AMOMIN, AMOMAX, AMOMINU, AMOMAXU

### Microarchitecture
- **5-Stage pipeline**: IF → ID → EX → MEM → WB
- **Full data forwarding**: EX/MEM and MEM/WB bypass paths
- **Hardware hazard detection**: Load-use stalls, branch flush
- **Branches resolved in EX stage** (2-cycle branch penalty)
- **Machine mode only** — no MMU, FPU, vector, or compressed extensions

---

## Memory Map

| Base Address | End Address | Region | Size |
| :--- | :--- | :--- | :--- |
| `0x0000_0000` | `0x0000_7FFF` | Boot ROM | 32 KB |
| `0x1000_0000` | `0x1000_7FFF` | SRAM | 32 KB |
| `0x2000_0000` | `0x2000_0FFF` | UART | 4 KB |
| `0x2000_1000` | `0x2000_1FFF` | GPIO | 4 KB |

---

## Project Structure

```
minimal_mcu/
├── rtl/
│   ├── core/            # ALU, regfile, decoder, hazard/forwarding units
│   ├── pipeline/        # IF/ID, ID/EX, EX/MEM, MEM/WB stage registers
│   ├── bus/             # Central bus address decoder & MMIO mux
│   ├── memory/          # ROM, behavioral SRAM, SAED macro wrapper
│   ├── peripherals/     # 8N1 UART, bidirectional 8-bit GPIO
│   └── rv32ima_mcu.sv   # SoC top-level
│
├── tb/                  # Self-checking testbenches (15 files)
│   ├── tb_alu.sv
│   ├── tb_regfile.sv
│   ├── tb_decoder.sv
│   ├── tb_immediate_gen.sv
│   ├── tb_pipeline_regs.sv
│   ├── tb_branch_unit.sv
│   ├── tb_forwarding_unit.sv
│   ├── tb_hazard_unit.sv
│   ├── tb_core.sv
│   ├── tb_atomic_unit.sv
│   ├── tb_memory.sv
│   ├── tb_uart.sv
│   ├── tb_gpio.sv
│   ├── tb_mcu.sv         # Full SoC integration test
│   └── tb_mcu_visual.sv  # Instrumented visual sim (generates VCD + TSV)
│
├── sw/                  # Bare-metal firmware source
│   ├── startup.S         # RISC-V reset vector & trap handler
│   ├── main.c            # Application (UART hello, GPIO demo)
│   ├── linker.ld         # Memory layout linker script
│   └── Makefile          # Cross-compiler build system
│
├── sim/                 # Simulation directory (generated files, gitignored)
│   └── filelist.f        # VCS / Icarus Verilog source filelist
│
├── syn/                 # Synopsys DC synthesis
│   ├── dc.tcl            # Synthesis script (SAED PDK)
│   └── constraints.sdc  # Clock & timing constraints (50 MHz)
│
├── visualizer/          # Interactive web-based chip simulator
│   └── index.html        # Self-contained dashboard (open in browser)
│
├── docs/                # Reference documentation
│   ├── architecture.md
│   ├── isa.md
│   ├── memory_map.md
│   ├── verification.md
│   └── saed_integration.md
│
├── run_tests.py         # Automated regression runner (Icarus Verilog)
└── README.md
```

---

## Getting Started

### Prerequisites
- **Icarus Verilog** (`iverilog`) ≥ v11
- **RISC-V GCC toolchain** — e.g. `riscv64-unknown-elf-gcc` with `-march=rv32ima -mabi=ilp32` support
- **GTKWave** (optional, for waveform viewing)
- **Synopsys VCS** (optional, for formal verification)
- **Synopsys Design Compiler** + SAED PDK (for synthesis)

### 1. Build Firmware
```bash
cd sw/
make          # → build/firmware.hex (ROM preload image)
make disasm   # → build/firmware.lst (annotated disassembly)
```

### 2. Run All Testbenches (Icarus Verilog)
```bash
python3 run_tests.py
```
Runs all 14 unit + integration testbenches and prints a JSON pass/fail report.
On success: **14/14 testbenches pass, 185 checks pass, 0 failures**.

Also regenerates `visualizer/data.js` from the SoC simulation trace.

### 3. View Interactive Chip Simulator
```bash
python3 -m http.server 8080 --directory visualizer/
# → open http://localhost:8080 in your browser
```
Or open `visualizer/index.html` directly in any modern browser.

### 4. Inspect Waveforms in GTKWave
```bash
gtkwave sim/mcu_waves.vcd
```
> `sim/mcu_waves.vcd` is generated by `tb_mcu_visual.sv` during `run_tests.py`.

### 5. Run Synthesis
```bash
cd syn/
# Edit SAED_DB path in dc.tcl to match your PDK installation
dc_shell -f dc.tcl | tee dc_run.log
```

---

## Verification Coverage

| Phase | Module | Testbench | Checks |
| :--- | :--- | :--- | :--- |
| 1 | `alu.sv` | `tb_alu.sv` | 24 |
| 1 | `regfile.sv` | `tb_regfile.sv` | 4 |
| 1 | `immediate_gen.sv` | `tb_immediate_gen.sv` | 10 |
| 1 | `decoder.sv` | `tb_decoder.sv` | 48 |
| 2 | Pipeline registers + PC | `tb_pipeline_regs.sv` | 17 |
| 3 | `branch_unit.sv` | `tb_branch_unit.sv` | 17 |
| 4 | `forwarding_unit.sv` | `tb_forwarding_unit.sv` | 8 |
| 4 | `hazard_unit.sv` | `tb_hazard_unit.sv` | 7 |
| 5 | `rv32_core.sv` | `tb_core.sv` | 14 |
| 6 | `atomic_unit.sv` | `tb_atomic_unit.sv` | 15 |
| 7 | `bus_decoder + memory_wrapper` | `tb_memory.sv` | 6 |
| 8 | `uart.sv` | `tb_uart.sv` | 7 |
| 9 | `gpio.sv` | `tb_gpio.sv` | 4 |
| 10 | `rv32ima_mcu.sv` (Full SoC) | `tb_mcu.sv` | 4 |

**Total: 185 self-checking verification points across 14 testbenches — all passing.**

---

## Synthesis Target

| Parameter | Value |
| :--- | :--- |
| Technology | SAED 32nm / 14nm |
| Target clock | 50 MHz (20 ns period) |
| Tool | Synopsys Design Compiler |
| Operating condition | Typical (tt_1p05v_25c) |
| Reset | Active-low synchronous (`rst_n`) |

---

## Documentation

| Document | Description |
| :--- | :--- |
| [`docs/architecture.md`](docs/architecture.md) | Microarchitecture specification |
| [`docs/isa.md`](docs/isa.md) | ISA reference and instruction encoding |
| [`docs/memory_map.md`](docs/memory_map.md) | System address space allocation |
| [`docs/verification.md`](docs/verification.md) | Verification plan and test coverage |
| [`docs/saed_integration.md`](docs/saed_integration.md) | SAED SRAM macro integration guide |
