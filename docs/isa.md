# RV32IMA Instruction Set Architecture Specification

<div align="center">

**[← Back to README](../README.md)** • **[Architecture](architecture.md)** • **[Memory Map](memory_map.md)** • **[Verification](verification.md)** • **[SAED Integration](saed_integration.md)**

</div>

---

## 1. Instruction Formats and Bit Layouts

All instructions in the RV32IMA architecture are 32 bits wide, aligned on 4-byte boundaries, and stored in little-endian format.

```
                  31        25 24     20 19     15 14  12 11      7 6            0
                 +------------+---------+---------+------+---------+--------------+
  R-Type         |   funct7   |   rs2   |   rs1   |funct3|   rd    |    opcode    |
                 +------------+---------+---------+------+---------+--------------+
  I-Type         |          imm[11:0]   |   rs1   |funct3|   rd    |    opcode    |
                 +------------+---------+---------+------+---------+--------------+
  S-Type         | imm[11:5]  |   rs2   |   rs1   |funct3|imm[4:0] |    opcode    |
                 +------------+---------+---------+------+---------+--------------+
  B-Type         |i[12]|i[10:5|   rs2   |   rs1   |funct3|i[4:1]|i11|    opcode   |
                 +------------+---------+---------+------+---------+--------------+
  U-Type         |                    imm[31:12]         |   rd    |    opcode    |
                 +------------+---------+---------+------+---------+--------------+
  J-Type         |i[20]|   imm[10:1]   |imm[11]|   imm[19:12] |rd  |    opcode    |
                 +------------+---------+---------+------+---------+--------------+
  Atomic (AMO)   |  funct5 |aq|rl| rs2  |   rs1   |funct3|   rd    |    opcode    |
                 +------------+---------+---------+------+---------+--------------+
```

---

## 2. RV32I Base Integer Instruction Set

### 2.1 Upper Immediate Instructions
| Instruction | Opcode | Format | Description | Operation |
| :--- | :---: | :---: | :--- | :--- |
| `LUI rd, imm` | `0110111` | U-Type | Load Upper Immediate | `rd = imm << 12` |
| `AUIPC rd, imm` | `0010111` | U-Type | Add Upper Immediate to PC | `rd = PC + (imm << 12)` |

---

### 2.2 Unconditional Jumps
| Instruction | Opcode | Funct3 | Format | Description | Operation |
| :--- | :---: | :---: | :---: | :--- | :--- |
| `JAL rd, offset` | `1101111` | — | J-Type | Jump and Link | `rd = PC + 4; PC = PC + offset` |
| `JALR rd, rs1, offset` | `1100111` | `000` | I-Type | Jump and Link Register | `rd = PC + 4; PC = (rs1 + offset) & ~1` |

---

### 2.3 Conditional Branches
All branch instructions use opcode `1100011` (B-Type format). The target is calculated as `PC + imm`.

| Instruction | Funct3 | Condition Tested | Taken Target |
| :--- | :---: | :--- | :--- |
| `BEQ rs1, rs2, offset` | `000` | `rs1 == rs2` | `PC + imm` |
| `BNE rs1, rs2, offset` | `001` | `rs1 != rs2` | `PC + imm` |
| `BLT rs1, rs2, offset` | `100` | `signed(rs1) < signed(rs2)` | `PC + imm` |
| `BGE rs1, rs2, offset` | `101` | `signed(rs1) >= signed(rs2)` | `PC + imm` |
| `BLTU rs1, rs2, offset` | `110` | `unsigned(rs1) < unsigned(rs2)` | `PC + imm` |
| `BGEU rs1, rs2, offset` | `111` | `unsigned(rs1) >= unsigned(rs2)` | `PC + imm` |

---

### 2.4 Load Instructions
All load instructions use opcode `0000011` (I-Type format). Effective address is `rs1 + offset`.

| Instruction | Funct3 | Data Width | Extension | Operation |
| :--- | :---: | :---: | :--- | :--- |
| `LB rd, offset(rs1)` | `000` | 8-bit (Byte) | Sign-extended | `rd = SignExt(Mem8[rs1 + offset])` |
| `LH rd, offset(rs1)` | `001` | 16-bit (Half) | Sign-extended | `rd = SignExt(Mem16[rs1 + offset])` |
| `LW rd, offset(rs1)` | `010` | 32-bit (Word) | Full 32-bit | `rd = Mem32[rs1 + offset]` |
| `LBU rd, offset(rs1)` | `100` | 8-bit (Byte) | Zero-extended | `rd = ZeroExt(Mem8[rs1 + offset])` |
| `LHU rd, offset(rs1)` | `101` | 16-bit (Half) | Zero-extended | `rd = ZeroExt(Mem16[rs1 + offset])` |

---

### 2.5 Store Instructions
All store instructions use opcode `0100011` (S-Type format). Effective address is `rs1 + offset`.

