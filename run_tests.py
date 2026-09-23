#!/usr/bin/env python3
import subprocess
import os
import re
import json

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SW_DIR = os.path.join(BASE_DIR, "sw")

# Ensure firmware is compiled
subprocess.run(["make", "-C", SW_DIR], capture_output=True, text=True, cwd=BASE_DIR)

# Stage firmware hex into sim/ AND root (iverilog $readmemh resolves relative to sim cwd)
fw_hex = os.path.join(SW_DIR, "build", "firmware.hex")
if os.path.exists(fw_hex):
    import shutil
    os.makedirs(os.path.join(BASE_DIR, "sim"), exist_ok=True)
    shutil.copy(fw_hex, os.path.join(BASE_DIR, "sim", "firmware.hex"))

SIM_BIN_DIR = os.path.join(BASE_DIR, "sim")
os.makedirs(SIM_BIN_DIR, exist_ok=True)


RTL_CORE = [
    "rtl/core/rv32_pkg.sv",
    "rtl/core/alu.sv",
    "rtl/core/regfile.sv",
    "rtl/core/immediate_gen.sv",
    "rtl/core/decoder.sv",
    "rtl/core/pc_reg.sv",
    "rtl/pipeline/if_id.sv",
    "rtl/pipeline/id_ex.sv",
    "rtl/pipeline/ex_mem.sv",
    "rtl/pipeline/mem_wb.sv",
    "rtl/core/branch_unit.sv",
    "rtl/core/forwarding_unit.sv",
    "rtl/core/hazard_unit.sv",
    "rtl/core/rv32_core.sv",
    "rtl/core/atomic_unit.sv",
]
RTL_BUS = ["rtl/bus/bus_decoder.sv"]
RTL_MEM = [
    "rtl/memory/rom.sv",
    "rtl/memory/ram.sv",
    "rtl/memory/saed_sram_wrapper.sv",
    "rtl/memory/memory_wrapper.sv",
]
RTL_PERIPH = [
    "rtl/peripherals/uart.sv",
    "rtl/peripherals/gpio.sv",
]
RTL_TOP = ["rtl/rv32ima_mcu.sv"]
ALL_RTL = RTL_CORE + RTL_BUS + RTL_MEM + RTL_PERIPH + RTL_TOP

TESTS = [
    {"phase": "Phase 1", "module": "alu.sv", "tb": "tb/tb_alu.sv", "srcs": ["rtl/core/rv32_pkg.sv", "rtl/core/alu.sv"]},
    {"phase": "Phase 1", "module": "regfile.sv", "tb": "tb/tb_regfile.sv", "srcs": ["rtl/core/rv32_pkg.sv", "rtl/core/regfile.sv"]},
    {"phase": "Phase 1", "module": "immediate_gen.sv", "tb": "tb/tb_immediate_gen.sv", "srcs": ["rtl/core/rv32_pkg.sv", "rtl/core/immediate_gen.sv"]},
    {"phase": "Phase 1", "module": "decoder.sv", "tb": "tb/tb_decoder.sv", "srcs": ["rtl/core/rv32_pkg.sv", "rtl/core/decoder.sv"]},
    {"phase": "Phase 2", "module": "pipeline_regs", "tb": "tb/tb_pipeline_regs.sv", "srcs": ["rtl/core/rv32_pkg.sv", "rtl/core/pc_reg.sv", "rtl/pipeline/if_id.sv", "rtl/pipeline/id_ex.sv", "rtl/pipeline/ex_mem.sv", "rtl/pipeline/mem_wb.sv"]},
    {"phase": "Phase 3", "module": "branch_unit.sv", "tb": "tb/tb_branch_unit.sv", "srcs": ["rtl/core/rv32_pkg.sv", "rtl/core/branch_unit.sv"]},
    {"phase": "Phase 4", "module": "forwarding_unit.sv", "tb": "tb/tb_forwarding_unit.sv", "srcs": ["rtl/core/rv32_pkg.sv", "rtl/core/forwarding_unit.sv"]},
    {"phase": "Phase 4", "module": "hazard_unit.sv", "tb": "tb/tb_hazard_unit.sv", "srcs": ["rtl/core/rv32_pkg.sv", "rtl/core/hazard_unit.sv"]},
    {"phase": "Phase 5", "module": "rv32_core.sv", "tb": "tb/tb_core.sv", "srcs": RTL_CORE},
    {"phase": "Phase 6", "module": "atomic_unit.sv", "tb": "tb/tb_atomic_unit.sv", "srcs": ["rtl/core/rv32_pkg.sv", "rtl/core/atomic_unit.sv"]},
    {"phase": "Phase 7", "module": "bus_decoder + memory_wrapper", "tb": "tb/tb_memory.sv", "srcs": ["rtl/core/rv32_pkg.sv", "rtl/bus/bus_decoder.sv"] + RTL_MEM},
    {"phase": "Phase 8", "module": "uart.sv", "tb": "tb/tb_uart.sv", "srcs": ["rtl/core/rv32_pkg.sv", "rtl/peripherals/uart.sv"]},
    {"phase": "Phase 9", "module": "gpio.sv", "tb": "tb/tb_gpio.sv", "srcs": ["rtl/core/rv32_pkg.sv", "rtl/peripherals/gpio.sv"]},
    {"phase": "Phase 10", "module": "rv32ima_mcu.sv (Full SoC)", "tb": "tb/tb_mcu.sv", "srcs": ALL_RTL},
]

