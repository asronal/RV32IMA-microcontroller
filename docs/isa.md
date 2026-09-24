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
| `LUI rd, imm` | `0110111` | U-Type | Load Upper Immediate | $\text{rd} \leftarrow \text{imm} \ll 12$ |
| `AUIPC rd, imm` | `0010111` | U-Type | Add Upper Immediate to PC | $\text{rd} \leftarrow \text{PC} + (\text{imm} \ll 12)$ |

---

### 2.2 Unconditional Jumps
| Instruction | Opcode | Funct3 | Format | Description | Operation |
| :--- | :---: | :---: | :---: | :--- | :--- |
| `JAL rd, offset` | `1101111` | — | J-Type | Jump and Link | $\text{rd} \leftarrow \text{PC} + 4;\; \text{PC} \leftarrow \text{PC} + \text{offset}$ |
| `JALR rd, rs1, offset` | `1100111` | `000` | I-Type | Jump and Link Register | $\text{rd} \leftarrow \text{PC} + 4;\; \text{PC} \leftarrow (\text{rs1} + \text{offset}) \ \& \sim 1$ |

---

### 2.3 Conditional Branches
All branch instructions use opcode `1100011` (B-Type format). The target is calculated as $\text{PC} + \text{imm}$.

| Instruction | Funct3 | Condition Tested | Taken Target |
| :--- | :---: | :--- | :--- |
| `BEQ rs1, rs2, offset` | `000` | $\text{rs1} == \text{rs2}$ | $\text{PC} + \text{imm}$ |
| `BNE rs1, rs2, offset` | `001` | $\text{rs1} \ne \text{rs2}$ | $\text{PC} + \text{imm}$ |
| `BLT rs1, rs2, offset` | `100` | $\text{signed}(\text{rs1}) < \text{signed}(\text{rs2})$ | $\text{PC} + \text{imm}$ |
| `BGE rs1, rs2, offset` | `101` | $\text{signed}(\text{rs1}) \ge \text{signed}(\text{rs2})$ | $\text{PC} + \text{imm}$ |
| `BLTU rs1, rs2, offset` | `110` | $\text{rs1} < \text{rs2}$ (Unsigned) | $\text{PC} + \text{imm}$ |
| `BGEU rs1, rs2, offset` | `111` | $\text{rs1} \ge \text{rs2}$ (Unsigned) | $\text{PC} + \text{imm}$ |

---

### 2.4 Load Instructions
All load instructions use opcode `0000011` (I-Type format). Effective address is $\text{rs1} + \text{offset}$.

| Instruction | Funct3 | Data Width | Extension | Operation |
| :--- | :---: | :---: | :--- | :--- |
| `LB rd, offset(rs1)` | `000` | 8-bit (Byte) | Sign-extended | $\text{rd} \leftarrow \text{SignExt}(\text{Mem8}[\text{rs1} + \text{offset}])$ |
| `LH rd, offset(rs1)` | `001` | 16-bit (Half) | Sign-extended | $\text{rd} \leftarrow \text{SignExt}(\text{Mem16}[\text{rs1} + \text{offset}])$ |
| `LW rd, offset(rs1)` | `010` | 32-bit (Word) | Full 32-bit | $\text{rd} \leftarrow \text{Mem32}[\text{rs1} + \text{offset}]$ |
| `LBU rd, offset(rs1)` | `100` | 8-bit (Byte) | Zero-extended | $\text{rd} \leftarrow \text{ZeroExt}(\text{Mem8}[\text{rs1} + \text{offset}])$ |
| `LHU rd, offset(rs1)` | `101` | 16-bit (Half) | Zero-extended | $\text{rd} \leftarrow \text{ZeroExt}(\text{Mem16}[\text{rs1} + \text{offset}])$ |

---

### 2.5 Store Instructions
All store instructions use opcode `0100011` (S-Type format). Effective address is $\text{rs1} + \text{offset}$.

