// =============================================================================
// File: tb_branch_unit.sv
// Description: Comprehensive self-checking unit testbench for Branch Unit
// Standard: IEEE 1800-2017 SystemVerilog
// =============================================================================

`timescale 1ns / 1ps

module tb_branch_unit;
  import rv32_pkg::*;

  branch_type_e branch_type;
  logic         jump;
  logic         jump_is_jalr;
  logic [31:0]  pc;
  logic [31:0]  imm;
  logic [31:0]  op_a;
  logic [31:0]  op_b;
  logic         branch_taken;
  logic [31:0]  branch_target;

  int error_count = 0;
  int test_count  = 0;

  // Instantiate DUT
  branch_unit dut (
    .branch_type   (branch_type),
    .jump          (jump),
    .jump_is_jalr  (jump_is_jalr),
    .pc            (pc),
    .imm           (imm),
    .op_a          (op_a),
    .op_b          (op_b),
    .branch_taken  (branch_taken),
    .branch_target (branch_target)
  );

  task check_branch(input logic exp_taken, input logic [31:0] exp_target, input string test_name);
    #1;
    test_count++;
    if (branch_taken !== exp_taken || branch_target !== exp_target) begin
      $display("[FAIL] %s | EXP: taken=%b, tgt=0x%08h | GOT: taken=%b, tgt=0x%08h",
               test_name, exp_taken, exp_target, branch_taken, branch_target);
      error_count++;
    end else begin
      $display("[PASS] %s: taken=%b, target=0x%08h", test_name, branch_taken, branch_target);
    end
  endtask

  initial begin
    branch_type  = BRANCH_NONE;
    jump         = 1'b0;
    jump_is_jalr = 1'b0;
    pc           = 32'h0000_1000;
    imm          = 32'd0;
    op_a         = 32'd0;
    op_b         = 32'd0;

    $display("\n========================================================");
    $display("       STARTING TESTBENCH: tb_branch_unit (Phase 3)");
    $display("========================================================");

    // -------------------------------------------------------------------------
    // Test 1: BEQ
    // -------------------------------------------------------------------------
    branch_type = BRANCH_BEQ;
    pc = 32'h0000_0100; imm = 32'd16;
    op_a = 32'd42; op_b = 32'd42;
    check_branch(1'b1, 32'h0000_0110, "BEQ_EQUAL_TAKEN");

    op_a = 32'd42; op_b = 32'd43;
    check_branch(1'b0, 32'h0000_0110, "BEQ_NOT_EQUAL_NOT_TAKEN");

    // -------------------------------------------------------------------------
    // Test 2: BNE
    // -------------------------------------------------------------------------
    branch_type = BRANCH_BNE;
    op_a = 32'd10; op_b = 32'd20;
    check_branch(1'b1, 32'h0000_0110, "BNE_NOT_EQUAL_TAKEN");

    op_a = 32'd20; op_b = 32'd20;
    check_branch(1'b0, 32'h0000_0110, "BNE_EQUAL_NOT_TAKEN");

    // -------------------------------------------------------------------------
    // Test 3: BLT (Signed)
    // -------------------------------------------------------------------------
    branch_type = BRANCH_BLT;
    op_a = -32'd10; op_b = 32'd5;
    check_branch(1'b1, 32'h0000_0110, "BLT_NEG_LT_POS_TAKEN");

    op_a = 32'd5; op_b = -32'd10;
    check_branch(1'b0, 32'h0000_0110, "BLT_POS_LT_NEG_NOT_TAKEN");

    op_a = -32'd20; op_b = -32'd10;
    check_branch(1'b1, 32'h0000_0110, "BLT_NEG_LT_NEG_TAKEN");

    // -------------------------------------------------------------------------
    // Test 4: BGE (Signed)
    // -------------------------------------------------------------------------
    branch_type = BRANCH_BGE;
    op_a = 32'd5; op_b = -32'd10;
    check_branch(1'b1, 32'h0000_0110, "BGE_POS_GE_NEG_TAKEN");

    op_a = -32'd10; op_b = 32'd5;
    check_branch(1'b0, 32'h0000_0110, "BGE_NEG_GE_POS_NOT_TAKEN");

    op_a = 32'd10; op_b = 32'd10;
    check_branch(1'b1, 32'h0000_0110, "BGE_EQUAL_TAKEN");

    // -------------------------------------------------------------------------
    // Test 5: BLTU (Unsigned)
    // -------------------------------------------------------------------------
    branch_type = BRANCH_BLTU;
    op_a = 32'd5; op_b = 32'hFFFF_FFFF;
    check_branch(1'b1, 32'h0000_0110, "BLTU_5_LT_ALLONES_TAKEN");

    op_a = 32'hFFFF_FFFF; op_b = 32'd5;
    check_branch(1'b0, 32'h0000_0110, "BLTU_ALLONES_LT_5_NOT_TAKEN");

    // -------------------------------------------------------------------------
    // Test 6: BGEU (Unsigned)
    // -------------------------------------------------------------------------
    branch_type = BRANCH_BGEU;
    op_a = 32'hFFFF_FFFF; op_b = 32'd5;
    check_branch(1'b1, 32'h0000_0110, "BGEU_ALLONES_GE_5_TAKEN");

    op_a = 32'd5; op_b = 32'hFFFF_FFFF;
    check_branch(1'b0, 32'h0000_0110, "BGEU_5_GE_ALLONES_NOT_TAKEN");

    // -------------------------------------------------------------------------
    // Test 7: JAL (Unconditional Jump PC + imm)
    // -------------------------------------------------------------------------
    branch_type  = BRANCH_NONE;
    jump         = 1'b1;
    jump_is_jalr = 1'b0;
    pc           = 32'h0000_0200;
    imm          = 32'h0000_0080;
    check_branch(1'b1, 32'h0000_0280, "JAL_POS_OFFSET");

    imm = -32'd16;
    check_branch(1'b1, 32'h0000_01F0, "JAL_NEG_OFFSET");

    // -------------------------------------------------------------------------
    // Test 8: JALR (Target = (op_a + imm) & ~1)
    // -------------------------------------------------------------------------
    jump_is_jalr = 1'b1;
    op_a         = 32'h1000_0001; // Odd address
    imm          = 32'd4;
    // 0x1000_0001 + 4 = 0x1000_0005 -> & ~1 = 0x1000_0004
    check_branch(1'b1, 32'h1000_0004, "JALR_LSB_CLEAR");

    // -------------------------------------------------------------------------
    // Summary
    // -------------------------------------------------------------------------
    $display("========================================================");
    if (error_count == 0) begin
      $display(" >>> ALL %0d TESTS PASSED SUCCESSFULLY! <<<", test_count);
    end else begin
      $display(" >>> FAILED: %0d / %0d TESTS FAILED! <<<", error_count, test_count);
    end
    $display("========================================================\n");
    $finish;
  end

endmodule : tb_branch_unit
