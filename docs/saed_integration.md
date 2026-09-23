# SAED SRAM Macro Integration Guide

This document explains the complete process for integrating a SAED PDK SRAM hard macro into the memory subsystem of the **Minimal RV32IMA MCU**.

---

## 1. Overview

The memory subsystem uses a compile-time macro switch:

```
memory_wrapper.sv
    │
    ├─── `ifdef USE_SAED_MEMORY  ─────> saed_sram_wrapper.sv  (ASIC with PDK macro)
    │
    └─── `else (default)          ─────> ram.sv                (Generic RTL / simulation)
```

The CPU core and bus decoder are **fully insulated** from PDK-specific details. Only `saed_sram_wrapper.sv` references macro pin names.

---

## 2. Step-by-Step Integration

### Step 1: Obtain SRAM Macro from SAED PDK Memory Compiler

Use the SAED memory compiler to generate an SRAM matching the required configuration:

| Parameter | Value |
| :--- | :--- |
| Organization | 8192 words × 32 bits |
| Capacity | 32 KB |
| Port type | Single-port (SP) |
| Write enables | Per-bit byte enable (`BWEN[31:0]`, active-low) |
| Interface | Synchronous |

The memory compiler will deliver:
- `*.lib` / `*.db` — Liberty timing model (for DC synthesis)
- `*.lef` — Layout abstract (for PnR)
- `*.v` / `*.sv` — Behavioral model (for simulation)
- `*.gds` — Physical layout (for tapeout)

---

### Step 2: Update `saed_sram_wrapper.sv`

Open [`rtl/memory/saed_sram_wrapper.sv`](file:///c:/projects/minimal_mcu/rtl/memory/saed_sram_wrapper.sv) and **replace the behavioral stub** with the actual macro instantiation. The wiring is already prepared:

```systemverilog
// Control signals are already derived:
//   cen_n  = ~en         (Active-low chip enable)
//   wen_n  = ~we         (Active-low write enable)
//   bwen_n = byte-to-bit expanded ~wstrb  (Active-low per-bit write enable)
//   word_addr = addr[ADDR_BITS+1:2]       (Word-indexed address)

// Insert your macro here (example - replace with your exact macro name):
SAED32_SRAM_SP_8192X32 u_saed_sram (
  .CLK    (clk),
  .CEN    (cen_n),
  .WEN    (wen_n),
  .BWEN   (bwen_n),
  .A      (word_addr),
  .D      (wdata),
  .Q      (rdata)
);
```

---

### Step 3: Add Macro Library to `dc.tcl`

In [`syn/dc.tcl`](file:///c:/projects/minimal_mcu/syn/dc.tcl), update the library variables to include the SRAM macro `.db`:

```tcl
set SAED_STDCELL_DB  "/path/to/saed_pdk/lib/stdcells_tt.db"
set SAED_SRAM_DB     "/path/to/saed_memory/lib/saed_sram_8192x32_tt.db"

set_app_var target_library  [list $SAED_STDCELL_DB $SAED_SRAM_DB]
set_app_var link_library    [list $SAED_STDCELL_DB $SAED_SRAM_DB "*"]
```

---

### Step 4: Compile with `USE_SAED_MEMORY` Defined

**For RTL Simulation (no macro, behavioral stub):**
```bash
vcs -sverilog -f sim/filelist.f -top tb_mcu
```

**For Gate-Level Simulation / Synthesis (with SAED macro):**
```bash
vcs -sverilog +define+USE_SAED_MEMORY -f sim/filelist.f ...
```

**For Synopsys DC Synthesis:**
```bash
dc_shell -f syn/dc.tcl | tee syn/reports/dc_run.log
# dc.tcl uses: analyze -format sverilog -define {USE_SAED_MEMORY} ...
```

> [!NOTE]
> Add `-define {USE_SAED_MEMORY}` to the `analyze` command in `dc.tcl` when running synthesis with the macro.

---

## 3. Pin Mapping Reference

| Generic Bus Signal | SAED SRAM Pin | Polarity | Notes |
| :--- | :--- | :--- | :--- |
| `clk` | `CLK` | Active-high edge | — |
| `~en` | `CEN` | Active-low | Chip enable |
| `~we` | `WEN` | Active-low | Write enable |
| `{8{~wstrb[3]},...,8{~wstrb[0]}}` | `BWEN[31:0]` | Active-low | Per-bit byte mask |
| `addr[ADDR_BITS+1:2]` | `A[12:0]` | — | Word index |
| `wdata[31:0]` | `D[31:0]` | — | Write data |
| `rdata[31:0]` | `Q[31:0]` | — | Read data |

---

## 4. Read Data Timing

SAED SRAM macros deliver read data **one clock cycle after the read address and CEN are applied**. The current `bus_decoder.sv` returns `dmem_ready = 1` unconditionally (zero wait-state). If your macro has a 1-cycle read latency, this is already compatible with the synchronous pipeline since the MEM stage occupies one full clock.

> [!WARNING]
> If your macro requires more than 1-cycle read latency (e.g., pipelined SRAM), you must:
> 1. Add a wait-state counter in `bus_decoder.sv` and deassert `dmem_ready` for the required cycles.
> 2. The `hazard_unit.sv` already stalls the pipeline on `~dmem_ready` — no changes needed to the core.

---

## 5. Verification After Integration

After inserting the real macro:

1. Run gate-level simulation with the SRAM behavioral model:
   ```bash
   vcs +define+USE_SAED_MEMORY -f sim/filelist.f -top tb_memory
   vcs +define+USE_SAED_MEMORY -f sim/filelist.f -top tb_mcu
   ```
2. Run Synopsys DC synthesis to confirm no `unresolved references` for the macro.
3. Check `syn/reports/timing.rpt` — the SRAM critical path (read access time) will determine the achievable clock frequency.
