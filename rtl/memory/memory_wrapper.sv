// =============================================================================
// File: memory_wrapper.sv
// Description: Unified Memory Controller Subsystem
// Features:
//   - Encapsulates Boot ROM and SRAM
//   - Implements compile-time selection between generic synthesizable RAM and
//     SAED SRAM macro wrapper via `ifdef USE_SAED_MEMORY
//   - Fully isolated from CPU and bus architecture (Section 8 compliance)
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module memory_wrapper #(
  parameter int ROM_BYTES = 32768,
  parameter int RAM_BYTES = 32768,
  parameter     BOOT_HEX  = ""
)(
  input  logic        clk,

  // ---------------------------------------------------------------------------
  // Instruction Fetch Port (Connected to Boot ROM)
  // ---------------------------------------------------------------------------
  input  logic        imem_en,
  input  logic [31:0] imem_addr,
  output logic [31:0] imem_rdata,

  // ---------------------------------------------------------------------------
  // Data Bus Port: ROM Access (from Bus Decoder)
  // ---------------------------------------------------------------------------
  input  logic        rom_en,
  input  logic [31:0] rom_addr,
  output logic [31:0] rom_rdata,

  // ---------------------------------------------------------------------------
  // Data Bus Port: RAM Access (from Bus Decoder)
  // ---------------------------------------------------------------------------
  input  logic        ram_en,
  input  logic        ram_we,
  input  logic [31:0] ram_addr,
  input  logic [31:0] ram_wdata,
  input  logic [3:0]  ram_wstrb,
  output logic [31:0] ram_rdata
);

  // ---------------------------------------------------------------------------
  // Dual-Port Boot ROM Instance
  // ---------------------------------------------------------------------------
  rom #(
    .ROM_BYTES (ROM_BYTES),
    .INIT_HEX  (BOOT_HEX)
  ) u_rom (
    .clk        (clk),
    .imem_en    (imem_en),
    .imem_addr  (imem_addr),
    .imem_rdata (imem_rdata),
    .dmem_en    (rom_en),
    .dmem_addr  (rom_addr),
    .dmem_rdata (rom_rdata)
  );

  // ---------------------------------------------------------------------------
  // SRAM Subsystem: Generic Synthesizable RAM vs SAED PDK SRAM Macro
  // When USE_SAED_MEMORY is defined, generic RAM is strictly NOT instantiated.
  // ---------------------------------------------------------------------------
`ifdef USE_SAED_MEMORY
  saed_sram_wrapper #(
    .RAM_BYTES (RAM_BYTES)
  ) u_saed_ram (
    .clk   (clk),
    .en    (ram_en),
    .we    (ram_we),
    .addr  (ram_addr),
    .wdata (ram_wdata),
    .wstrb (ram_wstrb),
    .rdata (ram_rdata)
  );
`else
  ram #(
    .RAM_BYTES (RAM_BYTES)
  ) u_generic_ram (
    .clk   (clk),
    .en    (ram_en),
    .we    (ram_we),
    .addr  (ram_addr),
    .wdata (ram_wdata),
    .wstrb (ram_wstrb),
    .rdata (ram_rdata)
  );
`endif

endmodule : memory_wrapper
