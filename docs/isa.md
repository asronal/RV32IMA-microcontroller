# RV32IMA Instruction Set Architecture Specification

This document details the instruction subset supported by the **Minimal RV32IMA Microcontroller**, its opcode/funct encodings, and execution semantics.

---

## 1. Supported Base Integer Instructions (RV32I)

### U-Type Instructions
| Instruction | Opcode | Description | Formula |
| :--- | :--- | :--- | :--- |
| `LUI rd, imm` | `0110111` | Load Upper Immediate | `rd = imm << 12` |
| `AUIPC rd, imm` | `0010111` | Add Upper Immediate to PC | `rd = PC + (imm << 12)` |

### Jumps
| Instruction | Opcode | Funct3 | Description | Formula |
| :--- | :--- | :--- | :--- | :--- |
| `JAL rd, offset` | `1101111` | — | Jump and Link | `rd = PC + 4; PC += imm` |
| `JALR rd, rs1, offset` | `1100111` | `000` | Jump and Link Register | `rd = PC + 4; PC = (rs1 + imm) & ~1` |

### Conditional Branches
All branches have opcode `1100011`.
| Instruction | Funct3 | Condition | Target |
| :--- | :--- | :--- | :--- |
| `BEQ rs1, rs2, offset` | `000` | `rs1 == rs2` | `PC + imm` |
| `BNE rs1, rs2, offset` | `001` | `rs1 != rs2` | `PC + imm` |
| `BLT rs1, rs2, offset` | `100` | `$signed(rs1) < $signed(rs2)` | `PC + imm` |
| `BGE rs1, rs2, offset` | `101` | `$signed(rs1) >= $signed(rs2)` | `PC + imm` |
| `BLTU rs1, rs2, offset` | `110` | `rs1 < rs2` (unsigned) | `PC + imm` |
| `BGEU rs1, rs2, offset` | `111` | `rs1 >= rs2` (unsigned) | `PC + imm` |

### Loads
All loads have opcode `0000011`.
| Instruction | Funct3 | Size | Extension |
| :--- | :--- | :--- | :--- |
| `LB rd, offset(rs1)` | `000` | Byte (8-bit) | Sign-extended |
| `LH rd, offset(rs1)` | `001` | Halfword (16-bit) | Sign-extended |
| `LW rd, offset(rs1)` | `010` | Word (32-bit) | Full word |
| `LBU rd, offset(rs1)` | `100` | Byte (8-bit) | Zero-extended |
| `LHU rd, offset(rs1)` | `101` | Halfword (16-bit) | Zero-extended |

### Stores
All stores have opcode `0100011`.
| Instruction | Funct3 | Size |
| :--- | :--- | :--- |
| `SB rs2, offset(rs1)` | `000` | Byte (8-bit) |
| `SH rs2, offset(rs1)` | `001` | Halfword (16-bit) |
| `SW rs2, offset(rs1)` | `010` | Word (32-bit) |

### Register-Immediate ALU Instructions
All immediate ALU instructions have opcode `0010011`.
| Instruction | Funct3 | Funct7 | Operation |
| :--- | :--- | :--- | :--- |
| `ADDI rd, rs1, imm` | `000` | — | `rd = rs1 + imm` |
| `SLTI rd, rs1, imm` | `010` | — | `rd = ($signed(rs1) < $signed(imm)) ? 1 : 0` |
| `SLTIU rd, rs1, imm` | `011` | — | `rd = (rs1 < imm) ? 1 : 0` |
| `XORI rd, rs1, imm` | `100` | — | `rd = rs1 ^ imm` |
| `ORI rd, rs1, imm` | `110` | — | `rd = rs1 \| imm` |
| `ANDI rd, rs1, imm` | `111` | — | `rd = rs1 & imm` |
| `SLLI rd, rs1, shamt` | `001` | `0000000` | `rd = rs1 << shamt[4:0]` |
| `SRLI rd, rs1, shamt` | `101` | `0000000` | `rd = rs1 >> shamt[4:0]` |
| `SRAI rd, rs1, shamt` | `101` | `0100000` | `rd = $signed(rs1) >>> shamt[4:0]` |

