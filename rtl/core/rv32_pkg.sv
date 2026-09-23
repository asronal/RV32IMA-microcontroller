// =============================================================================
// File: rv32_pkg.sv
// Description: Central package for RV32IMA microcontroller
//              Contains opcodes, funct3/funct7 codes, ALU operation enums,
//              multiplexer control signals, and exception/trap codes.
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

package rv32_pkg;

  // ---------------------------------------------------------------------------
  // Base Opcode Encodings (instr[6:0])
  // ---------------------------------------------------------------------------
  typedef enum logic [6:0] {
    OPCODE_LUI      = 7'b0110111, // Load Upper Immediate
    OPCODE_AUIPC    = 7'b0010111, // Add Upper Immediate to PC
    OPCODE_JAL      = 7'b1101111, // Jump and Link
    OPCODE_JALR     = 7'b1100111, // Jump and Link Register
    OPCODE_BRANCH   = 7'b1100011, // Conditional Branches
    OPCODE_LOAD     = 7'b0000011, // Load operations
    OPCODE_STORE    = 7'b0100011, // Store operations
    OPCODE_OP_IMM   = 7'b0010011, // Register-Immediate ALU
    OPCODE_OP       = 7'b0110011, // Register-Register ALU
    OPCODE_MISC_MEM = 7'b0001111, // FENCE, FENCE.I
    OPCODE_SYSTEM   = 7'b1110011, // CSR, ECALL, EBREAK, MRET, WFI
    OPCODE_AMO      = 7'b0101111  // RV32A Atomic Operations
  } opcode_e;

  // ---------------------------------------------------------------------------
  // Branch Funct3 Encodings (instr[14:12])
  // ---------------------------------------------------------------------------
  localparam logic [2:0] FUNCT3_BEQ  = 3'b000;
  localparam logic [2:0] FUNCT3_BNE  = 3'b001;
  localparam logic [2:0] FUNCT3_BLT  = 3'b100;
  localparam logic [2:0] FUNCT3_BGE  = 3'b101;
  localparam logic [2:0] FUNCT3_BLTU = 3'b110;
  localparam logic [2:0] FUNCT3_BGEU = 3'b111;

  // ---------------------------------------------------------------------------
  // Load Funct3 Encodings (instr[14:12])
  // ---------------------------------------------------------------------------
  localparam logic [2:0] FUNCT3_LB  = 3'b000;
  localparam logic [2:0] FUNCT3_LH  = 3'b001;
  localparam logic [2:0] FUNCT3_LW  = 3'b010;
  localparam logic [2:0] FUNCT3_LBU = 3'b100;
  localparam logic [2:0] FUNCT3_LHU = 3'b101;

  // ---------------------------------------------------------------------------
  // Store Funct3 Encodings (instr[14:12])
  // ---------------------------------------------------------------------------
  localparam logic [2:0] FUNCT3_SB = 3'b000;
  localparam logic [2:0] FUNCT3_SH = 3'b001;
  localparam logic [2:0] FUNCT3_SW = 3'b010;

  // ---------------------------------------------------------------------------
  // ALU Funct3 Encodings (instr[14:12])
  // ---------------------------------------------------------------------------
  localparam logic [2:0] FUNCT3_ADD_SUB = 3'b000;
  localparam logic [2:0] FUNCT3_SLL     = 3'b001;
  localparam logic [2:0] FUNCT3_SLT     = 3'b010;
  localparam logic [2:0] FUNCT3_SLTU    = 3'b011;
  localparam logic [2:0] FUNCT3_XOR     = 3'b100;
  localparam logic [2:0] FUNCT3_SRL_SRA = 3'b101;
  localparam logic [2:0] FUNCT3_OR      = 3'b110;
  localparam logic [2:0] FUNCT3_AND     = 3'b111;

  // ---------------------------------------------------------------------------
  // Funct7 Encodings (instr[31:25])
  // ---------------------------------------------------------------------------
  localparam logic [6:0] FUNCT7_STANDARD = 7'b0000000;
  localparam logic [6:0] FUNCT7_ALT      = 7'b0100000; // SUB, SRA

  // ---------------------------------------------------------------------------
  // CSR / System Funct3 Encodings (instr[14:12])
  // ---------------------------------------------------------------------------
  localparam logic [2:0] FUNCT3_PRIV   = 3'b000;
  localparam logic [2:0] FUNCT3_CSRRW  = 3'b001;
  localparam logic [2:0] FUNCT3_CSRRS  = 3'b010;
  localparam logic [2:0] FUNCT3_CSRRC  = 3'b011;
  localparam logic [2:0] FUNCT3_CSRRWI = 3'b101;
  localparam logic [2:0] FUNCT3_CSRRSI = 3'b110;
  localparam logic [2:0] FUNCT3_CSRRCI = 3'b111;

  // ---------------------------------------------------------------------------
  // Atomic Funct5 Encodings (instr[31:27])
  // ---------------------------------------------------------------------------
  localparam logic [4:0] AMO_FUNCT5_LR      = 5'b00010;
  localparam logic [4:0] AMO_FUNCT5_SC      = 5'b00011;
  localparam logic [4:0] AMO_FUNCT5_SWAP    = 5'b00001;
  localparam logic [4:0] AMO_FUNCT5_ADD     = 5'b00000;
  localparam logic [4:0] AMO_FUNCT5_XOR     = 5'b00100;
  localparam logic [4:0] AMO_FUNCT5_AND     = 5'b01100;
  localparam logic [4:0] AMO_FUNCT5_OR      = 5'b01000;
  localparam logic [4:0] AMO_FUNCT5_MIN     = 5'b10000;
  localparam logic [4:0] AMO_FUNCT5_MAX     = 5'b10100;
  localparam logic [4:0] AMO_FUNCT5_MINU    = 5'b11000;
  localparam logic [4:0] AMO_FUNCT5_MAXU    = 5'b11100;

  // ---------------------------------------------------------------------------
  // ALU Operation Enumeration
  // ---------------------------------------------------------------------------
  typedef enum logic [3:0] {
    ALU_ADD    = 4'd0,
    ALU_SUB    = 4'd1,
    ALU_AND    = 4'd2,
    ALU_OR     = 4'd3,
    ALU_XOR    = 4'd4,
    ALU_SLL    = 4'd5,
    ALU_SRL    = 4'd6,
    ALU_SRA    = 4'd7,
    ALU_SLT    = 4'd8,
    ALU_SLTU   = 4'd9,
    ALU_COPY_B = 4'd10
  } alu_op_e;

  // ---------------------------------------------------------------------------
  // Immediate Generation Source Selector
  // ---------------------------------------------------------------------------
  typedef enum logic [2:0] {
    IMM_SRC_I   = 3'd0,
    IMM_SRC_S   = 3'd1,
    IMM_SRC_B   = 3'd2,
    IMM_SRC_U   = 3'd3,
    IMM_SRC_J   = 3'd4,
    IMM_SRC_CSR = 3'd5
  } imm_src_e;

  // ---------------------------------------------------------------------------
  // ALU Operand A Multiplexer Select
  // ---------------------------------------------------------------------------
  typedef enum logic [1:0] {
    ALU_SRC_A_RS1  = 2'd0,
    ALU_SRC_A_PC   = 2'd1,
    ALU_SRC_A_ZERO = 2'd2
  } alu_src_a_e;

  // ---------------------------------------------------------------------------
  // ALU Operand B Multiplexer Select
  // ---------------------------------------------------------------------------
  typedef enum logic [1:0] {
    ALU_SRC_B_RS2  = 2'd0,
    ALU_SRC_B_IMM  = 2'd1,
    ALU_SRC_B_FOUR = 2'd2
  } alu_src_b_e;

  // ---------------------------------------------------------------------------
  // Writeback Data Multiplexer Select
  // ---------------------------------------------------------------------------
  typedef enum logic [2:0] {
    WB_SRC_ALU  = 3'd0,
    WB_SRC_MEM  = 3'd1,
    WB_SRC_PC4  = 3'd2,
    WB_SRC_CSR  = 3'd3,
    WB_SRC_AMO  = 3'd4
  } wb_src_e;

  // ---------------------------------------------------------------------------
  // Atomic Operation Types
  // ---------------------------------------------------------------------------
  typedef enum logic [3:0] {
    AMO_OP_NONE = 4'd0,
    AMO_OP_LR   = 4'd1,
    AMO_OP_SC   = 4'd2,
    AMO_OP_SWAP = 4'd3,
    AMO_OP_ADD  = 4'd4,
    AMO_OP_XOR  = 4'd5,
    AMO_OP_AND  = 4'd6,
    AMO_OP_OR   = 4'd7,
    AMO_OP_MIN  = 4'd8,
    AMO_OP_MAX  = 4'd9,
    AMO_OP_MINU = 4'd10,
    AMO_OP_MAXU = 4'd11
  } amo_op_e;

  // ---------------------------------------------------------------------------
  // Memory Transfer Size
  // ---------------------------------------------------------------------------
  typedef enum logic [1:0] {
    MEM_SIZE_BYTE = 2'b00,
    MEM_SIZE_HALF = 2'b01,
    MEM_SIZE_WORD = 2'b10
  } mem_size_e;

  // ---------------------------------------------------------------------------
  // Branch Comparison Type
  // ---------------------------------------------------------------------------
  typedef enum logic [2:0] {
    BRANCH_NONE = 3'b000,
    BRANCH_BEQ  = 3'b001,
    BRANCH_BNE  = 3'b010,
    BRANCH_BLT  = 3'b011,
    BRANCH_BGE  = 3'b100,
    BRANCH_BLTU = 3'b101,
    BRANCH_BGEU = 3'b110
  } branch_type_e;

  // ---------------------------------------------------------------------------
  // Machine Mode Trap Causes (mcause values)
  // ---------------------------------------------------------------------------
  localparam logic [31:0] TRAP_CAUSE_INSTR_ADDR_MISALIGNED = 32'd0;
  localparam logic [31:0] TRAP_CAUSE_INSTR_ACCESS_FAULT    = 32'd1;
  localparam logic [31:0] TRAP_CAUSE_ILLEGAL_INSTR         = 32'd2;
  localparam logic [31:0] TRAP_CAUSE_BREAKPOINT            = 32'd3;
  localparam logic [31:0] TRAP_CAUSE_LOAD_ADDR_MISALIGNED  = 32'd4;
  localparam logic [31:0] TRAP_CAUSE_LOAD_ACCESS_FAULT     = 32'd5;
  localparam logic [31:0] TRAP_CAUSE_STORE_ADDR_MISALIGNED = 32'd6;
  localparam logic [31:0] TRAP_CAUSE_STORE_ACCESS_FAULT    = 32'd7;
  localparam logic [31:0] TRAP_CAUSE_ECALL_M               = 32'd11;

endpackage : rv32_pkg
