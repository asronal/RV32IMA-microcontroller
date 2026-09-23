// =============================================================================
// File: tb_forwarding_unit.sv
// Description: Comprehensive self-checking unit testbench for Forwarding Unit
// Standard: IEEE 1800-2017 SystemVerilog
// =============================================================================

`timescale 1ns / 1ps

module tb_forwarding_unit;

  logic [4:0] ex_rs1_addr;
  logic [4:0] ex_rs2_addr;
  logic       mem_reg_write;
  logic [4:0] mem_rd_addr;
  logic       wb_reg_write;
  logic [4:0] wb_rd_addr;
  logic [1:0] forward_a;
  logic [1:0] forward_b;

  int error_count = 0;
  int test_count  = 0;

  // Instantiate DUT
  forwarding_unit dut (
    .ex_rs1_addr   (ex_rs1_addr),
    .ex_rs2_addr   (ex_rs2_addr),
    .mem_reg_write (mem_reg_write),
    .mem_rd_addr   (mem_rd_addr),
    .wb_reg_write  (wb_reg_write),
    .wb_rd_addr    (wb_rd_addr),
    .forward_a     (forward_a),
    .forward_b     (forward_b)
  );

  task check_fwd(input logic [1:0] exp_a, input logic [1:0] exp_b, input string test_name);
    #1;
    test_count++;
    if (forward_a !== exp_a || forward_b !== exp_b) begin
      $display("[FAIL] %s | EXP: a=%b, b=%b | GOT: a=%b, b=%b",
               test_name, exp_a, exp_b, forward_a, forward_b);
      error_count++;
    end else begin
      $display("[PASS] %s: forward_a=%b, forward_b=%b", test_name, forward_a, forward_b);
    end
  endtask

  initial begin
    ex_rs1_addr   = 5'd0;
    ex_rs2_addr   = 5'd0;
    mem_reg_write = 1'b0;
    mem_rd_addr   = 5'd0;
    wb_reg_write  = 1'b0;
    wb_rd_addr    = 5'd0;

    $display("\n========================================================");
    $display("    STARTING TESTBENCH: tb_forwarding_unit (Phase 4)");
    $display("========================================================");

    // -------------------------------------------------------------------------
    // Test 1: No Hazards
    // -------------------------------------------------------------------------
    ex_rs1_addr = 5'd1; ex_rs2_addr = 5'd2;
    check_fwd(2'b00, 2'b00, "NO_HAZARD");

    // -------------------------------------------------------------------------
    // Test 2: EX/MEM Forwarding to Operand A
    // -------------------------------------------------------------------------
    mem_reg_write = 1'b1; mem_rd_addr = 5'd1;
    check_fwd(2'b10, 2'b00, "EX_MEM_FORWARD_A");

    // -------------------------------------------------------------------------
    // Test 3: MEM/WB Forwarding to Operand A
    // -------------------------------------------------------------------------
    mem_reg_write = 1'b0; mem_rd_addr = 5'd0;
    wb_reg_write  = 1'b1; wb_rd_addr  = 5'd1;
    check_fwd(2'b01, 2'b00, "MEM_WB_FORWARD_A");

    // -------------------------------------------------------------------------
    // Test 4: EX/MEM Forwarding to Operand B
    // -------------------------------------------------------------------------
    wb_reg_write  = 1'b0; wb_rd_addr  = 5'd0;
    mem_reg_write = 1'b1; mem_rd_addr = 5'd2;
    check_fwd(2'b00, 2'b10, "EX_MEM_FORWARD_B");

    // -------------------------------------------------------------------------
    // Test 5: MEM/WB Forwarding to Operand B
    // -------------------------------------------------------------------------
    mem_reg_write = 1'b0; mem_rd_addr = 5'd0;
    wb_reg_write  = 1'b1; wb_rd_addr  = 5'd2;
    check_fwd(2'b00, 2'b01, "MEM_WB_FORWARD_B");

    // -------------------------------------------------------------------------
    // Test 6: Simultaneous Forwarding (EX/MEM on A, MEM/WB on B)
    // -------------------------------------------------------------------------
    mem_reg_write = 1'b1; mem_rd_addr = 5'd1;
    wb_reg_write  = 1'b1; wb_rd_addr  = 5'd2;
    check_fwd(2'b10, 2'b01, "SIMULTANEOUS_FWD_A_AND_B");

    // -------------------------------------------------------------------------
    // Test 7: Priority Test (EX/MEM must override MEM/WB when both match)
    // -------------------------------------------------------------------------
    ex_rs1_addr   = 5'd10;
    mem_reg_write = 1'b1; mem_rd_addr = 5'd10; // Younger producer
    wb_reg_write  = 1'b1; wb_rd_addr  = 5'd10; // Older producer
    check_fwd(2'b10, 2'b00, "EX_MEM_PRIORITY_OVER_MEM_WB");

    // -------------------------------------------------------------------------
    // Test 8: Register x0 Protection (Must NEVER forward x0)
    // -------------------------------------------------------------------------
    ex_rs1_addr   = 5'd0;
    ex_rs2_addr   = 5'd0;
    mem_reg_write = 1'b1; mem_rd_addr = 5'd0;
    wb_reg_write  = 1'b1; wb_rd_addr  = 5'd0;
    check_fwd(2'b00, 2'b00, "X0_NO_FORWARDING");

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

endmodule : tb_forwarding_unit