### Register-Register ALU Instructions
All register ALU instructions have opcode `0110011`.
| Instruction | Funct3 | Funct7 | Operation |
| :--- | :--- | :--- | :--- |
| `ADD rd, rs1, rs2` | `000` | `0000000` | `rd = rs1 + rs2` |
| `SUB rd, rs1, rs2` | `000` | `0100000` | `rd = rs1 - rs2` |
| `SLL rd, rs1, rs2` | `001` | `0000000` | `rd = rs1 << rs2[4:0]` |
| `SLT rd, rs1, rs2` | `010` | `0000000` | `rd = ($signed(rs1) < $signed(rs2)) ? 1 : 0` |
| `SLTU rd, rs1, rs2` | `011` | `0000000` | `rd = (rs1 < rs2) ? 1 : 0` |
| `XOR rd, rs1, rs2` | `100` | `0000000` | `rd = rs1 ^ rs2` |
| `SRL rd, rs1, rs2` | `101` | `0000000` | `rd = rs1 >> rs2[4:0]` |
| `SRA rd, rs1, rs2` | `101` | `0100000` | `rd = $signed(rs1) >>> rs2[4:0]` |
| `OR rd, rs1, rs2` | `110` | `0000000` | `rd = rs1 \| rs2` |
| `AND rd, rs1, rs2` | `111` | `0000000` | `rd = rs1 & rs2` |

---

## 2. Supported Atomic Instructions (RV32A — Full Subset)

All atomic memory operations have opcode `0101111` and `funct3 = 010` (word width).

### LR/SC — Reservation-Based Atomic Pair
| Instruction | Funct5 | Description |
| :--- | :--- | :--- |
| `LR.W rd, (rs1)` | `00010` | Load Reserved Word — loads word, sets reservation at `rs1` |
| `SC.W rd, rs2, (rs1)` | `00011` | Store Conditional Word — writes `rs2` to `rs1` if reservation valid; `rd=0` (success) or `rd=1` (fail) |

### AMO — Read-Modify-Write Atomics
All return the original memory value in `rd` and write the updated result to memory.
| Instruction | Funct5 | Write Data (`rd → memory`) |
| :--- | :--- | :--- |
| `AMOSWAP.W rd, rs2, (rs1)` | `00001` | `rs2` |
| `AMOADD.W rd, rs2, (rs1)` | `00000` | `mem + rs2` |
| `AMOXOR.W rd, rs2, (rs1)` | `00100` | `mem ^ rs2` |
| `AMOAND.W rd, rs2, (rs1)` | `01100` | `mem & rs2` |
| `AMOOR.W rd, rs2, (rs1)` | `01000` | `mem \| rs2` |
| `AMOMIN.W rd, rs2, (rs1)` | `10000` | `min($signed(mem), $signed(rs2))` |
| `AMOMAX.W rd, rs2, (rs1)` | `10100` | `max($signed(mem), $signed(rs2))` |
| `AMOMINU.W rd, rs2, (rs1)` | `11000` | `min(mem, rs2)` (unsigned) |
| `AMOMAXU.W rd, rs2, (rs1)` | `11100` | `max(mem, rs2)` (unsigned) |

---

## 3. System & Privileged Instructions

All have opcode `1110011`.
- `ECALL` (`funct3 = 000`, `funct12 = 0x000`)
- `EBREAK` (`funct3 = 000`, `funct12 = 0x001`)
- `MRET` (`funct3 = 000`, `funct12 = 0x302`)
- `WFI` (`funct3 = 000`, `funct12 = 0x105`)
- `CSRRW`, `CSRRS`, `CSRRC`, `CSRRWI`, `CSRRSI`, `CSRRCI` (`funct3 != 000`)
