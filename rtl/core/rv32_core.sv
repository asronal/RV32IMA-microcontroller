// =============================================================================
// File: rv32_core.sv
// Description: Top-Level RV32I / RV32IMA 5-Stage Pipelined CPU Core
// Pipeline: IF -> ID -> EX -> MEM -> WB
// Features:
//   - Full RV32I base integer instruction set
//   - Dual-operand data forwarding from EX/MEM and MEM/WB stages
//   - Hardware load-use hazard detection with 1-cycle stall bubble
//   - Early branch/jump resolution in EX stage with pipeline flush
//   - Load/Store byte-lane alignment and sign/zero extension
//   - Generic, decoupled Instruction and Data Memory interfaces
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module rv32_core
  import rv32_pkg::*;
#(
  parameter logic [31:0] RESET_VECTOR = 32'h0000_0000
)(
  input  logic        clk,
  input  logic        rst_n,

  // ---------------------------------------------------------------------------
  // Instruction Memory Interface (Fetch)
  // ---------------------------------------------------------------------------
  output logic [31:0] imem_addr,
  output logic        imem_req,
  input  logic [31:0] imem_rdata,

  // ---------------------------------------------------------------------------
  // Data Memory Interface (Load / Store)
  // ---------------------------------------------------------------------------
  output logic        dmem_valid,
  output logic        dmem_write,
  output logic [31:0] dmem_addr,
  output logic [31:0] dmem_wdata,
  output logic [3:0]  dmem_wstrb,
  input  logic [31:0] dmem_rdata,
  input  logic        dmem_ready
);

  // ===========================================================================
  // Internal Signal Declarations
  // ===========================================================================

  // Hazard Unit Controls
  logic        stall_pc;
  logic        stall_if_id;
  logic        flush_if_id;
  logic        flush_id_ex;

  // Branch Unit Controls
  logic        branch_taken;
  logic [31:0] branch_target;

  // Forwarding Unit Controls
  logic [1:0]  forward_a;
  logic [1:0]  forward_b;

  // ---------------------------------------------------------------------------
  // IF Stage Signals
  // ---------------------------------------------------------------------------
  logic [31:0] pc_curr;
  logic [31:0] pc_plus4;

  // ---------------------------------------------------------------------------
  // ID Stage Signals
  // ---------------------------------------------------------------------------
  logic [31:0] id_pc;
  logic [31:0] id_pc4;
  logic [31:0] id_instr;
  logic        id_valid;

  logic [4:0]  id_rs1_addr;
  logic [4:0]  id_rs2_addr;
  logic [4:0]  id_rd_addr;
  logic        id_reg_write;
  logic        id_mem_read;
  logic        id_mem_write;
  mem_size_e   id_mem_size;
  logic        id_mem_unsigned;
  branch_type_e id_branch_type;
  logic        id_jump;
  logic        id_jump_is_jalr;
  alu_op_e     id_alu_op;
  alu_src_a_e  id_alu_src_a;
  alu_src_b_e  id_alu_src_b;
  wb_src_e     id_wb_src;
  imm_src_e    id_imm_src;
  logic        id_is_atomic;
  amo_op_e     id_amo_op;
  logic        id_is_csr, id_is_mret, id_is_wfi, id_is_ecall, id_is_ebreak, id_illegal_instr;

  logic [31:0] rf_rs1_data;
  logic [31:0] rf_rs2_data;
  logic [31:0] id_rs1_data;
  logic [31:0] id_rs2_data;
  logic [31:0] id_imm;
  logic        id_rs1_used;
  logic        id_rs2_used;

  // ---------------------------------------------------------------------------
  // EX Stage Signals
  // ---------------------------------------------------------------------------
  logic [31:0] ex_pc;
  logic [31:0] ex_pc4;
  logic [31:0] ex_rs1_data;
  logic [31:0] ex_rs2_data;
  logic [4:0]  ex_rs1_addr;
  logic [4:0]  ex_rs2_addr;
  logic [4:0]  ex_rd_addr;
  logic [31:0] ex_imm;
  alu_op_e     ex_alu_op;
  alu_src_a_e  ex_alu_src_a;
  alu_src_b_e  ex_alu_src_b;
  branch_type_e ex_branch_type;
  logic        ex_jump;
  logic        ex_jump_is_jalr;
  logic        ex_mem_read;
  logic        ex_mem_write;
  mem_size_e   ex_mem_size;
  logic        ex_mem_unsigned;
  logic        ex_reg_write;
  wb_src_e     ex_wb_src;
  logic        ex_is_atomic;
  amo_op_e     ex_amo_op;
  logic        ex_is_csr, ex_is_mret, ex_is_wfi, ex_is_ecall, ex_is_ebreak, ex_illegal_instr;
  logic        ex_valid;

  logic [31:0] ex_op_a_fwd;
  logic [31:0] ex_op_b_fwd;
  logic [31:0] alu_in_a;
  logic [31:0] alu_in_b;
  logic [31:0] alu_result;
  logic        alu_zero;
  logic [31:0] mem_forward_data;

  // ---------------------------------------------------------------------------
  // MEM Stage Signals
  // ---------------------------------------------------------------------------
  logic [31:0] mem_pc;
  logic [31:0] mem_pc4;
  logic [31:0] mem_alu_result;
  logic [31:0] mem_rs2_data;
  logic [4:0]  mem_rd_addr;
  logic        mem_mem_read;
  logic        mem_mem_write;
  mem_size_e   mem_mem_size;
  logic        mem_mem_unsigned;
  logic        mem_reg_write;
  wb_src_e     mem_wb_src;
  logic        mem_is_atomic;
  amo_op_e     mem_amo_op;
  logic        mem_is_csr, mem_is_mret, mem_is_wfi, mem_is_ecall, mem_is_ebreak, mem_illegal_instr;
  logic        mem_valid;

  logic [31:0] load_data_formatted;

  // ---------------------------------------------------------------------------
  // WB Stage Signals
  // ---------------------------------------------------------------------------
  logic [31:0] wb_pc4;
  logic [31:0] wb_alu_result;
  logic [31:0] wb_rdata;
  logic [4:0]  wb_rd_addr;
  logic        wb_reg_write;
  wb_src_e     wb_wb_src;
  logic        wb_valid;
  logic [31:0] wb_data;

  // ===========================================================================
  // 1. INSTRUCTION FETCH (IF STAGE)
  // ===========================================================================
  pc_reg #(
    .RESET_VECTOR(RESET_VECTOR)
  ) u_pc_reg (
    .clk           (clk),
    .rst_n         (rst_n),
    .stall         (stall_pc),
    .branch_taken  (branch_taken),
    .branch_target (branch_target),
    .pc_curr       (pc_curr),
    .pc_plus4      (pc_plus4)
  );

  assign imem_addr = pc_curr;
  assign imem_req  = 1'b1;

  // IF/ID Pipeline Register
  if_id u_if_id (
    .clk      (clk),
    .rst_n    (rst_n),
    .stall    (stall_if_id),
    .flush    (flush_if_id),
    .if_pc    (pc_curr),
    .if_pc4   (pc_plus4),
    .if_instr (imem_rdata),
    .if_valid (1'b1),
    .id_pc    (id_pc),
    .id_pc4   (id_pc4),
    .id_instr (id_instr),
    .id_valid (id_valid)
  );

  // ===========================================================================
  // 2. INSTRUCTION DECODE & REGISTER READ (ID STAGE)
  // ===========================================================================
  decoder u_decoder (
    .instr         (id_instr),
    .rs1_addr      (id_rs1_addr),
    .rs2_addr      (id_rs2_addr),
    .rd_addr       (id_rd_addr),
    .reg_write     (id_reg_write),
    .mem_read      (id_mem_read),
    .mem_write     (id_mem_write),
    .mem_size      (id_mem_size),
    .mem_unsigned  (id_mem_unsigned),
    .branch_type   (id_branch_type),
    .jump          (id_jump),
    .jump_is_jalr  (id_jump_is_jalr),
    .alu_op        (id_alu_op),
    .alu_src_a     (id_alu_src_a),
    .alu_src_b     (id_alu_src_b),
    .wb_src        (id_wb_src),
    .imm_src       (id_imm_src),
    .is_atomic     (id_is_atomic),
    .amo_op        (id_amo_op),
    .is_csr        (id_is_csr),
    .is_mret       (id_is_mret),
    .is_wfi        (id_is_wfi),
    .is_ecall      (id_is_ecall),
    .is_ebreak     (id_is_ebreak),
    .illegal_instr (id_illegal_instr)
  );

  // Register File
  regfile u_regfile (
    .clk      (clk),
    .rst_n    (rst_n),
    .rs1_addr (id_rs1_addr),
    .rs1_data (rf_rs1_data),
    .rs2_addr (id_rs2_addr),
    .rs2_data (rf_rs2_data),
    .we       (wb_reg_write && wb_valid),
    .waddr    (wb_rd_addr),
    .wdata    (wb_data)
  );

  // Register File internal write-through (RAW hazard within same cycle)
  assign id_rs1_data = (wb_reg_write && wb_valid && (wb_rd_addr != 5'd0) && (wb_rd_addr == id_rs1_addr)) ?
                       wb_data : rf_rs1_data;

  assign id_rs2_data = (wb_reg_write && wb_valid && (wb_rd_addr != 5'd0) && (wb_rd_addr == id_rs2_addr)) ?
                       wb_data : rf_rs2_data;

  // Immediate Generator
  immediate_gen u_immediate_gen (
    .instr   (id_instr),
    .imm_src (id_imm_src),
    .imm_out (id_imm)
  );

  // Source register usage determination for hazard unit
  assign id_rs1_used = (id_alu_src_a == ALU_SRC_A_RS1) || id_mem_read || id_mem_write ||
                       (id_branch_type != BRANCH_NONE) || id_jump_is_jalr || id_is_atomic;

  assign id_rs2_used = (id_alu_src_b == ALU_SRC_B_RS2) || id_mem_write ||
                       (id_branch_type != BRANCH_NONE) || id_is_atomic;

  // Hazard Detection Unit
  hazard_unit u_hazard_unit (
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

  // ID/EX Pipeline Register
  id_ex u_id_ex (
    .clk              (clk),
    .rst_n            (rst_n),
    .stall            (1'b0),
    .flush            (flush_id_ex),
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

  // ===========================================================================
  // 3. EXECUTE (EX STAGE)
  // ===========================================================================

  // Forwarding Unit
  forwarding_unit u_forwarding_unit (
    .ex_rs1_addr   (ex_rs1_addr),
    .ex_rs2_addr   (ex_rs2_addr),
    .mem_reg_write (mem_reg_write && mem_valid),
    .mem_rd_addr   (mem_rd_addr),
    .wb_reg_write  (wb_reg_write && wb_valid),
    .wb_rd_addr    (wb_rd_addr),
    .forward_a     (forward_a),
    .forward_b     (forward_b)
  );

  // Value forwarded from EX/MEM stage
  assign mem_forward_data = (mem_wb_src == WB_SRC_PC4) ? mem_pc4 : mem_alu_result;

  // Operand A Forwarding Multiplexer
  always_comb begin
    case (forward_a)
      2'b10:   ex_op_a_fwd = mem_forward_data;
      2'b01:   ex_op_a_fwd = wb_data;
      default: ex_op_a_fwd = ex_rs1_data;
    endcase
  end

  // Operand B Forwarding Multiplexer
  always_comb begin
    case (forward_b)
      2'b10:   ex_op_b_fwd = mem_forward_data;
      2'b01:   ex_op_b_fwd = wb_data;
      default: ex_op_b_fwd = ex_rs2_data;
    endcase
  end

  // ALU Input A Selection Multiplexer
  always_comb begin
    case (ex_alu_src_a)
      ALU_SRC_A_RS1:  alu_in_a = ex_op_a_fwd;
      ALU_SRC_A_PC:   alu_in_a = ex_pc;
      ALU_SRC_A_ZERO: alu_in_a = 32'd0;
      default:        alu_in_a = ex_op_a_fwd;
    endcase
  end

  // ALU Input B Selection Multiplexer
  always_comb begin
    case (ex_alu_src_b)
      ALU_SRC_B_RS2:  alu_in_b = ex_op_b_fwd;
      ALU_SRC_B_IMM:  alu_in_b = ex_imm;
      ALU_SRC_B_FOUR: alu_in_b = 32'd4;
      default:        alu_in_b = ex_op_b_fwd;
    endcase
  end

  // ALU Instance
  alu u_alu (
    .op_a   (alu_in_a),
    .op_b   (alu_in_b),
    .alu_op (ex_alu_op),
    .result (alu_result),
    .zero   (alu_zero)
  );

  // Branch Unit Instance
  branch_unit u_branch_unit (
    .branch_type   (ex_branch_type),
    .jump          (ex_jump),
    .jump_is_jalr  (ex_jump_is_jalr),
    .pc            (ex_pc),
    .imm           (ex_imm),
    .op_a          (ex_op_a_fwd),
    .op_b          (ex_op_b_fwd),
    .branch_taken  (branch_taken),
    .branch_target (branch_target)
  );

  // EX/MEM Pipeline Register
  ex_mem u_ex_mem (
    .clk              (clk),
    .rst_n            (rst_n),
    .stall            (1'b0),
    .flush            (1'b0),
    .ex_pc            (ex_pc),
    .ex_pc4           (ex_pc4),
    .ex_alu_result    (alu_result),
    .ex_rs2_data      (ex_op_b_fwd),
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

  // ===========================================================================
  // 4. MEMORY ACCESS (MEM STAGE)
  // ===========================================================================
  assign dmem_valid = mem_valid && (mem_mem_read || mem_mem_write);
  assign dmem_write = mem_mem_write;
  assign dmem_addr  = mem_alu_result;

  logic [1:0] byte_offset;
  assign byte_offset = mem_alu_result[1:0];

  // Store Byte-Lane Alignment & Strobe Generation
  always_comb begin
    dmem_wdata = mem_rs2_data;
    dmem_wstrb = 4'b0000;

    case (mem_mem_size)
      MEM_SIZE_BYTE: begin
        dmem_wdata = {4{mem_rs2_data[7:0]}};
        dmem_wstrb = 4'b0001 << byte_offset;
      end

      MEM_SIZE_HALF: begin
        dmem_wdata = {2{mem_rs2_data[15:0]}};
        dmem_wstrb = byte_offset[1] ? 4'b1100 : 4'b0011;
      end

      MEM_SIZE_WORD: begin
        dmem_wdata = mem_rs2_data;
        dmem_wstrb = 4'b1111;
      end

      default: begin
        dmem_wdata = mem_rs2_data;
        dmem_wstrb = 4'b0000;
      end
    endcase
  end

  // Load Data Slicing & Sign/Zero Extension
  logic [7:0]  read_byte;
  logic [15:0] read_half;

  always_comb begin
    read_byte = 8'd0;
    case (byte_offset)
      2'b00:   read_byte = dmem_rdata[7:0];
      2'b01:   read_byte = dmem_rdata[15:8];
      2'b10:   read_byte = dmem_rdata[23:16];
      2'b11:   read_byte = dmem_rdata[31:24];
      default: read_byte = 8'd0;
    endcase
  end

  assign read_half = byte_offset[1] ? dmem_rdata[31:16] : dmem_rdata[15:0];

  always_comb begin
    case (mem_mem_size)
      MEM_SIZE_BYTE: begin
        load_data_formatted = mem_mem_unsigned ? {24'd0, read_byte} :
                                                {{24{read_byte[7]}}, read_byte};
      end

      MEM_SIZE_HALF: begin
        load_data_formatted = mem_mem_unsigned ? {16'd0, read_half} :
                                                {{16{read_half[15]}}, read_half};
      end

      MEM_SIZE_WORD: begin
        load_data_formatted = dmem_rdata;
      end

      default: begin
        load_data_formatted = dmem_rdata;
      end
    endcase
  end

  // MEM/WB Pipeline Register
  mem_wb u_mem_wb (
    .clk           (clk),
    .rst_n         (rst_n),
    .stall         (1'b0),
    .flush         (1'b0),
    .mem_pc4       (mem_pc4),
    .mem_alu_result(mem_alu_result),
    .mem_rdata     (load_data_formatted),
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

  // ===========================================================================
  // 5. REGISTER WRITEBACK (WB STAGE)
  // ===========================================================================
  always_comb begin
    case (wb_wb_src)
      WB_SRC_ALU: wb_data = wb_alu_result;
      WB_SRC_MEM: wb_data = wb_rdata;
      WB_SRC_PC4: wb_data = wb_pc4;
      default:    wb_data = wb_alu_result;
    endcase
  end

endmodule : rv32_core