| Instruction | Funct3 | Data Width | Operation |
| :--- | :---: | :---: | :--- |
| `SB rs2, offset(rs1)` | `000` | 8-bit (Byte) | `Mem8[rs1 + offset] = rs2[7:0]` |
| `SH rs2, offset(rs1)` | `001` | 16-bit (Half) | `Mem16[rs1 + offset] = rs2[15:0]` |
| `SW rs2, offset(rs1)` | `010` | 32-bit (Word) | `Mem32[rs1 + offset] = rs2[31:0]` |

---

### 2.6 Register-Immediate ALU Operations
All immediate arithmetic/logical instructions use opcode `0010011` (I-Type format).

| Instruction | Funct3 | Funct7 | Operation |
| :--- | :---: | :---: | :--- |
| `ADDI rd, rs1, imm` | `000` | — | `rd = rs1 + SignExt(imm)` |
| `SLTI rd, rs1, imm` | `010` | — | `rd = (signed(rs1) < signed(imm)) ? 1 : 0` |
| `SLTIU rd, rs1, imm` | `011` | — | `rd = (unsigned(rs1) < unsigned(imm)) ? 1 : 0` |
| `XORI rd, rs1, imm` | `100` | — | `rd = rs1 ^ SignExt(imm)` |
| `ORI rd, rs1, imm` | `110` | — | `rd = rs1 \| SignExt(imm)` |
| `ANDI rd, rs1, imm` | `111` | — | `rd = rs1 & SignExt(imm)` |
| `SLLI rd, rs1, shamt` | `001` | `0000000` | `rd = rs1 << shamt[4:0]` |
| `SRLI rd, rs1, shamt` | `101` | `0000000` | `rd = rs1 >> shamt[4:0]` (Logical Shift) |
| `SRAI rd, rs1, shamt` | `101` | `0100000` | `rd = signed(rs1) >>> shamt[4:0]` (Arithmetic Shift) |

---

### 2.7 Register-Register ALU Operations
All register-register arithmetic/logical instructions use opcode `0110011` (R-Type format).

| Instruction | Funct3 | Funct7 | Operation |
| :--- | :---: | :---: | :--- |
| `ADD rd, rs1, rs2` | `000` | `0000000` | `rd = rs1 + rs2` |
| `SUB rd, rs1, rs2` | `000` | `0100000` | `rd = rs1 - rs2` |
| `SLL rd, rs1, rs2` | `001` | `0000000` | `rd = rs1 << rs2[4:0]` |
| `SLT rd, rs1, rs2` | `010` | `0000000` | `rd = (signed(rs1) < signed(rs2)) ? 1 : 0` |
| `SLTU rd, rs1, rs2` | `011` | `0000000` | `rd = (unsigned(rs1) < unsigned(rs2)) ? 1 : 0` |
| `XOR rd, rs1, rs2` | `100` | `0000000` | `rd = rs1 ^ rs2` |
| `SRL rd, rs1, rs2` | `101` | `0000000` | `rd = rs1 >> rs2[4:0]` (Logical Shift) |
| `SRA rd, rs1, rs2` | `101` | `0100000` | `rd = signed(rs1) >>> rs2[4:0]` (Arithmetic Shift) |
| `OR rd, rs1, rs2` | `110` | `0000000` | `rd = rs1 \| rs2` |
| `AND rd, rs1, rs2` | `111` | `0000000` | `rd = rs1 & rs2` |

---

## 3. RV32M Standard Extension (Multiplication and Division)

All RV32M instructions use opcode `0110011` (R-Type) with `funct7 = 0000001`.

| Instruction | Funct3 | Operation | Description |
| :--- | :---: | :--- | :--- |
| `MUL rd, rs1, rs2` | `000` | `rd = (rs1 * rs2)[31:0]` | Low 32 bits of signed multiply |
| `MULH rd, rs1, rs2` | `001` | `rd = (signed(rs1) * signed(rs2))[63:32]` | High 32 bits of signed multiply |
| `MULHSU rd, rs1, rs2`| `010` | `rd = (signed(rs1) * unsigned(rs2))[63:32]` | High 32 bits of signed &times; unsigned multiply |
| `MULHU rd, rs1, rs2` | `011` | `rd = (unsigned(rs1) * unsigned(rs2))[63:32]` | High 32 bits of unsigned multiply |
| `DIV rd, rs1, rs2` | `100` | `rd = signed(rs1) / signed(rs2)` | Signed integer division |
| `DIVU rd, rs1, rs2` | `101` | `rd = unsigned(rs1) / unsigned(rs2)` | Unsigned integer division |
| `REM rd, rs1, rs2` | `110` | `rd = signed(rs1) % signed(rs2)` | Signed remainder |
| `REMU rd, rs1, rs2` | `111` | `rd = unsigned(rs1) % unsigned(rs2)` | Unsigned remainder |

> [!NOTE]
> **Division Corner Cases**:
> - Division by zero: `DIV`/`DIVU` returns `0xFFFFFFFF`; `REM`/`REMU` returns `rs1`.
> - Signed overflow: `(-2^31) / -1` returns `-2^31`; remainder returns `0`.

---