| Instruction | Funct3 | Data Width | Operation |
| :--- | :---: | :---: | :--- |
| `SB rs2, offset(rs1)` | `000` | 8-bit (Byte) | $\text{Mem8}[\text{rs1} + \text{offset}] \leftarrow \text{rs2}[7:0]$ |
| `SH rs2, offset(rs1)` | `001` | 16-bit (Half) | $\text{Mem16}[\text{rs1} + \text{offset}] \leftarrow \text{rs2}[15:0]$ |
| `SW rs2, offset(rs1)` | `010` | 32-bit (Word) | $\text{Mem32}[\text{rs1} + \text{offset}] \leftarrow \text{rs2}[31:0]$ |

---

### 2.6 Register-Immediate ALU Operations
All immediate arithmetic/logical instructions use opcode `0010011` (I-Type format).

| Instruction | Funct3 | Funct7 | Operation |
| :--- | :---: | :---: | :--- |
| `ADDI rd, rs1, imm` | `000` | — | $\text{rd} \leftarrow \text{rs1} + \text{SignExt}(\text{imm})$ |
| `SLTI rd, rs1, imm` | `010` | — | $\text{rd} \leftarrow (\text{signed}(\text{rs1}) < \text{signed}(\text{imm})) \;?\; 1 : 0$ |
| `SLTIU rd, rs1, imm` | `011` | — | $\text{rd} \leftarrow (\text{rs1} < \text{imm}) \;?\; 1 : 0$ |
| `XORI rd, rs1, imm` | `100` | — | $\text{rd} \leftarrow \text{rs1} \oplus \text{SignExt}(\text{imm})$ |
| `ORI rd, rs1, imm` | `110` | — | $\text{rd} \leftarrow \text{rs1} \mid \text{SignExt}(\text{imm})$ |
| `ANDI rd, rs1, imm` | `111` | — | $\text{rd} \leftarrow \text{rs1} \ \& \ \text{SignExt}(\text{imm})$ |
| `SLLI rd, rs1, shamt` | `001` | `0000000` | $\text{rd} \leftarrow \text{rs1} \ll \text{shamt}[4:0]$ |
| `SRLI rd, rs1, shamt` | `101` | `0000000` | $\text{rd} \leftarrow \text{rs1} \gg \text{shamt}[4:0]$ (Logical Shift) |
| `SRAI rd, rs1, shamt` | `101` | `0100000` | $\text{rd} \leftarrow \text{signed}(\text{rs1}) \ggg \text{shamt}[4:0]$ (Arithmetic Shift) |

---

### 2.7 Register-Register ALU Operations
All register-register arithmetic/logical instructions use opcode `0110011` (R-Type format).

| Instruction | Funct3 | Funct7 | Operation |
| :--- | :---: | :---: | :--- |
| `ADD rd, rs1, rs2` | `000` | `0000000` | $\text{rd} \leftarrow \text{rs1} + \text{rs2}$ |
| `SUB rd, rs1, rs2` | `000` | `0100000` | $\text{rd} \leftarrow \text{rs1} - \text{rs2}$ |
| `SLL rd, rs1, rs2` | `001` | `0000000` | $\text{rd} \leftarrow \text{rs1} \ll \text{rs2}[4:0]$ |
| `SLT rd, rs1, rs2` | `010` | `0000000` | $\text{rd} \leftarrow (\text{signed}(\text{rs1}) < \text{signed}(\text{rs2})) \;?\; 1 : 0$ |
| `SLTU rd, rs1, rs2` | `011` | `0000000` | $\text{rd} \leftarrow (\text{rs1} < \text{rs2}) \;?\; 1 : 0$ |
| `XOR rd, rs1, rs2` | `100` | `0000000` | $\text{rd} \leftarrow \text{rs1} \oplus \text{rs2}$ |
| `SRL rd, rs1, rs2` | `101` | `0000000` | $\text{rd} \leftarrow \text{rs1} \gg \text{rs2}[4:0]$ (Logical Shift) |
| `SRA rd, rs1, rs2` | `101` | `0100000` | $\text{rd} \leftarrow \text{signed}(\text{rs1}) \ggg \text{rs2}[4:0]$ (Arithmetic Shift) |
| `OR rd, rs1, rs2` | `110` | `0000000` | $\text{rd} \leftarrow \text{rs1} \mid \text{rs2}$ |
| `AND rd, rs1, rs2` | `111` | `0000000` | $\text{rd} \leftarrow \text{rs1} \ \& \ \text{rs2}$ |