incdirs = [
    "-I", "rtl/core",
    "-I", "rtl/pipeline",
    "-I", "rtl/bus",
    "-I", "rtl/memory",
    "-I", "rtl/peripherals",
    "-I", "."
]

stats = []
total_checks_passed = 0
total_checks_failed = 0

for t in TESTS:
    tb_basename = os.path.basename(t["tb"]).replace(".sv", "")
    out_bin = os.path.join(SIM_BIN_DIR, f"sim_{tb_basename}")
    cmd_comp = ["iverilog", "-g2012"] + incdirs + [os.path.join(BASE_DIR, s) for s in t["srcs"]] + [os.path.join(BASE_DIR, t["tb"]), "-o", out_bin]
    
    comp = subprocess.run(cmd_comp, capture_output=True, text=True, cwd=BASE_DIR)
    if comp.returncode != 0:
        stats.append({
            "phase": t["phase"],
            "module": t["module"],
            "tb": os.path.basename(t["tb"]),
            "status": "COMPILE_FAIL",
            "passed_checks": 0,
            "failed_checks": 0,
            "sim_time": "N/A",
            "details": comp.stderr.strip()
        })
        continue
    
    sim = subprocess.run([out_bin], capture_output=True, text=True, cwd=BASE_DIR, timeout=40)
    out = sim.stdout + sim.stderr
    
    # Extract pass/fail checks
    pass_matches = re.findall(r"\[PASS\]", out)
    fail_matches = re.findall(r"\[FAIL\]", out)
    num_pass = len(pass_matches)
    num_fail = len(fail_matches)
    
    # Also look for ALL X TESTS PASSED
    all_passed_match = re.search(r"ALL\s+(\d+)\s+.*PASSED", out)
    if all_passed_match and num_pass == 0:
        num_pass = int(all_passed_match.group(1))
    
    # Extract simulation finish time
    time_match = re.search(r"\$finish called at (\d+)\s*\((\w+)\)", out)
    sim_time = f"{time_match.group(1)} {time_match.group(2)}" if time_match else "Completed"
    
    # Status
    status = "PASS" if num_fail == 0 and sim.returncode == 0 else "FAIL"
    
    # Extra details like UART string
    details = ""
    if "tb_mcu" in t["tb"]:
        # Find UART print output
        rx_match = re.search(r"Received (\d+) UART characters", out)
        if rx_match:
            details = f"Firmware executed, {rx_match.group(0)}"
    
    stats.append({
        "phase": t["phase"],
        "module": t["module"],
        "tb": os.path.basename(t["tb"]),
        "status": status,
        "passed_checks": num_pass,
        "failed_checks": num_fail,
        "sim_time": sim_time,
        "details": details,
        "raw_out": out
    })
    total_checks_passed += num_pass
    total_checks_failed += num_fail
    if os.path.exists(out_bin):
        os.remove(out_bin)

