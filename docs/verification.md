# Verification Strategy and Final Results

---

## 1. Verification Philosophy

The methodology follows a strict **bottom-up, self-checking** approach:
- Every module has its own self-contained testbench with `[PASS]` / `[FAIL]` output and a final error count.
- All testbenches use `$finish` at the end — no manual simulation termination needed.
- The integration testbench (`tb_mcu.sv`) exercises the full software-hardware path by booting from a `firmware.hex` image and capturing UART output.

---

## 2. Testbench Coverage — Complete Matrix

| Phase | Testbench | DUT(s) | Checks | Key Scenarios |
| :---: | :--- | :--- | :---: | :--- |
| 1 | [`tb_alu.sv`](file:///c:/projects/minimal_mcu/tb/tb_alu.sv) | `alu.sv` | **22** | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU, COPY_B, zero-flag |
| 1 | [`tb_regfile.sv`](file:///c:/projects/minimal_mcu/tb/tb_regfile.sv) | `regfile.sv` | **36** | Reset, `x0` == 0 enforcement, sweep `x1–x31`, dual-port simultaneous read |
| 1 | [`tb_immediate_gen.sv`](file:///c:/projects/minimal_mcu/tb/tb_immediate_gen.sv) | `immediate_gen.sv` | **8** | I, S, B, U, J, CSR sign-extension and bit-splicing |
| 1 | [`tb_decoder.sv`](file:///c:/projects/minimal_mcu/tb/tb_decoder.sv) | `decoder.sv` | **34** | RV32I, RV32A, CSR, ECALL/EBREAK, illegal opcode trapping |
| 2 | [`tb_pipeline_regs.sv`](file:///c:/projects/minimal_mcu/tb/tb_pipeline_regs.sv) | `pc_reg`, `if_id`, `id_ex`, `ex_mem`, `mem_wb` | **14** | PC increment, stall hold, branch redirect, bubble injection, flush priority |
| 3 | [`tb_branch_unit.sv`](file:///c:/projects/minimal_mcu/tb/tb_branch_unit.sv) | `branch_unit.sv` | **15** | BEQ, BNE, BLT, BGE, BLTU, BGEU, JAL target, JALR LSB masking |
| 4 | [`tb_forwarding_unit.sv`](file:///c:/projects/minimal_mcu/tb/tb_forwarding_unit.sv) | `forwarding_unit.sv` | **8** | EX/MEM forward, MEM/WB forward, priority, `x0` exclusion |
| 4 | [`tb_hazard_unit.sv`](file:///c:/projects/minimal_mcu/tb/tb_hazard_unit.sv) | `hazard_unit.sv` | **7** | Load-use stall, branch flush, flush priority over stall |
| 5 | [`tb_core.sv`](file:///c:/projects/minimal_mcu/tb/tb_core.sv) | `rv32_core.sv` | **13** | RAW forwarding, load-use stall, byte store/load, branch flush, JAL/JALR link |
| 6 | [`tb_atomic_unit.sv`](file:///c:/projects/minimal_mcu/tb/tb_atomic_unit.sv) | `atomic_unit.sv` | **12** | LR.W, SC.W success/fail, address mismatch, intervening store, AMOSWAP, AMOADD, AMOXOR, AMOAND, AMOOR, AMOMIN, AMOMAX |
| 7 | [`tb_memory.sv`](file:///c:/projects/minimal_mcu/tb/tb_memory.sv) | `bus_decoder`, `memory_wrapper` | **6** | ROM fetch, bus decode to ROM/UART/GPIO, SRAM word write/read, byte strobe assembly |
| 8 | [`tb_uart.sv`](file:///c:/projects/minimal_mcu/tb/tb_uart.sv) | `uart.sv` | **5** | STATUS init, TX start bit, TX busy, RX byte capture, RX_VALID auto-clear |
| 9 | [`tb_gpio.sv`](file:///c:/projects/minimal_mcu/tb/tb_gpio.sv) | `gpio.sv` | **4** | Reset defaults, DIR config, output drive, external input sampling |
| 10 | [`tb_mcu.sv`](file:///c:/projects/minimal_mcu/tb/tb_mcu.sv) | `rv32ima_mcu.sv` | **4** | First char 'H', "Hello" string match, min output length, GPIO input |

**Total: 188 self-checking checks across 14 testbenches.**

---

## 3. How to Run Simulations

```bash
# Individual unit testbench (example: ALU)
vcs -sverilog -f sim/filelist.f -top tb_alu +define+UNIT_SIM -R

# Full core integration
vcs -sverilog -f sim/filelist.f -top tb_core -R

# Full SoC integration (requires firmware.hex)
vcs -sverilog -f sim/filelist.f -top tb_mcu +define+SIM_ROM_HEX=\"sw/build/firmware.hex\" -R

# With SAED SRAM macro enabled
vcs -sverilog +define+USE_SAED_MEMORY -f sim/filelist.f -top tb_mcu -R
```

---

## 4. Synthesis Verification Checklist

After running `syn/dc.tcl`, check these reports:

| Report | File | What to Check |
| :--- | :--- | :--- |
| Timing | `syn/reports/timing.rpt` | No setup/hold violations at 50 MHz |
| Area | `syn/reports/area.rpt` | Total cell area and module breakdown |
| Power | `syn/reports/power.rpt` | Dynamic and leakage estimates |
| Constraint violations | `syn/reports/violations.rpt` | Should be empty |
| Unresolved references | DC console output | Should be zero (SAED cell library properly linked) |