---

## 3. RV32M Standard Extension (Multiplication and Division)

All RV32M instructions use opcode `0110011` (R-Type) with `funct7 = 0000001`.

| Instruction | Funct3 | Operation | Description |
| :--- | :---: | :--- | :--- |
| `MUL rd, rs1, rs2` | `000` | $\text{rd} \leftarrow (\text{rs1} \times \text{rs2})[31:0]$ | Low 32 bits of signed $\times$ signed multiply |
| `MULH rd, rs1, rs2` | `001` | $\text{rd} \leftarrow (\text{signed}(\text{rs1}) \times \text{signed}(\text{rs2}))[63:32]$ | High 32 bits of signed $\times$ signed multiply |
| `MULHSU rd, rs1, rs2`| `010` | $\text{rd} \leftarrow (\text{signed}(\text{rs1}) \times \text{unsigned}(\text{rs2}))[63:32]$ | High 32 bits of signed $\times$ unsigned multiply |
| `MULHU rd, rs1, rs2` | `011` | $\text{rd} \leftarrow (\text{unsigned}(\text{rs1}) \times \text{unsigned}(\text{rs2}))[63:32]$ | High 32 bits of unsigned $\times$ unsigned multiply |
| `DIV rd, rs1, rs2` | `100` | $\text{rd} \leftarrow \text{signed}(\text{rs1}) / \text{signed}(\text{rs2})$ | Signed integer division |
| `DIVU rd, rs1, rs2` | `101` | $\text{rd} \leftarrow \text{unsigned}(\text{rs1}) / \text{unsigned}(\text{rs2})$ | Unsigned integer division |
| `REM rd, rs1, rs2` | `110` | $\text{rd} \leftarrow \text{signed}(\text{rs1}) \pmod{\text{signed}(\text{rs2})}$ | Signed remainder |
| `REMU rd, rs1, rs2` | `111` | $\text{rd} \leftarrow \text{unsigned}(\text{rs1}) \pmod{\text{unsigned}(\text{rs2})}$ | Unsigned remainder |

> [!NOTE]
> **Division Corner Cases**:
> - Division by zero: `DIV`/`DIVU` returns `32'hFFFF_FFFF`; `REM`/`REMU` returns `rs1`.
> - Signed overflow: `(-2^31) / -1` returns `-2^31`; remainder returns `0`.

---

## 4. RV32A Standard Extension (Atomic Memory Operations)

All atomic instructions use opcode `0101111` with `funct3 = 010` (word width).

### 4.1 Reservation-Based Atomics (LR/SC)
| Instruction | Funct5 | Description | Semantics |
| :--- | :---: | :--- | :--- |
| `LR.W rd, (rs1)` | `00010` | Load Reserved Word | $\text{rd} \leftarrow \text{Mem32}[\text{rs1}]$; Registers reservation on $\text{rs1}$. |
| `SC.W rd, rs2, (rs1)` | `00011` | Store Conditional Word | If reservation is valid and address matches $\text{rs1}$: $\text{Mem32}[\text{rs1}] \leftarrow \text{rs2},\; \text{rd} \leftarrow 0$ (Success).<br>Else: No write, $\text{rd} \leftarrow 1$ (Failure). |

---

### 4.2 Read-Modify-Write Atomic Memory Operations (AMO)
Every AMO instruction atomically loads the original 32-bit word from $\text{Mem32}[\text{rs1}]$ into register $\text{rd}$, performs the arithmetic/logical operation with $\text{rs2}$, and writes the result back into $\text{Mem32}[\text{rs1}]$.

