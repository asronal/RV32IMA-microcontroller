// =============================================================================
// File: decoder.sv
// Description: RV32IMA Instruction Decoder
// Features:
//   - Fully decodes RV32I base integer instructions
//   - Decodes RV32A atomic instructions (LR.W, SC.W, AMOADD.W, AMOSWAP.W, etc.)
//   - Decodes Privilege / CSR / Trapping instructions (MRET, WFI, ECALL, EBREAK, CSR*)
//   - Identifies illegal instructions and asserts illegal_instr flag
//   - Purely combinational with zero latch inference
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module decoder
  import rv32_pkg::*;
(
  input  logic [31:0]       instr,

  // Register File Addresses
  output logic [4:0]        rs1_addr,
  output logic [4:0]        rs2_addr,
  output logic [4:0]        rd_addr,

  // Register File Control
  output logic              reg_write,

  // Memory Interface Control
  output logic              mem_read,
  output logic              mem_write,
  output mem_size_e         mem_size,
  output logic              mem_unsigned,

  // Branch & Jump Control
  output branch_type_e      branch_type,
  output logic              jump,
  output logic              jump_is_jalr,

  // ALU Control
  output alu_op_e           alu_op,
  output alu_src_a_e        alu_src_a,
  output alu_src_b_e        alu_src_b,
  output wb_src_e           wb_src,
  output imm_src_e          imm_src,

  // Atomic (RV32A) Control
  output logic              is_atomic,
  output amo_op_e           amo_op,

  // System & CSR Control
  output logic              is_csr,
  output logic              is_mret,
  output logic              is_wfi,
  output logic              is_ecall,
  output logic              is_ebreak,

  // Exception / Illegal Instruction Flag
  output logic              illegal_instr
);

  // ---------------------------------------------------------------------------
  // Instruction Field Extraction
  // ---------------------------------------------------------------------------
  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic [4:0] funct5;
  logic [11:0] funct12;

  assign opcode  = instr[6:0];
  assign funct3  = instr[14:12];
  assign funct7  = instr[31:25];
  assign funct5  = instr[31:27];
  assign funct12 = instr[31:20];

  assign rs1_addr = instr[19:15];
  assign rs2_addr = instr[24:20];
  assign rd_addr  = instr[11:7];

  // ---------------------------------------------------------------------------
  // Combinational Decode Logic
  // Unconditional default assignments prevent any latch inference.
  // ---------------------------------------------------------------------------
  always_comb begin
    // Unconditional Defaults
    reg_write     = 1'b0;
    mem_read      = 1'b0;
    mem_write     = 1'b0;
    mem_size      = MEM_SIZE_WORD;
    mem_unsigned  = 1'b0;
    branch_type   = BRANCH_NONE;
    jump          = 1'b0;
    jump_is_jalr  = 1'b0;
    alu_op        = ALU_ADD;
    alu_src_a     = ALU_SRC_A_RS1;
    alu_src_b     = ALU_SRC_B_RS2;
    wb_src        = WB_SRC_ALU;
    imm_src       = IMM_SRC_I;
    is_atomic     = 1'b0;
    amo_op        = AMO_OP_NONE;
    is_csr        = 1'b0;
    is_mret       = 1'b0;
    is_wfi        = 1'b0;
    is_ecall      = 1'b0;
    is_ebreak     = 1'b0;
    illegal_instr = 1'b0;

    case (opcode)
      // -----------------------------------------------------------------------
      // LUI (Load Upper Immediate)
      // -----------------------------------------------------------------------
      OPCODE_LUI: begin
        reg_write = 1'b1;
        imm_src   = IMM_SRC_U;
        alu_src_a = ALU_SRC_A_ZERO;
        alu_src_b = ALU_SRC_B_IMM;
        alu_op    = ALU_ADD;
        wb_src    = WB_SRC_ALU;
      end

      // -----------------------------------------------------------------------
      // AUIPC (Add Upper Immediate to PC)
      // -----------------------------------------------------------------------
      OPCODE_AUIPC: begin
        reg_write = 1'b1;
        imm_src   = IMM_SRC_U;
        alu_src_a = ALU_SRC_A_PC;
        alu_src_b = ALU_SRC_B_IMM;
        alu_op    = ALU_ADD;
        wb_src    = WB_SRC_ALU;
      end

      // -----------------------------------------------------------------------
      // JAL (Jump and Link)
      // -----------------------------------------------------------------------
      OPCODE_JAL: begin
        reg_write = 1'b1;
        jump      = 1'b1;
        imm_src   = IMM_SRC_J;
        alu_src_a = ALU_SRC_A_PC;
        alu_src_b = ALU_SRC_B_FOUR;
        alu_op    = ALU_ADD;
        wb_src    = WB_SRC_PC4;
      end

      // -----------------------------------------------------------------------
      // JALR (Jump and Link Register)
      // -----------------------------------------------------------------------
      OPCODE_JALR: begin
        if (funct3 == 3'b000) begin
          reg_write    = 1'b1;
          jump         = 1'b1;
          jump_is_jalr = 1'b1;
          imm_src      = IMM_SRC_I;
          alu_src_a    = ALU_SRC_A_PC;
          alu_src_b    = ALU_SRC_B_FOUR;
          alu_op       = ALU_ADD;
          wb_src       = WB_SRC_PC4;
        end else begin
          illegal_instr = 1'b1;
        end
      end

      // -----------------------------------------------------------------------
      // Conditional Branches
      // -----------------------------------------------------------------------
      OPCODE_BRANCH: begin
        imm_src   = IMM_SRC_B;
        alu_src_a = ALU_SRC_A_RS1;
        alu_src_b = ALU_SRC_B_RS2;

        case (funct3)
          FUNCT3_BEQ:  branch_type = BRANCH_BEQ;
          FUNCT3_BNE:  branch_type = BRANCH_BNE;
          FUNCT3_BLT:  branch_type = BRANCH_BLT;
          FUNCT3_BGE:  branch_type = BRANCH_BGE;
          FUNCT3_BLTU: branch_type = BRANCH_BLTU;
          FUNCT3_BGEU: branch_type = BRANCH_BGEU;
          default:     illegal_instr = 1'b1;
        endcase
      end

      // -----------------------------------------------------------------------
      // Load Instructions
      // -----------------------------------------------------------------------
      OPCODE_LOAD: begin
        reg_write = 1'b1;
        mem_read  = 1'b1;
        imm_src   = IMM_SRC_I;
        alu_src_a = ALU_SRC_A_RS1;
        alu_src_b = ALU_SRC_B_IMM;
        alu_op    = ALU_ADD;
        wb_src    = WB_SRC_MEM;

        case (funct3)
          FUNCT3_LB: begin
            mem_size     = MEM_SIZE_BYTE;
            mem_unsigned = 1'b0;
          end
          FUNCT3_LH: begin
            mem_size     = MEM_SIZE_HALF;
            mem_unsigned = 1'b0;
          end
          FUNCT3_LW: begin
            mem_size     = MEM_SIZE_WORD;
            mem_unsigned = 1'b0;
          end
          FUNCT3_LBU: begin
            mem_size     = MEM_SIZE_BYTE;
            mem_unsigned = 1'b1;
          end
          FUNCT3_LHU: begin
            mem_size     = MEM_SIZE_HALF;
            mem_unsigned = 1'b1;
          end
          default: begin
            illegal_instr = 1'b1;
          end
        endcase
      end

      // -----------------------------------------------------------------------
      // Store Instructions
      // -----------------------------------------------------------------------
      OPCODE_STORE: begin
        mem_write = 1'b1;
        imm_src   = IMM_SRC_S;
        alu_src_a = ALU_SRC_A_RS1;
        alu_src_b = ALU_SRC_B_IMM;
        alu_op    = ALU_ADD;

        case (funct3)
          FUNCT3_SB: mem_size = MEM_SIZE_BYTE;
          FUNCT3_SH: mem_size = MEM_SIZE_HALF;
          FUNCT3_SW: mem_size = MEM_SIZE_WORD;
          default:   illegal_instr = 1'b1;
        endcase
      end

      // -----------------------------------------------------------------------
      // Register-Immediate ALU Instructions
      // -----------------------------------------------------------------------
      OPCODE_OP_IMM: begin
        reg_write = 1'b1;
        imm_src   = IMM_SRC_I;
        alu_src_a = ALU_SRC_A_RS1;
        alu_src_b = ALU_SRC_B_IMM;
        wb_src    = WB_SRC_ALU;

        case (funct3)
          FUNCT3_ADD_SUB: alu_op = ALU_ADD;
          FUNCT3_SLT:     alu_op = ALU_SLT;
          FUNCT3_SLTU:    alu_op = ALU_SLTU;
          FUNCT3_XOR:     alu_op = ALU_XOR;
          FUNCT3_OR:      alu_op = ALU_OR;
          FUNCT3_AND:     alu_op = ALU_AND;

          FUNCT3_SLL: begin
            if (funct7 == FUNCT7_STANDARD) begin
              alu_op = ALU_SLL;
            end else begin
              illegal_instr = 1'b1;
            end
          end

          FUNCT3_SRL_SRA: begin
            if (funct7 == FUNCT7_STANDARD) begin
              alu_op = ALU_SRL;
            end else if (funct7 == FUNCT7_ALT) begin
              alu_op = ALU_SRA;
            end else begin
              illegal_instr = 1'b1;
            end
          end

          default: illegal_instr = 1'b1;
        endcase
      end

      // -----------------------------------------------------------------------
      // Register-Register ALU Instructions
      // -----------------------------------------------------------------------
      OPCODE_OP: begin
        reg_write = 1'b1;
        alu_src_a = ALU_SRC_A_RS1;
        alu_src_b = ALU_SRC_B_RS2;
        wb_src    = WB_SRC_ALU;

        case (funct7)
          FUNCT7_STANDARD: begin
            case (funct3)
              FUNCT3_ADD_SUB: alu_op = ALU_ADD;
              FUNCT3_SLL:     alu_op = ALU_SLL;
              FUNCT3_SLT:     alu_op = ALU_SLT;
              FUNCT3_SLTU:    alu_op = ALU_SLTU;
              FUNCT3_XOR:     alu_op = ALU_XOR;
              FUNCT3_SRL_SRA: alu_op = ALU_SRL;
              FUNCT3_OR:      alu_op = ALU_OR;
              FUNCT3_AND:     alu_op = ALU_AND;
              default:        illegal_instr = 1'b1;
            endcase
          end

          FUNCT7_ALT: begin
            case (funct3)
              FUNCT3_ADD_SUB: alu_op = ALU_SUB;
              FUNCT3_SRL_SRA: alu_op = ALU_SRA;
              default:        illegal_instr = 1'b1;
            endcase
          end

          default: begin
            illegal_instr = 1'b1;
          end
        endcase
      end

      // -----------------------------------------------------------------------
      // RV32A Atomic Instructions
      // -----------------------------------------------------------------------
      OPCODE_AMO: begin
        // Only 32-bit word atomics are valid in RV32A (funct3 == 3'b010)
        if (funct3 == 3'b010) begin
          is_atomic = 1'b1;
          reg_write = 1'b1;
          wb_src    = WB_SRC_AMO;
          alu_src_a = ALU_SRC_A_RS1; // Base memory address in rs1
          alu_src_b = ALU_SRC_B_RS2; // Operand in rs2

          case (funct5)
            AMO_FUNCT5_LR:   amo_op = AMO_OP_LR;
            AMO_FUNCT5_SC:   amo_op = AMO_OP_SC;
            AMO_FUNCT5_SWAP: amo_op = AMO_OP_SWAP;
            AMO_FUNCT5_ADD:  amo_op = AMO_OP_ADD;
            AMO_FUNCT5_XOR:  amo_op = AMO_OP_XOR;
            AMO_FUNCT5_AND:  amo_op = AMO_OP_AND;
            AMO_FUNCT5_OR:   amo_op = AMO_OP_OR;
            AMO_FUNCT5_MIN:  amo_op = AMO_OP_MIN;
            AMO_FUNCT5_MAX:  amo_op = AMO_OP_MAX;
            AMO_FUNCT5_MINU: amo_op = AMO_OP_MINU;
            AMO_FUNCT5_MAXU: amo_op = AMO_OP_MAXU;
            default:         illegal_instr = 1'b1;
          endcase
        end else begin
          illegal_instr = 1'b1;
        end
      end

      // -----------------------------------------------------------------------
      // Privilege / CSR / System Instructions
      // -----------------------------------------------------------------------
      OPCODE_SYSTEM: begin
        if (funct3 == FUNCT3_PRIV) begin
          // Non-CSR system instructions: ECALL, EBREAK, MRET, WFI
          case (funct12)
            12'h000: is_ecall  = 1'b1;
            12'h001: is_ebreak = 1'b1;
            12'h302: is_mret   = 1'b1;
            12'h105: is_wfi    = 1'b1;
            default: illegal_instr = 1'b1;
          endcase
        end else begin
          // CSR instructions: CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI
          is_csr    = 1'b1;
          reg_write = (rd_addr != 5'd0); // Only writeback if destination != x0
          wb_src    = WB_SRC_CSR;

          case (funct3)
            FUNCT3_CSRRW,
            FUNCT3_CSRRS,
            FUNCT3_CSRRC: begin
              alu_src_a = ALU_SRC_A_RS1;
            end
            FUNCT3_CSRRWI,
            FUNCT3_CSRRSI,
            FUNCT3_CSRRCI: begin
              imm_src   = IMM_SRC_CSR;
              alu_src_b = ALU_SRC_B_IMM;
            end
            default: begin
              illegal_instr = 1'b1;
            end
          endcase
        end
      end

      // -----------------------------------------------------------------------
      // Miscellaneous Memory (FENCE, FENCE.I)
      // Executed as NOP in this single-issue in-order un-cached MCU
      // -----------------------------------------------------------------------
      OPCODE_MISC_MEM: begin
        // Intentionally treated as NOP (no side-effects, no stall needed)
        reg_write = 1'b0;
      end

      // -----------------------------------------------------------------------
      // Unsupported / Unknown Opcode
      // -----------------------------------------------------------------------
      default: begin
        illegal_instr = 1'b1;
      end
    endcase
  end

endmodule : decoder
