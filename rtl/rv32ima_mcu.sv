// =============================================================================
// File: rv32ima_mcu.sv
// Description: Full SoC Top-Level Integration for Minimal RV32IMA Microcontroller
//
// System Architecture:
//   - rv32_core        : 5-Stage RV32IMA pipeline CPU
//   - memory_wrapper   : Boot ROM (32 KB) + SRAM (32 KB) with SAED macro hook
//   - bus_decoder      : Centralized address decoder and bus mux
//   - uart             : Memory-mapped 8N1 UART  @ 0x2000_0000
//   - gpio             : Memory-mapped GPIO (8-bit) @ 0x2000_1000
//
// Memory Map (Section 10):
//   0x0000_0000 - 0x0000_7FFF : Boot ROM   (32 KB, instruction + data fetch)
//   0x1000_0000 - 0x1000_7FFF : SRAM       (32 KB, read/write data)
//   0x2000_0000 - 0x2000_0FFF : UART       (4 KB)
//   0x2000_1000 - 0x2000_1FFF : GPIO       (4 KB)
//
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC / SAED PDK)
// =============================================================================

`timescale 1ns / 1ps

module rv32ima_mcu #(
  parameter int    ROM_BYTES    = 32768,
  parameter int    RAM_BYTES    = 32768,
  parameter int    CLK_HZ       = 50_000_000,
  parameter int    BAUD_RATE    = 115200,
  parameter int GPIO_WIDTH   = 8,
  parameter     BOOT_HEX     = ""
)(
  input  logic                  clk,
  input  logic                  rst_n,

  // UART External Pins
  input  logic                  uart_rx,
  output logic                  uart_tx,

  // GPIO External Pins
  input  logic [GPIO_WIDTH-1:0] gpio_in,
  output logic [GPIO_WIDTH-1:0] gpio_out,
  output logic [GPIO_WIDTH-1:0] gpio_oe
);

  // ===========================================================================
  // Internal Interconnect Signals
  // ===========================================================================

  // CPU Instruction Memory Interface
  logic        imem_req;
  logic [31:0] imem_addr;
  logic [31:0] imem_rdata;

  // CPU Data Memory Interface (Master to Bus Decoder)
  logic        dmem_valid;
  logic        dmem_write;
  logic [31:0] dmem_addr;
  logic [31:0] dmem_wdata;
  logic [3:0]  dmem_wstrb;
  logic [31:0] dmem_rdata;
  logic        dmem_ready;

  // Bus Decoder → Memory Wrapper (ROM)
  logic        rom_en;
  logic [31:0] rom_addr;
  logic [31:0] rom_rdata;

  // Bus Decoder → Memory Wrapper (RAM)
  logic        ram_en;
  logic        ram_we;
  logic [31:0] ram_addr;
  logic [31:0] ram_wdata;
  logic [3:0]  ram_wstrb;
  logic [31:0] ram_rdata;

  // Bus Decoder → UART
  logic        uart_en;
  logic        uart_we;
  logic [11:0] uart_addr;
  logic [31:0] uart_wdata;
  logic [31:0] uart_rdata;

  // Bus Decoder → GPIO
  logic        gpio_en;
  logic        gpio_we;
  logic [11:0] gpio_addr;
  logic [31:0] gpio_wdata;
  logic [31:0] gpio_rdata;

  // ===========================================================================
  // 1. CPU Core
  // ===========================================================================
  rv32_core u_rv32_core (
    .clk         (clk),
    .rst_n       (rst_n),
    // Instruction Interface
    .imem_req    (imem_req),
    .imem_addr   (imem_addr),
    .imem_rdata  (imem_rdata),
    // Data Interface
    .dmem_valid  (dmem_valid),
    .dmem_write  (dmem_write),
    .dmem_addr   (dmem_addr),
    .dmem_wdata  (dmem_wdata),
    .dmem_wstrb  (dmem_wstrb),
    .dmem_rdata  (dmem_rdata),
    .dmem_ready  (dmem_ready)
  );

  // ===========================================================================
  // 2. Centralized Address Decoder / Bus Multiplexer
  // ===========================================================================
  bus_decoder u_bus_decoder (
    // Master CPU side
    .dmem_valid  (dmem_valid),
    .dmem_write  (dmem_write),
    .dmem_addr   (dmem_addr),
    .dmem_wdata  (dmem_wdata),
    .dmem_wstrb  (dmem_wstrb),
    .dmem_rdata  (dmem_rdata),
    .dmem_ready  (dmem_ready),
    // ROM
    .rom_en      (rom_en),
    .rom_addr    (rom_addr),
    .rom_rdata   (rom_rdata),
    // RAM
    .ram_en      (ram_en),
    .ram_we      (ram_we),
    .ram_addr    (ram_addr),
    .ram_wdata   (ram_wdata),
    .ram_wstrb   (ram_wstrb),
    .ram_rdata   (ram_rdata),
    // UART
    .uart_en     (uart_en),
    .uart_we     (uart_we),
    .uart_addr   (uart_addr),
    .uart_wdata  (uart_wdata),
    .uart_rdata  (uart_rdata),
    // GPIO
    .gpio_en     (gpio_en),
    .gpio_we     (gpio_we),
    .gpio_addr   (gpio_addr),
    .gpio_wdata  (gpio_wdata),
    .gpio_rdata  (gpio_rdata)
  );

  // ===========================================================================
  // 3. Memory Wrapper (ROM + SRAM or SAED Macro)
  // ===========================================================================
  memory_wrapper #(
    .ROM_BYTES (ROM_BYTES),
    .RAM_BYTES (RAM_BYTES),
    .BOOT_HEX  (BOOT_HEX)
  ) u_memory_wrapper (
    .clk        (clk),
    // Instruction Fetch Port → Boot ROM
    .imem_en    (imem_req),
    .imem_addr  (imem_addr),
    .imem_rdata (imem_rdata),
    // Data ROM Port
    .rom_en     (rom_en),
    .rom_addr   (rom_addr),
    .rom_rdata  (rom_rdata),
    // Data RAM Port
    .ram_en     (ram_en),
    .ram_we     (ram_we),
    .ram_addr   (ram_addr),
    .ram_wdata  (ram_wdata),
    .ram_wstrb  (ram_wstrb),
    .ram_rdata  (ram_rdata)
  );

  // ===========================================================================
  // 4. UART Peripheral
  // ===========================================================================
  uart #(
    .CLK_HZ       (CLK_HZ),
    .DEFAULT_BAUD (BAUD_RATE)
  ) u_uart (
    .clk     (clk),
    .rst_n   (rst_n),
    .en      (uart_en),
    .we      (uart_we),
    .addr    (uart_addr),
    .wdata   (uart_wdata),
    .rdata   (uart_rdata),
    .uart_rx (uart_rx),
    .uart_tx (uart_tx)
  );

  // ===========================================================================
  // 5. GPIO Peripheral
  // ===========================================================================
  gpio #(
    .GPIO_WIDTH (GPIO_WIDTH)
  ) u_gpio (
    .clk      (clk),
    .rst_n    (rst_n),
    .en       (gpio_en),
    .we       (gpio_we),
    .addr     (gpio_addr),
    .wdata    (gpio_wdata),
    .rdata    (gpio_rdata),
    .gpio_in  (gpio_in),
    .gpio_out (gpio_out),
    .gpio_oe  (gpio_oe)
  );

endmodule : rv32ima_mcu
