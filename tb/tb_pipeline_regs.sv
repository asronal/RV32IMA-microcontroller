// =============================================================================
// File: tb_pipeline_regs.sv
// Description: Comprehensive self-checking testbench for PC and Pipeline Registers
// Tests: pc_reg, if_id, id_ex, ex_mem, mem_wb
// Standard: IEEE 1800-2017 SystemVerilog
// =============================================================================

`timescale 1ns / 1ps

module tb_pipeline_regs;
  import rv32_pkg::*;

  logic        clk;
  logic        rst_n;

  // PC signals
  logic        pc_stall;
  logic        branch_taken;
  logic [31:0] branch_target;
  logic [31:0] pc_curr;
  logic [31:0] pc_plus4;

  // Pipeline flow controls
  logic if_id_stall,  if_id_flush;
  logic id_ex_stall,  id_ex_flush;
  logic ex_mem_stall, ex_mem_flush;
  logic mem_wb_stall, mem_wb_flush;

  // IF/ID signals
  logic [31:0] if_pc, if_pc4, if_instr;
  logic        if_valid;
  logic [31:0] id_pc, id_pc4, id_instr;
  logic        id_valid;

  // ID/EX signals
  logic [31:0] id_rs1_data, id_rs2_data, id_imm;
  logic [4:0]  id_rs1_addr, id_rs2_addr, id_rd_addr;
  alu_op_e     id_alu_op;
  alu_src_a_e  id_alu_src_a;
  alu_src_b_e  id_alu_src_b;
  branch_type_e id_branch_type;
  logic        id_jump, id_jump_is_jalr;
  logic        id_mem_read, id_mem_write, id_mem_unsigned, id_reg_write;
  mem_size_e   id_mem_size;
  wb_src_e     id_wb_src;
  logic        id_is_atomic, id_is_csr, id_is_mret, id_is_wfi, id_is_ecall, id_is_ebreak, id_illegal_instr;
  amo_op_e     id_amo_op;

  logic [31:0] ex_pc, ex_pc4, ex_rs1_data, ex_rs2_data, ex_imm;
  logic [4:0]  ex_rs1_addr, ex_rs2_addr, ex_rd_addr;
  alu_op_e     ex_alu_op;
  alu_src_a_e  ex_alu_src_a;
  alu_src_b_e  ex_alu_src_b;
  branch_type_e ex_branch_type;
  logic        ex_jump, ex_jump_is_jalr;
  logic        ex_mem_read, ex_mem_write, ex_mem_unsigned, ex_reg_write;
  mem_size_e   ex_mem_size;
  wb_src_e     ex_wb_src;
  logic        ex_is_atomic, ex_is_csr, ex_is_mret, ex_is_wfi, ex_is_ecall, ex_is_ebreak, ex_illegal_instr;
  amo_op_e     ex_amo_op;
  logic        ex_valid;

  // EX/MEM signals
  logic [31:0] ex_alu_result;
  logic [31:0] mem_pc, mem_pc4, mem_alu_result, mem_rs2_data;
  logic [4:0]  mem_rd_addr;
  logic        mem_mem_read, mem_mem_write, mem_mem_unsigned, mem_reg_write;
  mem_size_e   mem_mem_size;
  wb_src_e     mem_wb_src;
  logic        mem_is_atomic, mem_is_csr, mem_is_mret, mem_is_wfi, mem_is_ecall, mem_is_ebreak, mem_illegal_instr;
  amo_op_e     mem_amo_op;
  logic        mem_valid;

  // MEM/WB signals
  logic [31:0] mem_rdata;
  logic [31:0] wb_pc4, wb_alu_result, wb_rdata;
  logic [4:0]  wb_rd_addr;
  logic        wb_reg_write;
  wb_src_e     wb_wb_src;
  logic        wb_valid;

  int error_count = 0;
  int test_count  = 0;

  // Clock generation (10ns period)
  always #5 clk = ~clk;

  // ---------------------------------------------------------------------------
  // DUT Instantiations
  // ---------------------------------------------------------------------------
  pc_reg #(
    .RESET_VECTOR(32'h0000_0000)
  ) u_pc_reg (
    .clk          (clk),
    .rst_n        (rst_n),
    .stall        (pc_stall),
    .branch_taken (branch_taken),
    .branch_target(branch_target),
    .pc_curr      (pc_curr),
    .pc_plus4     (pc_plus4)
  );

  if_id u_if_id (
    .clk      (clk),
    .rst_n    (rst_n),
    .stall    (if_id_stall),
    .flush    (if_id_flush),
    .if_pc    (if_pc),
    .if_pc4   (if_pc4),
    .if_instr (if_instr),
    .if_valid (if_valid),
    .id_pc    (id_pc),
    .id_pc4   (id_pc4),
    .id_instr (id_instr),
    .id_valid (id_valid)
  );

  id_ex u_id_ex (
    .clk              (clk),
    .rst_n            (rst_n),
    .stall            (id_ex_stall),
    .flush            (id_ex_flush),
    .id_pc            (id_pc),
    .id_pc4           (id_pc4),
    .id_rs1_data      (id_rs1_data),
    .id_rs2_data      (id_rs2_data),
    .id_rs1_addr      (id_rs1_addr),
    .id_rs2_addr      (id_rs2_addr),
    .id_rd_addr       (id_rd_addr),
    .id_imm           (id_imm),
    .id_alu_op        (id_alu_op),
    .id_alu_src_a     (id_alu_src_a),
    .id_alu_src_b     (id_alu_src_b),
    .id_branch_type   (id_branch_type),
    .id_jump          (id_jump),
    .id_jump_is_jalr  (id_jump_is_jalr),
    .id_mem_read      (id_mem_read),
    .id_mem_write     (id_mem_write),
    .id_mem_size      (id_mem_size),
    .id_mem_unsigned  (id_mem_unsigned),
    .id_reg_write     (id_reg_write),
    .id_wb_src        (id_wb_src),
    .id_is_atomic     (id_is_atomic),
    .id_amo_op        (id_amo_op),
    .id_is_csr        (id_is_csr),
    .id_is_mret       (id_is_mret),
    .id_is_wfi        (id_is_wfi),
    .id_is_ecall      (id_is_ecall),
    .id_is_ebreak     (id_is_ebreak),
    .id_illegal_instr (id_illegal_instr),
    .id_valid         (id_valid),
    .ex_pc            (ex_pc),
    .ex_pc4           (ex_pc4),
    .ex_rs1_data      (ex_rs1_data),
    .ex_rs2_data      (ex_rs2_data),
    .ex_rs1_addr      (ex_rs1_addr),
    .ex_rs2_addr      (ex_rs2_addr),
    .ex_rd_addr       (ex_rd_addr),
    .ex_imm           (ex_imm),
    .ex_alu_op        (ex_alu_op),
    .ex_alu_src_a     (ex_alu_src_a),
    .ex_alu_src_b     (ex_alu_src_b),
    .ex_branch_type   (ex_branch_type),
    .ex_jump          (ex_jump),
    .ex_jump_is_jalr  (ex_jump_is_jalr),
    .ex_mem_read      (ex_mem_read),
    .ex_mem_write     (ex_mem_write),
    .ex_mem_size      (ex_mem_size),
    .ex_mem_unsigned  (ex_mem_unsigned),
    .ex_reg_write     (ex_reg_write),
    .ex_wb_src        (ex_wb_src),
    .ex_is_atomic     (ex_is_atomic),
    .ex_amo_op        (ex_amo_op),
    .ex_is_csr        (ex_is_csr),
    .ex_is_mret       (ex_is_mret),
    .ex_is_wfi        (ex_is_wfi),
    .ex_is_ecall      (ex_is_ecall),
    .ex_is_ebreak     (ex_is_ebreak),
    .ex_illegal_instr (ex_illegal_instr),
    .ex_valid         (ex_valid)
  );

  ex_mem u_ex_mem (
    .clk              (clk),
    .rst_n            (rst_n),
    .stall            (ex_mem_stall),
    .flush            (ex_mem_flush),
    .ex_pc            (ex_pc),
    .ex_pc4           (ex_pc4),
    .ex_alu_result    (ex_alu_result),
    .ex_rs2_data      (ex_rs2_data),
    .ex_rd_addr       (ex_rd_addr),
    .ex_mem_read      (ex_mem_read),
    .ex_mem_write     (ex_mem_write),
    .ex_mem_size      (ex_mem_size),
    .ex_mem_unsigned  (ex_mem_unsigned),
    .ex_reg_write     (ex_reg_write),
    .ex_wb_src        (ex_wb_src),
    .ex_is_atomic     (ex_is_atomic),
    .ex_amo_op        (ex_amo_op),
    .ex_is_csr        (ex_is_csr),
    .ex_is_mret       (ex_is_mret),
    .ex_is_wfi        (ex_is_wfi),
    .ex_is_ecall      (ex_is_ecall),
    .ex_is_ebreak     (ex_is_ebreak),
    .ex_illegal_instr (ex_illegal_instr),
    .ex_valid         (ex_valid),
    .mem_pc           (mem_pc),
    .mem_pc4          (mem_pc4),
    .mem_alu_result   (mem_alu_result),
    .mem_rs2_data     (mem_rs2_data),
    .mem_rd_addr      (mem_rd_addr),
    .mem_mem_read     (mem_mem_read),
    .mem_mem_write    (mem_mem_write),
    .mem_mem_size     (mem_mem_size),
    .mem_mem_unsigned (mem_mem_unsigned),
    .mem_reg_write    (mem_reg_write),
    .mem_wb_src       (mem_wb_src),
    .mem_is_atomic    (mem_is_atomic),
    .mem_amo_op       (mem_amo_op),
    .mem_is_csr       (mem_is_csr),
    .mem_is_mret      (mem_is_mret),
    .mem_is_wfi       (mem_is_wfi),
    .mem_is_ecall     (mem_is_ecall),
    .mem_is_ebreak    (mem_is_ebreak),
    .mem_illegal_instr(mem_illegal_instr),
    .mem_valid        (mem_valid)
  );

  mem_wb u_mem_wb (
    .clk           (clk),
    .rst_n         (rst_n),
    .stall         (mem_wb_stall),
    .flush         (mem_wb_flush),
    .mem_pc4       (mem_pc4),
    .mem_alu_result(mem_alu_result),
    .mem_rdata     (mem_rdata),
    .mem_rd_addr   (mem_rd_addr),
    .mem_reg_write (mem_reg_write),
    .mem_wb_src    (mem_wb_src),
    .mem_valid     (mem_valid),
    .wb_pc4        (wb_pc4),
    .wb_alu_result (wb_alu_result),
    .wb_rdata      (wb_rdata),
    .wb_rd_addr    (wb_rd_addr),
    .wb_reg_write  (wb_reg_write),
    .wb_wb_src     (wb_wb_src),
    .wb_valid      (wb_valid)
  );

  task check_cond(input logic condition, input string test_name);
    #1;
    test_count++;
    if (!condition) begin
      $display("[FAIL] %s", test_name);
      error_count++;
    end else begin
      $display("[PASS] %s", test_name);
    end
  endtask

  initial begin
    clk          = 1'b0;
    rst_n        = 1'b0;
    pc_stall     = 1'b0;
    branch_taken = 1'b0;
    branch_target= 32'd0;

    if_id_stall  = 1'b0; if_id_flush  = 1'b0;
    id_ex_stall  = 1'b0; id_ex_flush  = 1'b0;
    ex_mem_stall = 1'b0; ex_mem_flush = 1'b0;
    mem_wb_stall = 1'b0; mem_wb_flush = 1'b0;

    if_pc        = 32'd0; if_pc4   = 32'd4; if_instr = 32'h0000_0013; if_valid = 1'b0;
    id_rs1_data  = 32'd0; id_rs2_data = 32'd0; id_imm = 32'd0;
    id_rs1_addr  = 5'd0;  id_rs2_addr = 5'd0;  id_rd_addr = 5'd0;
    id_alu_op    = ALU_ADD; id_alu_src_a = ALU_SRC_A_RS1; id_alu_src_b = ALU_SRC_B_RS2;
    id_branch_type = BRANCH_NONE; id_jump = 1'b0; id_jump_is_jalr = 1'b0;
    id_mem_read  = 1'b0; id_mem_write = 1'b0; id_mem_size = MEM_SIZE_WORD; id_mem_unsigned = 1'b0;
    id_reg_write = 1'b0; id_wb_src = WB_SRC_ALU;
    id_is_atomic = 1'b0; id_amo_op = AMO_OP_NONE; id_is_csr = 1'b0; id_is_mret = 1'b0;
    id_is_wfi    = 1'b0; id_is_ecall = 1'b0; id_is_ebreak = 1'b0; id_illegal_instr = 1'b0;
    ex_alu_result = 32'd0; mem_rdata = 32'd0;

    $display("\n========================================================");
    $display("     STARTING TESTBENCH: tb_pipeline_regs (Phase 2)");
    $display("========================================================");

    // Apply Reset
    #12;
    rst_n = 1'b1;
    #1;

    // -------------------------------------------------------------------------
    // Test 1: PC Reset and Sequential Increment
    // -------------------------------------------------------------------------
    check_cond(pc_curr == 32'h0000_0000, "PC_RESET_0");
    @(posedge clk); #1;
    check_cond(pc_curr == 32'h0000_0004, "PC_INCREMENT_4");
    @(posedge clk); #1;
    check_cond(pc_curr == 32'h0000_0008, "PC_INCREMENT_8");

    // -------------------------------------------------------------------------
    // Test 2: PC Stall
    // -------------------------------------------------------------------------
    pc_stall <= 1'b1;
    @(posedge clk); #1;
    check_cond(pc_curr == 32'h0000_0008, "PC_STALL_HOLD_1");
    @(posedge clk); #1;
    check_cond(pc_curr == 32'h0000_0008, "PC_STALL_HOLD_2");
    pc_stall <= 1'b0;

    // -------------------------------------------------------------------------
    // Test 3: PC Branch Redirection
    // -------------------------------------------------------------------------
    branch_taken  <= 1'b1;
    branch_target <= 32'h0000_1000;
    @(posedge clk); #1;
    check_cond(pc_curr == 32'h0000_1000, "PC_BRANCH_REDIRECT");
    branch_taken  <= 1'b0;
    @(posedge clk); #1;
    check_cond(pc_curr == 32'h0000_1004, "PC_POST_BRANCH_INCREMENT");

    // -------------------------------------------------------------------------
    // Test 4: Pipeline Data Propagation (IF -> ID -> EX -> MEM -> WB)
    // -------------------------------------------------------------------------
    $display("\n--- [Test 4] Pipeline Data Propagation ---");
    // Cycle 0: Feed token into IF
    @(posedge clk);
    if_pc    <= 32'h0000_0020;
    if_pc4   <= 32'h0000_0024;
    if_instr <= 32'h1234_5678;
    if_valid <= 1'b1;

    // Cycle 1: Token in ID
    @(posedge clk);
    if_valid <= 1'b0; // Single pulse token
    #1;
    check_cond(id_valid && (id_pc == 32'h0000_0020) && (id_instr == 32'h1234_5678), "TOKEN_IN_ID");

    // Configure ID outputs for next stage
    id_rs1_data   <= 32'hAAAA_BBBB;
    id_rd_addr    <= 5'd7;
    id_reg_write  <= 1'b1;
    id_alu_op     <= ALU_ADD;

    // Cycle 2: Token in EX
    @(posedge clk); #1;
    check_cond(ex_valid && (ex_pc == 32'h0000_0020) && (ex_rd_addr == 5'd7) &&
               (ex_rs1_data == 32'hAAAA_BBBB) && ex_reg_write, "TOKEN_IN_EX");

    // Configure EX outputs for MEM
    ex_alu_result <= 32'h5555_6666;

    // Cycle 3: Token in MEM
    @(posedge clk); #1;
    check_cond(mem_valid && (mem_alu_result == 32'h5555_6666) && (mem_rd_addr == 5'd7) &&
               mem_reg_write, "TOKEN_IN_MEM");

    // Cycle 4: Token in WB
    @(posedge clk); #1;
    check_cond(wb_valid && (wb_alu_result == 32'h5555_6666) && (wb_rd_addr == 5'd7) &&
               wb_reg_write, "TOKEN_IN_WB");

    // -------------------------------------------------------------------------
    // Test 5: Pipeline Stall
    // -------------------------------------------------------------------------
    $display("\n--- [Test 5] Pipeline Stall ---");
    @(posedge clk);
    if_pc       <= 32'h0000_0040;
    if_instr    <= 32'hAABB_CCDD;
    if_valid    <= 1'b1;
    @(posedge clk);
    if_valid    <= 1'b0;
    if_id_stall <= 1'b1; // Freeze IF/ID
    #1;
    check_cond(id_valid && (id_pc == 32'h0000_0040), "ID_BEFORE_STALL");

    @(posedge clk); #1;
    check_cond(id_valid && (id_pc == 32'h0000_0040) && (id_instr == 32'hAABB_CCDD), "ID_STALL_HOLD_1");
    @(posedge clk); #1;
    check_cond(id_valid && (id_pc == 32'h0000_0040) && (id_instr == 32'hAABB_CCDD), "ID_STALL_HOLD_2");
    if_id_stall <= 1'b0;

    // -------------------------------------------------------------------------
    // Test 6: Pipeline Flush
    // -------------------------------------------------------------------------
    $display("\n--- [Test 6] Pipeline Flush ---");
    @(posedge clk);
    if_id_flush <= 1'b1;
    @(posedge clk);
    if_id_flush <= 1'b0;
    #1;
    check_cond(!id_valid && (id_instr == 32'h0000_0013), "ID_FLUSH_BUBBLE_NOP");

    // -------------------------------------------------------------------------
    // Test 7: Flush Priority Over Stall
    // -------------------------------------------------------------------------
    $display("\n--- [Test 7] Flush Priority Over Stall ---");
    if_pc       <= 32'h0000_0080;
    if_valid    <= 1'b1;
    @(posedge clk);
    if_valid    <= 1'b0;
    #1;
    check_cond(id_valid && (id_pc == 32'h0000_0080), "ID_BEFORE_FLUSH_STALL");

    // Assert both flush and stall
    if_id_stall <= 1'b1;
    if_id_flush <= 1'b1;
    @(posedge clk);
    if_id_stall <= 1'b0;
    if_id_flush <= 1'b0;
    #1;
    check_cond(!id_valid && (id_instr == 32'h0000_0013), "FLUSH_PRIORITY_CLEARS_STALL");

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

endmodule : tb_pipeline_regs
