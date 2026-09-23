// =============================================================================
// File: id_ex.sv
// Description: ID/EX Pipeline Stage Register
// Features:
//   - Registers decoded control signals, register data, and immediate values
//   - Supports synchronous flush (bubble insertion on branch or load-use hazard)
//   - Supports synchronous stall
//   - Active-low asynchronous reset
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module id_ex
  import rv32_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Pipeline Flow Control
  input  logic        stall,
  input  logic        flush,

  // Inputs from ID Stage
  input  logic [31:0] id_pc,
  input  logic [31:0] id_pc4,
  input  logic [31:0] id_rs1_data,
  input  logic [31:0] id_rs2_data,
  input  logic [4:0]  id_rs1_addr,
  input  logic [4:0]  id_rs2_addr,
  input  logic [4:0]  id_rd_addr,
  input  logic [31:0] id_imm,

  // Control Signals from ID Stage
  input  alu_op_e      id_alu_op,
  input  alu_src_a_e   id_alu_src_a,
  input  alu_src_b_e   id_alu_src_b,
  input  branch_type_e id_branch_type,
  input  logic         id_jump,
  input  logic         id_jump_is_jalr,
  input  logic         id_mem_read,
  input  logic         id_mem_write,
  input  mem_size_e    id_mem_size,
  input  logic         id_mem_unsigned,
  input  logic         id_reg_write,
  input  wb_src_e      id_wb_src,
  input  logic         id_is_atomic,
  input  amo_op_e      id_amo_op,
  input  logic         id_is_csr,
  input  logic         id_is_mret,
  input  logic         id_is_wfi,
  input  logic         id_is_ecall,
  input  logic         id_is_ebreak,
  input  logic         id_illegal_instr,
  input  logic         id_valid,

  // Outputs to EX Stage
  output logic [31:0] ex_pc,
  output logic [31:0] ex_pc4,
  output logic [31:0] ex_rs1_data,
  output logic [31:0] ex_rs2_data,
  output logic [4:0]  ex_rs1_addr,
  output logic [4:0]  ex_rs2_addr,
  output logic [4:0]  ex_rd_addr,
  output logic [31:0] ex_imm,

  // Control Signals to EX Stage
  output alu_op_e      ex_alu_op,
  output alu_src_a_e   ex_alu_src_a,
  output alu_src_b_e   ex_alu_src_b,
  output branch_type_e ex_branch_type,
  output logic         ex_jump,
  output logic         ex_jump_is_jalr,
  output logic         ex_mem_read,
  output logic         ex_mem_write,
  output mem_size_e    ex_mem_size,
  output logic         ex_mem_unsigned,
  output logic         ex_reg_write,
  output wb_src_e      ex_wb_src,
  output logic         ex_is_atomic,
  output amo_op_e      ex_amo_op,
  output logic         ex_is_csr,
  output logic         ex_is_mret,
  output logic         ex_is_wfi,
  output logic         ex_is_ecall,
  output logic         ex_is_ebreak,
  output logic         ex_illegal_instr,
  output logic         ex_valid
);

  // ---------------------------------------------------------------------------
  // Sequential Register Process
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ex_pc            <= 32'd0;
      ex_pc4           <= 32'd0;
      ex_rs1_data      <= 32'd0;
      ex_rs2_data      <= 32'd0;
      ex_rs1_addr      <= 5'd0;
      ex_rs2_addr      <= 5'd0;
      ex_rd_addr       <= 5'd0;
      ex_imm           <= 32'd0;
      ex_alu_op        <= ALU_ADD;
      ex_alu_src_a     <= ALU_SRC_A_RS1;
      ex_alu_src_b     <= ALU_SRC_B_RS2;
      ex_branch_type   <= BRANCH_NONE;
      ex_jump          <= 1'b0;
      ex_jump_is_jalr  <= 1'b0;
      ex_mem_read      <= 1'b0;
      ex_mem_write     <= 1'b0;
      ex_mem_size      <= MEM_SIZE_WORD;
      ex_mem_unsigned  <= 1'b0;
      ex_reg_write     <= 1'b0;
      ex_wb_src        <= WB_SRC_ALU;
      ex_is_atomic     <= 1'b0;
      ex_amo_op        <= AMO_OP_NONE;
      ex_is_csr        <= 1'b0;
      ex_is_mret       <= 1'b0;
      ex_is_wfi        <= 1'b0;
      ex_is_ecall      <= 1'b0;
      ex_is_ebreak     <= 1'b0;
      ex_illegal_instr <= 1'b0;
      ex_valid         <= 1'b0;
    end else if (flush) begin
      // Bubble insertion: deactivate all active control lines
      ex_pc            <= 32'd0;
      ex_pc4           <= 32'd0;
      ex_rs1_data      <= 32'd0;
      ex_rs2_data      <= 32'd0;
      ex_rs1_addr      <= 5'd0;
      ex_rs2_addr      <= 5'd0;
      ex_rd_addr       <= 5'd0;
      ex_imm           <= 32'd0;
      ex_alu_op        <= ALU_ADD;
      ex_alu_src_a     <= ALU_SRC_A_RS1;
      ex_alu_src_b     <= ALU_SRC_B_RS2;
      ex_branch_type   <= BRANCH_NONE;
      ex_jump          <= 1'b0;
      ex_jump_is_jalr  <= 1'b0;
      ex_mem_read      <= 1'b0;
      ex_mem_write     <= 1'b0;
      ex_mem_size      <= MEM_SIZE_WORD;
      ex_mem_unsigned  <= 1'b0;
      ex_reg_write     <= 1'b0;
      ex_wb_src        <= WB_SRC_ALU;
      ex_is_atomic     <= 1'b0;
      ex_amo_op        <= AMO_OP_NONE;
      ex_is_csr        <= 1'b0;
      ex_is_mret       <= 1'b0;
      ex_is_wfi        <= 1'b0;
      ex_is_ecall      <= 1'b0;
      ex_is_ebreak     <= 1'b0;
      ex_illegal_instr <= 1'b0;
      ex_valid         <= 1'b0;
    end else if (!stall) begin
      ex_pc            <= id_pc;
      ex_pc4           <= id_pc4;
      ex_rs1_data      <= id_rs1_data;
      ex_rs2_data      <= id_rs2_data;
      ex_rs1_addr      <= id_rs1_addr;
      ex_rs2_addr      <= id_rs2_addr;
      ex_rd_addr       <= id_rd_addr;
      ex_imm           <= id_imm;
      ex_alu_op        <= id_alu_op;
      ex_alu_src_a     <= id_alu_src_a;
      ex_alu_src_b     <= id_alu_src_b;
      ex_branch_type   <= id_branch_type;
      ex_jump          <= id_jump;
      ex_jump_is_jalr  <= id_jump_is_jalr;
      ex_mem_read      <= id_mem_read;
      ex_mem_write     <= id_mem_write;
      ex_mem_size      <= id_mem_size;
      ex_mem_unsigned  <= id_mem_unsigned;
      ex_reg_write     <= id_reg_write;
      ex_wb_src        <= id_wb_src;
      ex_is_atomic     <= id_is_atomic;
      ex_amo_op        <= id_amo_op;
      ex_is_csr        <= id_is_csr;
      ex_is_mret       <= id_is_mret;
      ex_is_wfi        <= id_is_wfi;
      ex_is_ecall      <= id_is_ecall;
      ex_is_ebreak     <= id_is_ebreak;
      ex_illegal_instr <= id_illegal_instr;
      ex_valid         <= id_valid;
    end
  end

endmodule : id_ex