| Instruction | Funct5 | Atomic Operation Performed | Writeback Value to Memory |
| :--- | :---: | :--- | :--- |
| `AMOSWAP.W rd, rs2, (rs1)` | `00001` | Swap | $\text{rs2}$ |
| `AMOADD.W rd, rs2, (rs1)` | `00000` | Add | $\text{mem} + \text{rs2}$ |
| `AMOXOR.W rd, rs2, (rs1)` | `00100` | Exclusive OR | $\text{mem} \oplus \text{rs2}$ |
| `AMOAND.W rd, rs2, (rs1)` | `01100` | Logical AND | $\text{mem} \ \& \ \text{rs2}$ |
| `AMOOR.W rd, rs2, (rs1)` | `01000` | Logical OR | $\text{mem} \mid \text{rs2}$ |
| `AMOMIN.W rd, rs2, (rs1)` | `10000` | Signed Minimum | $\min(\text{signed}(\text{mem}),\; \text{signed}(\text{rs2}))$ |
| `AMOMAX.W rd, rs2, (rs1)` | `10100` | Signed Maximum | $\max(\text{signed}(\text{mem}),\; \text{signed}(\text{rs2}))$ |
| `AMOMINU.W rd, rs2, (rs1)` | `11000` | Unsigned Minimum | $\min(\text{unsigned}(\text{mem}),\; \text{unsigned}(\text{rs2}))$ |
| `AMOMAXU.W rd, rs2, (rs1)` | `11100` | Unsigned Maximum | $\max(\text{unsigned}(\text{mem}),\; \text{unsigned}(\text{rs2}))$ |

---

## 5. System & Control/Status Register (CSR) Instructions

All system and CSR instructions use opcode `1110011`.

### 5.1 CSR Register Manipulation
| Instruction | Funct3 | Description | Operation |
| :--- | :---: | :--- | :--- |
| `CSRRW rd, csr, rs1` | `001` | Atomic Read & Write CSR | $\text{rd} \leftarrow \text{CSR};\; \text{CSR} \leftarrow \text{rs1}$ |
| `CSRRS rd, csr, rs1` | `010` | Atomic Read & Set Bitmask | $\text{rd} \leftarrow \text{CSR};\; \text{CSR} \leftarrow \text{CSR} \mid \text{rs1}$ |
| `CSRRC rd, csr, rs1` | `011` | Atomic Read & Clear Bitmask | $\text{rd} \leftarrow \text{CSR};\; \text{CSR} \leftarrow \text{CSR} \ \& \sim\text{rs1}$ |
| `CSRRWI rd, csr, uimm`| `101` | Atomic Read & Write Immediate | $\text{rd} \leftarrow \text{CSR};\; \text{CSR} \leftarrow \text{ZeroExt}(\text{uimm}[4:0])$ |
| `CSRRSI rd, csr, uimm`| `110` | Atomic Read & Set Immediate | $\text{rd} \leftarrow \text{CSR};\; \text{CSR} \leftarrow \text{CSR} \mid \text{ZeroExt}(\text{uimm}[4:0])$ |
| `CSRRCI rd, csr, uimm`| `111` | Atomic Read & Clear Immediate | $\text{rd} \leftarrow \text{CSR};\; \text{CSR} \leftarrow \text{CSR} \ \& \sim\text{ZeroExt}(\text{uimm}[4:0])$ |

---

### 5.2 Privileged System Control
| Instruction | Funct3 | Funct12 | Description | Semantics |
| :--- | :---: | :---: | :--- | :--- |
| `ECALL` | `000` | `0x000` | Environment Call | Generates an Environment Call exception (`mcause = 11`). |
| `EBREAK` | `000` | `0x001` | Breakpoint | Generates a Breakpoint exception (`mcause = 3`). |
| `MRET` | `000` | `0x302` | Machine Return | Returns from trap: $\text{PC} \leftarrow \text{mepc}$; restores privilege status. |
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
