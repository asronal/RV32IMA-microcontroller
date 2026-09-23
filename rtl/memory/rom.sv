// =============================================================================
// File: rom.sv
// Description: Dual-Port Parameterized Boot ROM
// Features:
//   - Parameterized capacity (Default: 32 KB = 8192 words)
//   - Port A: Instruction Fetch Interface
//   - Port B: Data Load Interface
//   - Supports hex initialization via INIT_HEX parameter
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module rom #(
  parameter int ROM_BYTES = 32768,
  parameter     INIT_HEX  = ""
)(
  input  logic        clk,

  // Port A: Instruction Fetch Port
  input  logic        imem_en,
  input  logic [31:0] imem_addr,
  output logic [31:0] imem_rdata,

  // Port B: Data Memory Read Port
  input  logic        dmem_en,
  input  logic [31:0] dmem_addr,
  output logic [31:0] dmem_rdata
);

  localparam int ROM_WORDS = ROM_BYTES / 4;
  localparam int ADDR_BITS = $clog2(ROM_WORDS);

  // 32-bit word-addressed ROM storage array
  logic [31:0] mem [0:ROM_WORDS-1];

  // Address slicing (word index)
  logic [ADDR_BITS-1:0] imem_idx;
  logic [ADDR_BITS-1:0] dmem_idx;

  assign imem_idx = imem_addr[ADDR_BITS+1:2];
  assign dmem_idx = dmem_addr[ADDR_BITS+1:2];

  // Asynchronous read with range gating
  assign imem_rdata = imem_en ? mem[imem_idx] : 32'h0000_0013;
  assign dmem_rdata = dmem_en ? mem[dmem_idx] : 32'd0;

  // Initialize ROM content
  initial begin
    for (int i = 0; i < ROM_WORDS; i++) begin
      mem[i] = 32'h0000_0013; // Default to NOP (addi x0, x0, 0)
    end

    if (INIT_HEX != "") begin
      $readmemh(INIT_HEX, mem);
    end
  end

endmodule : rom
