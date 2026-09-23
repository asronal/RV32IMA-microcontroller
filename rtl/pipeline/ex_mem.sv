// =============================================================================
// File: ex_mem.sv
// Description: EX/MEM Pipeline Stage Register
// Features:
//   - Registers EX stage execution results (ALU result, store data, destination)
//   - Passes memory access controls and writeback signals
//   - Supports synchronous stall and flush
//   - Active-low asynchronous reset
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module ex_mem
  import rv32_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Pipeline Flow Control
  input  logic        stall,
  input  logic        flush,

  // Inputs from EX Stage
  input  logic [31:0] ex_pc,
  input  logic [31:0] ex_pc4,
  input  logic [31:0] ex_alu_result,
  input  logic [31:0] ex_rs2_data,
  input  logic [4:0]  ex_rd_addr,

  // Control Signals from EX Stage
  input  logic        ex_mem_read,
  input  logic        ex_mem_write,
  input  mem_size_e   ex_mem_size,
  input  logic        ex_mem_unsigned,
  input  logic        ex_reg_write,
  input  wb_src_e     ex_wb_src,
  input  logic        ex_is_atomic,
  input  amo_op_e     ex_amo_op,
  input  logic        ex_is_csr,
  input  logic        ex_is_mret,
  input  logic        ex_is_wfi,
  input  logic        ex_is_ecall,
  input  logic        ex_is_ebreak,
  input  logic        ex_illegal_instr,
  input  logic        ex_valid,

  // Outputs to MEM Stage
  output logic [31:0] mem_pc,
  output logic [31:0] mem_pc4,
  output logic [31:0] mem_alu_result,
  output logic [31:0] mem_rs2_data,
  output logic [4:0]  mem_rd_addr,

  // Control Signals to MEM Stage
  output logic        mem_mem_read,
  output logic        mem_mem_write,
  output mem_size_e   mem_mem_size,
  output logic        mem_mem_unsigned,
  output logic        mem_reg_write,
  output wb_src_e     mem_wb_src,
  output logic        mem_is_atomic,
  output amo_op_e     mem_amo_op,
  output logic        mem_is_csr,
  output logic        mem_is_mret,
  output logic        mem_is_wfi,
  output logic        mem_is_ecall,
  output logic        mem_is_ebreak,
  output logic        mem_illegal_instr,
  output logic        mem_valid
);

  // ---------------------------------------------------------------------------
  // Sequential Register Process
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_pc            <= 32'd0;
      mem_pc4           <= 32'd0;
      mem_alu_result    <= 32'd0;
      mem_rs2_data      <= 32'd0;
      mem_rd_addr       <= 5'd0;
      mem_mem_read      <= 1'b0;
      mem_mem_write     <= 1'b0;
      mem_mem_size      <= MEM_SIZE_WORD;
      mem_mem_unsigned  <= 1'b0;
      mem_reg_write     <= 1'b0;
      mem_wb_src        <= WB_SRC_ALU;
      mem_is_atomic     <= 1'b0;
      mem_amo_op        <= AMO_OP_NONE;
      mem_is_csr        <= 1'b0;
      mem_is_mret       <= 1'b0;
      mem_is_wfi        <= 1'b0;
      mem_is_ecall      <= 1'b0;
      mem_is_ebreak     <= 1'b0;
      mem_illegal_instr <= 1'b0;
      mem_valid         <= 1'b0;
    end else if (flush) begin
      mem_pc            <= 32'd0;
      mem_pc4           <= 32'd0;
      mem_alu_result    <= 32'd0;
      mem_rs2_data      <= 32'd0;
      mem_rd_addr       <= 5'd0;
      mem_mem_read      <= 1'b0;
      mem_mem_write     <= 1'b0;
      mem_mem_size      <= MEM_SIZE_WORD;
      mem_mem_unsigned  <= 1'b0;
      mem_reg_write     <= 1'b0;
      mem_wb_src        <= WB_SRC_ALU;
      mem_is_atomic     <= 1'b0;
      mem_amo_op        <= AMO_OP_NONE;
      mem_is_csr        <= 1'b0;
      mem_is_mret       <= 1'b0;
      mem_is_wfi        <= 1'b0;
      mem_is_ecall      <= 1'b0;
      mem_is_ebreak     <= 1'b0;
      mem_illegal_instr <= 1'b0;
      mem_valid         <= 1'b0;
    end else if (!stall) begin
      mem_pc            <= ex_pc;
      mem_pc4           <= ex_pc4;
      mem_alu_result    <= ex_alu_result;
      mem_rs2_data      <= ex_rs2_data;
      mem_rd_addr       <= ex_rd_addr;
      mem_mem_read      <= ex_mem_read;
      mem_mem_write     <= ex_mem_write;
      mem_mem_size      <= ex_mem_size;
      mem_mem_unsigned  <= ex_mem_unsigned;
      mem_reg_write     <= ex_reg_write;
      mem_wb_src        <= ex_wb_src;
      mem_is_atomic     <= ex_is_atomic;
      mem_amo_op        <= ex_amo_op;
      mem_is_csr        <= ex_is_csr;
      mem_is_mret       <= ex_is_mret;
      mem_is_wfi        <= ex_is_wfi;
      mem_is_ecall      <= ex_is_ecall;
      mem_is_ebreak     <= ex_is_ebreak;
      mem_illegal_instr <= ex_illegal_instr;
      mem_valid         <= ex_valid;
    end
  end

endmodule : ex_mem
