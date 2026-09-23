// =============================================================================
// File: branch_unit.sv
// Description: Branch Condition Evaluation and Target Address Generator
// Features:
//   - Purely combinational evaluation of BEQ, BNE, BLT, BGE, BLTU, BGEU
//   - Evaluates unconditional jumps (JAL, JALR)
//   - Calculates PC-relative targets (PC + imm) for Branch/JAL
//   - Calculates register-indirect target ((op_a + imm) & ~1) for JALR
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module branch_unit
  import rv32_pkg::*;
(
  // Branch & Jump Control Inputs
  input  branch_type_e branch_type,
  input  logic         jump,
  input  logic         jump_is_jalr,

  // Program Counter and Immediate from EX stage
  input  logic [31:0]  pc,
  input  logic [31:0]  imm,

  // Operands (Forwarded rs1 and rs2 data)
  input  logic [31:0]  op_a,
  input  logic [31:0]  op_b,

  // Control Flow Outputs to PC and Pipeline Flush Logic
  output logic         branch_taken,
  output logic [31:0]  branch_target
);

  // ---------------------------------------------------------------------------
  // Condition Evaluation
  // Evaluates whether a conditional branch criteria is satisfied.
  // Explicit signed casting ($signed) is used for BLT and BGE.
  // ---------------------------------------------------------------------------
  logic cond_met;

  always_comb begin
    cond_met = 1'b0;

    case (branch_type)
      BRANCH_BEQ:  cond_met = (op_a == op_b);
      BRANCH_BNE:  cond_met = (op_a != op_b);
      BRANCH_BLT:  cond_met = ($signed(op_a) < $signed(op_b));
      BRANCH_BGE:  cond_met = ($signed(op_a) >= $signed(op_b));
      BRANCH_BLTU: cond_met = (op_a < op_b);
      BRANCH_BGEU: cond_met = (op_a >= op_b);
      default:     cond_met = 1'b0;
    endcase
  end

  // Branch is taken if it's an unconditional jump OR a branch condition is met
  assign branch_taken = jump | cond_met;

  // ---------------------------------------------------------------------------
  // Target Address Generation
  // JALR uses (op_a + imm) with LSB masked to 0.
  // Conditional Branches and JAL use (pc + imm).
  // ---------------------------------------------------------------------------
  always_comb begin
    if (jump_is_jalr) begin
      branch_target = (op_a + imm) & 32'hFFFF_FFFE;
    end else begin
      branch_target = pc + imm;
    end
  end

endmodule : branch_unit
