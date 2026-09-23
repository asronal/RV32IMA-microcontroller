// =============================================================================
// File: mem_wb.sv
// Description: MEM/WB Pipeline Stage Register
// Features:
//   - Registers Memory stage outputs and prepares writeback to Register File
//   - Supports synchronous stall and flush
//   - Active-low asynchronous reset
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module mem_wb
  import rv32_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Pipeline Flow Control
  input  logic        stall,
  input  logic        flush,

  // Inputs from MEM Stage
  input  logic [31:0] mem_pc4,
  input  logic [31:0] mem_alu_result,
  input  logic [31:0] mem_rdata,
  input  logic [4:0]  mem_rd_addr,
  input  logic        mem_reg_write,
  input  wb_src_e     mem_wb_src,
  input  logic        mem_valid,

  // Outputs to WB Stage
  output logic [31:0] wb_pc4,
  output logic [31:0] wb_alu_result,
  output logic [31:0] wb_rdata,
  output logic [4:0]  wb_rd_addr,
  output logic        wb_reg_write,
  output wb_src_e     wb_wb_src,
  output logic        wb_valid
);

  // ---------------------------------------------------------------------------
  // Sequential Register Process
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wb_pc4        <= 32'd0;
      wb_alu_result <= 32'd0;
      wb_rdata      <= 32'd0;
      wb_rd_addr    <= 5'd0;
      wb_reg_write  <= 1'b0;
      wb_wb_src     <= WB_SRC_ALU;
      wb_valid      <= 1'b0;
    end else if (flush) begin
      wb_pc4        <= 32'd0;
      wb_alu_result <= 32'd0;
      wb_rdata      <= 32'd0;
      wb_rd_addr    <= 5'd0;
      wb_reg_write  <= 1'b0;
      wb_wb_src     <= WB_SRC_ALU;
      wb_valid      <= 1'b0;
    end else if (!stall) begin
      wb_pc4        <= mem_pc4;
      wb_alu_result <= mem_alu_result;
      wb_rdata      <= mem_rdata;
      wb_rd_addr    <= mem_rd_addr;
      wb_reg_write  <= mem_reg_write;
      wb_wb_src     <= mem_wb_src;
      wb_valid      <= mem_valid;
    end
  end

endmodule : mem_wb
