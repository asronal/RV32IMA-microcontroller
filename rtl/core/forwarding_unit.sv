// =============================================================================
// File: forwarding_unit.sv
// Description: Data Forwarding Unit for RV32 5-Stage Pipeline
// Features:
//   - Resolves RAW data hazards across EX, MEM, and WB stages without stalls
//   - Forwards from EX/MEM stage (ALU results) with highest priority
//   - Forwards from MEM/WB stage (ALU or Memory load results)
//   - Explicitly excludes register x0 (waddr == 5'd0) from forwarding
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module forwarding_unit (
  // Source register addresses consumed in EX stage
  input  logic [4:0] ex_rs1_addr,
  input  logic [4:0] ex_rs2_addr,

  // EX/MEM stage writeback control and destination
  input  logic       mem_reg_write,
  input  logic [4:0] mem_rd_addr,

  // MEM/WB stage writeback control and destination
  input  logic       wb_reg_write,
  input  logic [4:0] wb_rd_addr,

  // Forwarding Multiplexer Selectors
  // 2'b00: No forward (use registered operand from ID/EX)
  // 2'b10: Forward from EX/MEM stage (mem_alu_result)
  // 2'b01: Forward from MEM/WB stage (wb_data)
  output logic [1:0] forward_a,
  output logic [1:0] forward_b
);

  // ---------------------------------------------------------------------------
  // Forwarding Logic for Operand A (rs1)
  // EX/MEM hazard takes precedence over MEM/WB hazard (youngest producer wins).
  // ---------------------------------------------------------------------------
  always_comb begin
    if (mem_reg_write && (mem_rd_addr != 5'd0) && (mem_rd_addr == ex_rs1_addr)) begin
      forward_a = 2'b10; // Forward from EX/MEM
    end else if (wb_reg_write && (wb_rd_addr != 5'd0) && (wb_rd_addr == ex_rs1_addr)) begin
      forward_a = 2'b01; // Forward from MEM/WB
    end else begin
      forward_a = 2'b00; // No forward
    end
  end

  // ---------------------------------------------------------------------------
  // Forwarding Logic for Operand B (rs2)
  // EX/MEM hazard takes precedence over MEM/WB hazard (youngest producer wins).
  // ---------------------------------------------------------------------------
  always_comb begin
    if (mem_reg_write && (mem_rd_addr != 5'd0) && (mem_rd_addr == ex_rs2_addr)) begin
      forward_b = 2'b10; // Forward from EX/MEM
    end else if (wb_reg_write && (wb_rd_addr != 5'd0) && (wb_rd_addr == ex_rs2_addr)) begin
      forward_b = 2'b01; // Forward from MEM/WB
    end else begin
      forward_b = 2'b00; // No forward
    end
  end

endmodule : forwarding_unit
