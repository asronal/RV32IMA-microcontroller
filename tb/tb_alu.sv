// =============================================================================
// File: tb_alu.sv
// Description: Comprehensive self-checking unit testbench for 32-bit ALU
// Standard: IEEE 1800-2017 SystemVerilog
// =============================================================================

`timescale 1ns / 1ps

module tb_alu;
  import rv32_pkg::*;

  logic [31:0]   op_a;
  logic [31:0]   op_b;
  alu_op_e       alu_op;
  logic [31:0]   result;
  logic          zero;

  int error_count = 0;
  int test_count  = 0;

  // Instantiate ALU DUT
  alu dut (
    .op_a   (op_a),
    .op_b   (op_b),
    .alu_op (alu_op),
    .result (result),
    .zero   (zero)
  );

  // Check task
  task check_result(input logic [31:0] exp_result, input logic exp_zero, input string op_name);
    #1;
    test_count++;
    if (result !== exp_result || zero !== exp_zero) begin
      $display("[FAIL] %s: op_a=0x%08h, op_b=0x%08h | EXP: res=0x%08h z=%b | GOT: res=0x%08h z=%b",
               op_name, op_a, op_b, exp_result, exp_zero, result, zero);
      error_count++;
    end else begin
      $display("[PASS] %s: op_a=0x%08h, op_b=0x%08h => res=0x%08h z=%b",
               op_name, op_a, op_b, result, zero);
    end
  endtask

  initial begin
    $display("\n========================================================");
    $display("           STARTING TESTBENCH: tb_alu");
    $display("========================================================");

    // -------------------------------------------------------------------------
    // Test ADD
    // -------------------------------------------------------------------------
    alu_op = ALU_ADD;
    op_a = 32'd15;  op_b = 32'd25;          check_result(32'd40, 1'b0, "ADD_POS");
    op_a = 32'd10;  op_b = -32'd10;         check_result(32'd0,  1'b1, "ADD_ZERO");
    op_a = 32'hFFFF_FFFF; op_b = 32'd1;     check_result(32'd0,  1'b1, "ADD_OVERFLOW");
    op_a = 32'h7FFF_FFFF; op_b = 32'd1;     check_result(32'h8000_0000, 1'b0, "ADD_POS_TO_NEG");

    // -------------------------------------------------------------------------
    // Test SUB
    // -------------------------------------------------------------------------
    alu_op = ALU_SUB;
    op_a = 32'd50;  op_b = 32'd20;          check_result(32'd30, 1'b0, "SUB_POS");
    op_a = 32'd25;  op_b = 32'd25;          check_result(32'd0,  1'b1, "SUB_ZERO");
    op_a = 32'd0;   op_b = 32'd1;           check_result(32'hFFFF_FFFF, 1'b0, "SUB_UNDERFLOW");

    // -------------------------------------------------------------------------
    // Test AND, OR, XOR
    // -------------------------------------------------------------------------
    alu_op = ALU_AND;
    op_a = 32'hF0F0_AAAA; op_b = 32'h0F0F_FFFF; check_result(32'h0000_AAAA, 1'b0, "AND");
    alu_op = ALU_OR;
    op_a = 32'hF0F0_0000; op_b = 32'h0000_AAAA; check_result(32'hF0F0_AAAA, 1'b0, "OR");
    alu_op = ALU_XOR;
    op_a = 32'hFFFF_AAAA; op_b = 32'hFFFF_5555; check_result(32'h0000_FFFF, 1'b0, "XOR");
    op_a = 32'h1234_5678; op_b = 32'h1234_5678; check_result(32'd0, 1'b1, "XOR_SAME_ZERO");

    // -------------------------------------------------------------------------
    // Test SLL, SRL, SRA
    // -------------------------------------------------------------------------
    alu_op = ALU_SLL;
    op_a = 32'h0000_0001; op_b = 32'd4;     check_result(32'h0000_0010, 1'b0, "SLL_4");
    op_a = 32'h0000_0001; op_b = 32'd35;    check_result(32'h0000_0008, 1'b0, "SLL_35_MASKED_TO_3");

    alu_op = ALU_SRL;
    op_a = 32'h8000_0000; op_b = 32'd4;     check_result(32'h0800_0000, 1'b0, "SRL_LOGICAL");

    alu_op = ALU_SRA;
    op_a = 32'h8000_0000; op_b = 32'd4;     check_result(32'hF800_0000, 1'b0, "SRA_ARITH_NEG");
    op_a = 32'h7000_0000; op_b = 32'd4;     check_result(32'h0700_0000, 1'b0, "SRA_ARITH_POS");

    // -------------------------------------------------------------------------
    // Test SLT (Signed comparison)
    // -------------------------------------------------------------------------
    alu_op = ALU_SLT;
    op_a = -32'd10; op_b = 32'd5;           check_result(32'd1, 1'b0, "SLT_NEG_LT_POS");
    op_a = 32'd5;   op_b = -32'd10;          check_result(32'd0, 1'b1, "SLT_POS_GT_NEG");
    op_a = -32'd20; op_b = -32'd10;         check_result(32'd1, 1'b0, "SLT_NEG_LT_NEG");
    op_a = 32'd10;  op_b = 32'd10;          check_result(32'd0, 1'b1, "SLT_EQUAL");

    // -------------------------------------------------------------------------
    // Test SLTU (Unsigned comparison)
    // -------------------------------------------------------------------------
    alu_op = ALU_SLTU;
    op_a = 32'd5;   op_b = 32'hFFFF_FFFF;   check_result(32'd1, 1'b0, "SLTU_5_LT_ALLONES");
    op_a = 32'hFFFF_FFFF; op_b = 32'd5;     check_result(32'd0, 1'b1, "SLTU_ALLONES_GT_5");
    op_a = 32'd100; op_b = 32'd100;         check_result(32'd0, 1'b1, "SLTU_EQUAL");

    // -------------------------------------------------------------------------
    // Test COPY_B
    // -------------------------------------------------------------------------
    alu_op = ALU_COPY_B;
    op_a = 32'h1234_5678; op_b = 32'hDEAD_BEEF; check_result(32'hDEAD_BEEF, 1'b0, "COPY_B");

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

endmodule : tb_alu