print(json.dumps({
    "total_testbenches": len(TESTS),
    "testbenches_passed": sum(1 for s in stats if s["status"] == "PASS"),
    "testbenches_failed": sum(1 for s in stats if s["status"] != "PASS"),
    "total_checks_passed": total_checks_passed,
    "total_checks_failed": total_checks_failed,
    "breakdown": [{k: v for k, v in s.items() if k != "raw_out"} for s in stats]
}, indent=2))

# Also print SoC test output log
soc_stat = next(s for s in stats if "tb_mcu" in s["tb"])
print("\n=== FULL SOC TESTBENCH RUN LOG (tb_mcu.sv) ===")
print(soc_stat["raw_out"])

# Generate visualizer/data.js if sim_cycles.tsv exists
TSV_FILE = os.path.join(BASE_DIR, "sim", "sim_cycles.tsv")
if not os.path.exists(TSV_FILE):
    TSV_FILE = os.path.join(BASE_DIR, "sim_cycles.tsv")
LST_FILE = os.path.join(BASE_DIR, "sw", "build", "firmware.lst")
OUT_DIR = os.path.join(BASE_DIR, "visualizer")
os.makedirs(OUT_DIR, exist_ok=True)
OUT_JS = os.path.join(OUT_DIR, "data.js")

if os.path.exists(TSV_FILE) and os.path.exists(LST_FILE):
    disasm_map = {}
    symbols = {}
    with open(LST_FILE, "r") as f:
        curr_symbol = ""
        for line in f:
            sym_match = re.match(r"^([0-9a-fA-F]+)\s+<([^>]+)>:", line.strip())
            if sym_match:
                addr = int(sym_match.group(1), 16)
                curr_symbol = sym_match.group(2)
                symbols[curr_symbol] = f"0x{addr:08x}"
                continue
            instr_match = re.match(r"^\s*([0-9a-fA-F]+):\s+([0-9a-fA-F]+)\s+([^\n#;]+)", line)
            if instr_match:
                addr = int(instr_match.group(1), 16)
                hex_code = instr_match.group(2).lower()
                asm_text = instr_match.group(3).strip()
                disasm_map[f"{addr:08x}"] = {"hex": hex_code, "asm": asm_text, "symbol": curr_symbol}

    def get_disasm(hex_addr):
        addr_str = hex_addr.lower().replace("0x", "").zfill(8)
        if addr_str in disasm_map:
            return disasm_map[addr_str]["asm"]
        return "nop"

    ABI_NAMES = ["zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0/fp", "s1", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"]
    cycles_data = []
    curr_uart_str = ""
    events = []

    with open(TSV_FILE, "r") as f:
        headers = f.readline().strip().split("\t")
        prev_regs = ["00000000"] * 32
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) < len(headers):
                continue
            row = dict(zip(headers, parts))
            c_num = int(row["cycle"])
            regs = [row[f"x{r}"] for r in range(32)]
            changed_regs = []
            for r in range(32):
                if regs[r] != prev_regs[r]:
                    changed_regs.append({"reg": r, "name": ABI_NAMES[r], "old": prev_regs[r], "new": regs[r]})
            prev_regs = list(regs)

            if_dis = get_disasm(row["if_pc"])
            id_dis = get_disasm(row["id_pc"])
            ex_dis = get_disasm(row["ex_pc"])
            mem_dis = get_disasm(row["mem_pc"])

            if row["bus_uart"] == "1" and row["dmem_write"] == "1" and row["dmem_addr"].startswith("20000000"):
                val = int(row["dmem_wdata"][-2:], 16)
                ch = chr(val) if 32 <= val <= 126 else ("\\n" if val == 10 else "\\r" if val == 13 else f"\\x{val:02x}")
                curr_uart_str += chr(val) if 32 <= val <= 126 or val == 10 else ""
                events.append({"cycle": c_num, "title": f"UART Output: '{ch}'", "desc": f"CPU wrote char 0x{val:02x} to UART_TXDATA"})

            if c_num == 1:
                events.append({"cycle": 1, "title": "Reset Released", "desc": "MCU begins fetch from Boot ROM (0x00000000)"})
            elif id_dis.startswith("csrw mtvec"):
                events.append({"cycle": c_num, "title": "Trap Vector Set", "desc": "Machine trap vector mtvec pointed to trap_handler"})
            elif id_dis.startswith("addi sp,sp,-16"):
                events.append({"cycle": c_num, "title": "Stack Pointer Initialized", "desc": "SP set to 0x10008000 (Top of 32 KB SRAM)"})
            elif id_dis.startswith("jal d8") or id_dis.startswith("jal 0xd8") or (row["id_pc"] == "00000074"):
                events.append({"cycle": c_num, "title": "Jump to main()", "desc": "Firmware jumps to C entry point main()"})
            elif row["bus_gpio"] == "1" and row["dmem_write"] == "1":
                events.append({"cycle": c_num, "title": "GPIO Write", "desc": f"Address 0x{row['dmem_addr']}: data 0x{row['dmem_wdata']}"})

            cycle_entry = {
                "c": c_num, "t": row["time_ns"],
                "if": {"pc": row["if_pc"], "raw": row["if_instr"], "asm": if_dis},
                "id": {"pc": row["id_pc"], "raw": row["id_instr"], "asm": id_dis, "rs1": int(row["id_rs1"]), "rs2": int(row["id_rs2"]), "rd": int(row["id_rd"])},
                "ex": {"pc": row["ex_pc"], "alu": row["ex_alu"], "asm": ex_dis, "fwd_a": int(row["fwd_a"]), "fwd_b": int(row["fwd_b"])},
                "mem": {"pc": row["mem_pc"], "asm": mem_dis, "addr": row["dmem_addr"], "wdata": row["dmem_wdata"], "we": int(row["dmem_write"]), "rdata": row["dmem_rdata"], "re": int(row["dmem_read"])},
                "wb": {"rd": int(row["wb_rd"]), "we": int(row["wb_we"]), "data": row["wb_data"]},
                "hz": {"stall": int(row["stall"]), "flush": int(row["flush"])},
                "bus": {"rom": int(row["bus_rom"]), "ram": int(row["bus_ram"]), "uart": int(row["bus_uart"]), "gpio": int(row["bus_gpio"])},
                "uart": {"tx": int(row["uart_tx"]), "ready": int(row["uart_ready"]), "term": curr_uart_str},
                "gpio": {"out": row["gpio_out"], "oe": row["gpio_oe"], "in": row["gpio_in"]},
                "diff_regs": changed_regs, "regs": regs
            }
            cycles_data.append(cycle_entry)

    out_payload = {
        "summary": {"total_cycles": len(cycles_data), "clock_mhz": 10, "period_ns": 100, "uart_baud": 625000, "final_uart": curr_uart_str, "symbols": symbols, "abi_names": ABI_NAMES},
        "disassembly": disasm_map, "events": events, "cycles": cycles_data
    }
    with open(OUT_JS, "w") as f:
        f.write("window.SIM_DATA = ")
        json.dump(out_payload, f)
        f.write(";\n")
    print(f"[INFO] Generated visualizer data: {OUT_JS} ({os.path.getsize(OUT_JS) // 1024} KB)")