## 4. RV32A Standard Extension (Atomic Memory Operations)

All atomic instructions use opcode `0101111` with `funct3 = 010` (word width).

### 4.1 Reservation-Based Atomics (LR/SC)
| Instruction | Funct5 | Description | Semantics |
| :--- | :---: | :--- | :--- |
| `LR.W rd, (rs1)` | `00010` | Load Reserved Word | `rd = Mem32[rs1]`; registers reservation on `rs1` |
| `SC.W rd, rs2, (rs1)` | `00011` | Store Conditional Word | If reservation valid & matches `rs1`:<br>`Mem32[rs1] = rs2`, `rd = 0` (Success).<br>Else: No write, `rd = 1` (Failure). |

---

### 4.2 Read-Modify-Write Atomic Memory Operations (AMO)
Every AMO instruction atomically loads the original 32-bit word from `Mem32[rs1]` into register `rd`, performs the arithmetic/logical operation with `rs2`, and writes the result back into `Mem32[rs1]`.

| Instruction | Funct5 | Atomic Operation Performed | Writeback Value to Memory |
| :--- | :---: | :--- | :--- |
| `AMOSWAP.W rd, rs2, (rs1)` | `00001` | Swap | `rs2` |
| `AMOADD.W rd, rs2, (rs1)` | `00000` | Add | `mem + rs2` |
| `AMOXOR.W rd, rs2, (rs1)` | `00100` | Exclusive OR | `mem ^ rs2` |
| `AMOAND.W rd, rs2, (rs1)` | `01100` | Logical AND | `mem & rs2` |
| `AMOOR.W rd, rs2, (rs1)` | `01000` | Logical OR | `mem \| rs2` |
| `AMOMIN.W rd, rs2, (rs1)` | `10000` | Signed Minimum | `min(signed(mem), signed(rs2))` |
| `AMOMAX.W rd, rs2, (rs1)` | `10100` | Signed Maximum | `max(signed(mem), signed(rs2))` |
| `AMOMINU.W rd, rs2, (rs1)` | `11000` | Unsigned Minimum | `min(unsigned(mem), unsigned(rs2))` |
| `AMOMAXU.W rd, rs2, (rs1)` | `11100` | Unsigned Maximum | `max(unsigned(mem), unsigned(rs2))` |

---

## 5. System & Control/Status Register (CSR) Instructions

All system and CSR instructions use opcode `1110011`.

### 5.1 CSR Register Manipulation
| Instruction | Funct3 | Description | Operation |
| :--- | :---: | :--- | :--- |
| `CSRRW rd, csr, rs1` | `001` | Atomic Read & Write CSR | `rd = CSR; CSR = rs1` |
| `CSRRS rd, csr, rs1` | `010` | Atomic Read & Set Bitmask | `rd = CSR; CSR = CSR \| rs1` |
| `CSRRC rd, csr, rs1` | `011` | Atomic Read & Clear Bitmask | `rd = CSR; CSR = CSR & ~rs1` |
| `CSRRWI rd, csr, uimm`| `101` | Atomic Read & Write Immediate | `rd = CSR; CSR = ZeroExt(uimm[4:0])` |
| `CSRRSI rd, csr, uimm`| `110` | Atomic Read & Set Immediate | `rd = CSR; CSR = CSR \| ZeroExt(uimm[4:0])` |
| `CSRRCI rd, csr, uimm`| `111` | Atomic Read & Clear Immediate | `rd = CSR; CSR = CSR & ~ZeroExt(uimm[4:0])` |

---

### 5.2 Privileged System Control
| Instruction | Funct3 | Funct12 | Description | Semantics |
| :--- | :---: | :---: | :--- | :--- |
| `ECALL` | `000` | `0x000` | Environment Call | Generates an Environment Call exception (`mcause = 11`). |
| `EBREAK` | `000` | `0x001` | Breakpoint | Generates a Breakpoint exception (`mcause = 3`). |
| `MRET` | `000` | `0x302` | Machine Return | Returns from trap: `PC = mepc`; restores privilege status. |
| `WFI` | `000` | `0x105` | Wait for Interrupt | Halts instruction execution until an interrupt occurs. |

---

### 5.3 Implemented Machine-Mode CSRs
| CSR Address | Register Name | Privilege | Description |
| :--- | :--- | :---: | :--- |
| `0x300` | `mstatus` | MRW | Machine status register (Interrupt enables, privilege level) |
| `0x304` | `mie` | MRW | Machine interrupt enable register |
| `0x305` | `mtvec` | MRW | Machine trap-handler base address |
| `0x341` | `mepc` | MRW | Machine exception program counter |
| `0x342` | `mcause` | MRW | Machine trap cause code |
| `0x343` | `mtval` | MRW | Machine bad address / instruction trap value |
| `0x344` | `mip` | MRW | Machine interrupt pending register |
| `0xC00` | `mcycle` | MRO | Elapsed cycle counter (low 32 bits) |
| `0xC02` | `minstret` | MRO | Retired instruction counter (low 32 bits) |
