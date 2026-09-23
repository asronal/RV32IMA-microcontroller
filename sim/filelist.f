# Minimal RV32IMA Simulation Filelist
# Include paths
+incdir+../rtl/core
+incdir+../rtl/pipeline
+incdir+../rtl/bus
+incdir+../rtl/memory
+incdir+../rtl/peripherals

# Phase 1: Package and Core Primitives
../rtl/core/rv32_pkg.sv
../rtl/core/alu.sv
../rtl/core/regfile.sv
../rtl/core/immediate_gen.sv
../rtl/core/decoder.sv

# Phase 2: PC and Pipeline Registers
../rtl/core/pc_reg.sv
../rtl/pipeline/if_id.sv
../rtl/pipeline/id_ex.sv
../rtl/pipeline/ex_mem.sv
../rtl/pipeline/mem_wb.sv

# Phase 3: Branch Unit
../rtl/core/branch_unit.sv

# Phase 4: Forwarding and Hazard Units
../rtl/core/forwarding_unit.sv
../rtl/core/hazard_unit.sv

# Phase 5: Core Top-Level
../rtl/core/rv32_core.sv

# Phase 6: Atomic Unit
../rtl/core/atomic_unit.sv

# Phase 7: Bus Decoder and Memory Abstraction
../rtl/bus/bus_decoder.sv
../rtl/memory/rom.sv
../rtl/memory/ram.sv
../rtl/memory/saed_sram_wrapper.sv
../rtl/memory/memory_wrapper.sv

# Phase 8: UART Peripheral
../rtl/peripherals/uart.sv

# Phase 9: GPIO Peripheral
../rtl/peripherals/gpio.sv

# Phase 10: Full SoC Top-Level
../rtl/rv32ima_mcu.sv

# Testbenches
../tb/tb_alu.sv
../tb/tb_regfile.sv
../tb/tb_immediate_gen.sv
../tb/tb_decoder.sv
../tb/tb_pipeline_regs.sv
../tb/tb_branch_unit.sv
../tb/tb_forwarding_unit.sv
../tb/tb_hazard_unit.sv
../tb/tb_core.sv
../tb/tb_atomic_unit.sv
../tb/tb_memory.sv
../tb/tb_uart.sv
../tb/tb_gpio.sv
../tb/tb_mcu.sv
