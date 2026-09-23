# =============================================================================
# File: Makefile
# Description: Build system for Minimal RV32IMA Bare-Metal Firmware
#
# Toolchain: RISC-V GCC cross-compiler (riscv32-unknown-elf or riscv64-unknown-elf)
#   Install: sudo apt install gcc-riscv64-linux-gnu   (Ubuntu)
#            brew install riscv-software-src/riscv/riscv-gnu-toolchain (macOS)
#
# Targets:
#   make          : Build firmware.elf and firmware.hex
#   make clean    : Remove build artifacts
#   make disasm   : Disassemble firmware.elf
#   make size     : Print section sizes
#
# firmware.hex is a $readmemh-compatible hex file for Verilog simulation.
# =============================================================================

# Toolchain prefix — auto-detect available RISC-V GCC
CROSS ?= $(shell which riscv64-none-linux-musl-gcc >/dev/null 2>&1 && echo riscv64-none-linux-musl || echo riscv64-unknown-elf)
CC     = $(CROSS)-gcc
OBJCOPY = $(CROSS)-objcopy
OBJDUMP = $(CROSS)-objdump
SIZE    = $(CROSS)-size

# Build directory
BUILD = build

# Source files
SRCS = startup.S main.c

# Architecture flags (strict RV32IMA + zicsr for CSR instructions)
ARCH_FLAGS = -march=rv32ima_zicsr -mabi=ilp32

# Compiler and linker flags
CFLAGS  = $(ARCH_FLAGS) -O2 -Wall -Wextra \
           -ffreestanding -ffunction-sections -fdata-sections \
           -nostdlib -nostartfiles
LDFLAGS = $(ARCH_FLAGS) -T linker.ld \
           -Wl,--gc-sections \
           -Wl,-Map=$(BUILD)/firmware.map

# Output targets
ELF = $(BUILD)/firmware.elf
HEX = $(BUILD)/firmware.hex
LST = $(BUILD)/firmware.lst

.PHONY: all clean disasm size hex

all: $(HEX)

$(BUILD):
	mkdir -p $(BUILD)

# Compile and link in one step (two-source project)
$(ELF): $(SRCS) linker.ld | $(BUILD)
	$(CC) $(CFLAGS) $(LDFLAGS) $(SRCS) -o $@

# Generate $readmemh-compatible hex image (word-addressed, row per word)
# verilog format: 4-byte-per-line big-endian hex, no address records
$(HEX): $(ELF)
	$(OBJCOPY) -O verilog --verilog-data-width 4 $< $@
	@echo ""
	@echo "====================================="
	@echo "  firmware.hex written to $(HEX)"
	@echo "  Copy to sim/ or point BOOT_HEX parameter to this path."
	@echo "====================================="

# Disassembly listing
disasm: $(ELF)
	$(OBJDUMP) -d -S -z $< > $(LST)
	@echo "Disassembly written to $(LST)"

# Section size report
size: $(ELF)
	$(SIZE) $<

clean:
	rm -rf $(BUILD)
