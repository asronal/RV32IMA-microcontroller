// =============================================================================
// File: tb_hazard_unit.sv
// Description: Comprehensive self-checking unit testbench for Hazard Unit
// Standard: IEEE 1800-2017 SystemVerilog
// =============================================================================

`timescale 1ns / 1ps

module tb_hazard_unit;

  logic [4:0] id_rs1_addr;
  logic [4:0] id_rs2_addr;
  logic       id_rs1_used;
  logic       id_rs2_used;
  logic       ex_mem_read;
  logic [4:0] ex_rd_addr;
  logic       branch_taken;
  logic       stall_pc;
  logic       stall_if_id;
  logic       flush_if_id;
  logic       flush_id_ex;

  int error_count = 0;
  int test_count  = 0;

  // Instantiate DUT
  hazard_unit dut (
    .id_rs1_addr  (id_rs1_addr),
    .id_rs2_addr  (id_rs2_addr),
    .id_rs1_used  (id_rs1_used),
    .id_rs2_used  (id_rs2_used),
    .ex_mem_read  (ex_mem_read),
    .ex_rd_addr   (ex_rd_addr),
    .branch_taken (branch_taken),
    .stall_pc     (stall_pc),
    .stall_if_id  (stall_if_id),
    .flush_if_id  (flush_if_id),
    .flush_id_ex  (flush_id_ex)
  );

  task check_hazard(
    input logic exp_stall_pc,
    input logic exp_stall_if_id,
    input logic exp_flush_if_id,
    input logic exp_flush_id_ex,
    input string test_name
  );
    #1;
    test_count++;
    if (stall_pc !== exp_stall_pc || stall_if_id !== exp_stall_if_id ||
        flush_if_id !== exp_flush_if_id || flush_id_ex !== exp_flush_id_ex) begin
      $display("[FAIL] %s | EXP: st_pc=%b, st_ifid=%b, fl_ifid=%b, fl_idex=%b | GOT: st_pc=%b, st_ifid=%b, fl_ifid=%b, fl_idex=%b",
               test_name, exp_stall_pc, exp_stall_if_id, exp_flush_if_id, exp_flush_id_ex,
               stall_pc, stall_if_id, flush_if_id, flush_id_ex);
      error_count++;
    end else begin
      $display("[PASS] %s: stall_pc=%b, stall_if_id=%b, flush_if_id=%b, flush_id_ex=%b",
               test_name, stall_pc, stall_if_id, flush_if_id, flush_id_ex);
    end
  endtask

  initial begin
    id_rs1_addr  = 5'd0;
    id_rs2_addr  = 5'd0;
    id_rs1_used  = 1'b0;
    id_rs2_used  = 1'b0;
    ex_mem_read  = 1'b0;
    ex_rd_addr   = 5'd0;
    branch_taken = 1'b0;

    $display("\n========================================================");
    $display("      STARTING TESTBENCH: tb_hazard_unit (Phase 4)");
    $display("========================================================");

    // -------------------------------------------------------------------------
    // Test 1: Normal execution (No hazards)
    // -------------------------------------------------------------------------
    id_rs1_addr = 5'd1; id_rs1_used = 1'b1;
    id_rs2_addr = 5'd2; id_rs2_used = 1'b1;
    ex_mem_read = 1'b0; ex_rd_addr  = 5'd3;
    check_hazard(1'b0, 1'b0, 1'b0, 1'b0, "NO_HAZARD");

    // -------------------------------------------------------------------------
    // Test 2: Load-Use Hazard on rs1
    // -------------------------------------------------------------------------
    ex_mem_read = 1'b1; ex_rd_addr = 5'd1; // Load into x1
    id_rs1_addr = 5'd1; id_rs1_used = 1'b1; // Consumes x1
    check_hazard(1'b1, 1'b1, 1'b0, 1'b1, "LOAD_USE_RS1");

    // -------------------------------------------------------------------------
    // Test 3: Load-Use Hazard on rs2
    // -------------------------------------------------------------------------
    id_rs1_addr = 5'd4; id_rs1_used = 1'b1;
    id_rs2_addr = 5'd1; id_rs2_used = 1'b1; // Consumes x1
    check_hazard(1'b1, 1'b1, 1'b0, 1'b1, "LOAD_USE_RS2");

    // -------------------------------------------------------------------------
    // Test 4: No Load-Use if operand is not used
    // -------------------------------------------------------------------------
    id_rs2_used = 1'b0; // e.g. I-type ALU does not use rs2
    check_hazard(1'b0, 1'b0, 1'b0, 1'b0, "NO_LOAD_USE_WHEN_RS2_UNUSED");

    // -------------------------------------------------------------------------
    // Test 5: No Load-Use if destination is x0
    // -------------------------------------------------------------------------
    ex_rd_addr = 5'd0;
    id_rs1_addr = 5'd0; id_rs1_used = 1'b1;
    check_hazard(1'b0, 1'b0, 1'b0, 1'b0, "NO_LOAD_USE_X0");

    // -------------------------------------------------------------------------
    // Test 6: Branch Taken (Control Hazard)
    // -------------------------------------------------------------------------
    ex_mem_read  = 1'b0;
    branch_taken = 1'b1;
    check_hazard(1'b0, 1'b0, 1'b1, 1'b1, "BRANCH_TAKEN_FLUSH");

    // -------------------------------------------------------------------------
    // Test 7: Branch Priority over Load-Use Hazard
    // -------------------------------------------------------------------------
    ex_mem_read = 1'b1; ex_rd_addr = 5'd5;
    id_rs1_addr = 5'd5; id_rs1_used = 1'b1;
    branch_taken = 1'b1;
    // Branch flush must win over stall
    check_hazard(1'b0, 1'b0, 1'b1, 1'b1, "BRANCH_PRIORITY_OVER_LOAD_USE");

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

endmodule : tb_hazard_unit
