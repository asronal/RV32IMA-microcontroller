// =============================================================================
// File: tb_immediate_gen.sv
// Description: Comprehensive self-checking unit testbench for Immediate Generator
// Standard: IEEE 1800-2017 SystemVerilog
// =============================================================================

`timescale 1ns / 1ps

module tb_immediate_gen;
  import rv32_pkg::*;

  logic [31:0] instr;
  imm_src_e    imm_src;
  logic [31:0] imm_out;

  int error_count = 0;
  int test_count  = 0;

  // Instantiate DUT
  immediate_gen dut (
    .instr   (instr),
    .imm_src (imm_src),
    .imm_out (imm_out)
  );

  task check_imm(input logic [31:0] expected, input string name);
    #1;
    test_count++;
    if (imm_out !== expected) begin
      $display("[FAIL] %s: instr=0x%08h | EXP=0x%08h | GOT=0x%08h", name, instr, expected, imm_out);
      error_count++;
    end else begin
      $display("[PASS] %s: instr=0x%08h => 0x%08h", name, instr, imm_out);
    end
  endtask

  initial begin
    $display("\n========================================================");
    $display("       STARTING TESTBENCH: tb_immediate_gen");
    $display("========================================================");

    // -------------------------------------------------------------------------
    // Test 1: I-type Immediate
    // -------------------------------------------------------------------------
    imm_src = IMM_SRC_I;
    // Positive immediate: +100 (0x064 in bits 31:20)
    instr = {12'h064, 5'd0, 3'b000, 5'd1, 7'b0010011};
    check_imm(32'd100, "I_TYPE_POS_100");

    // Negative immediate: -1 (0xFFF in bits 31:20)
    instr = {12'hFFF, 5'd0, 3'b000, 5'd1, 7'b0010011};
    check_imm(32'hFFFF_FFFF, "I_TYPE_NEG_1");

    // -------------------------------------------------------------------------
    // Test 2: S-type Immediate
    // -------------------------------------------------------------------------
    imm_src = IMM_SRC_S;
    // Positive immediate: +20 (0x014 -> bits 31:25 = 7'b0000000, bits 11:7 = 5'b10100)
    instr = {7'b0000000, 5'd2, 5'd1, 3'b010, 5'b10100, 7'b0100011};
    check_imm(32'd20, "S_TYPE_POS_20");

    // Negative immediate: -4 (0xFFC -> bits 31:25 = 7'b1111111, bits 11:7 = 5'b11100)
    instr = {7'b1111111, 5'd2, 5'd1, 3'b010, 5'b11100, 7'b0100011};
    check_imm(-32'd4, "S_TYPE_NEG_4");

    // -------------------------------------------------------------------------
    // Test 3: B-type Immediate
    // -------------------------------------------------------------------------
    imm_src = IMM_SRC_B;
    // Positive branch offset: +16 (0x010 -> bit12=0, bit11=0, bits10:5=0, bits4:1=4'b1000)
    // instr[31] = 0
    // instr[7]  = 0
    // instr[30:25] = 6'b000000
    // instr[11:8]  = 4'b1000
    instr = {1'b0, 6'b000000, 5'd2, 5'd1, 3'b000, 4'b1000, 1'b0, 7'b1100011};
    check_imm(32'd16, "B_TYPE_POS_16");

    // Negative branch offset: -8 (0x1FF8 -> bit12=1, bit11=1, bits10:5=6'b111111, bits4:1=4'b1100)
    instr = {1'b1, 6'b111111, 5'd2, 5'd1, 3'b000, 4'b1100, 1'b1, 7'b1100011};
    check_imm(-32'd8, "B_TYPE_NEG_8");

    // -------------------------------------------------------------------------
    // Test 4: U-type Immediate
    // -------------------------------------------------------------------------
    imm_src = IMM_SRC_U;
    // 0x12345 in bits 31:12 -> 0x12345000
    instr = {20'h12345, 5'd1, 7'b0110111};
    check_imm(32'h1234_5000, "U_TYPE_LUI");

    // -------------------------------------------------------------------------
    // Test 5: J-type Immediate
    // -------------------------------------------------------------------------
    imm_src = IMM_SRC_J;
    // Jump offset +2048 (0x000800):
    // bit 20: 0
    // bits 19:12: 8'b00000000
    // bit 11: 1
    // bits 10:1: 10'b0000000000
    instr = {1'b0, 10'b0000000000, 1'b1, 8'b00000000, 5'd1, 7'b1101111};
    check_imm(32'd2048, "J_TYPE_POS_2048");

    // Negative jump offset -4 (0x1FFFFC):
    // bit 20: 1
    // bits 19:12: 8'b11111111
    // bit 11: 1
    // bits 10:1: 10'b1111111110
    instr = {1'b1, 10'b1111111110, 1'b1, 8'b11111111, 5'd1, 7'b1101111};
    check_imm(-32'd4, "J_TYPE_NEG_4");

    // -------------------------------------------------------------------------
    // Test 6: CSR Immediate
    // -------------------------------------------------------------------------
    imm_src = IMM_SRC_CSR;
    // uimm = 5'b11111 (31)
    instr = {12'h300, 5'b11111, 3'b101, 5'd1, 7'b1110011};
    check_imm(32'd31, "CSR_UIMM_31");

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

endmodule : tb_immediate_gen
