# =============================================================================
# File: dc.tcl
# Description: Synopsys Design Compiler Synthesis Script
#              for Minimal RV32IMA Microcontroller (rv32ima_mcu)
#
# Usage:
#   dc_shell -f dc.tcl | tee reports/dc_run.log
#
# PDK: SAED 32nm / 14nm (set SAED_DB path below)
# Target: Gate-level netlist + timing/area reports
# =============================================================================

# =============================================================================
# 0. Path Detection & Project Root Resolution
# =============================================================================
set PROJ_DIR ""
set RUN_DIR  [pwd]

# Check script location if available
set script_dir_guess ""
if {[info script] ne ""} {
    set script_dir_guess [file normalize [file dirname [info script]]]
}

# Candidates checked in priority order:
set candidate_dirs [list \
    [expr {[info exists env(MINIMAL_MCU_DIR)] ? $env(MINIMAL_MCU_DIR) : ""}] \
    [file normalize [file join $RUN_DIR "minimal_mcu"]] \
    "/home/asron/minimal_mcu" \
    "/home/rithicks/minimal_mcu" \
    [file normalize [file join $RUN_DIR ".."]] \
    [file normalize [file join $RUN_DIR "../.."]] \
    [file normalize $RUN_DIR] \
    [expr {$script_dir_guess ne "" ? [file normalize [file join $script_dir_guess ".."]] : ""}] \
    [expr {$script_dir_guess ne "" ? [file normalize [file join $script_dir_guess "../.."]] : ""}] \
    $script_dir_guess \
]

foreach dir $candidate_dirs {
    if {$dir ne "" && [file isdirectory "$dir/rtl"]} {
        set PROJ_DIR [file normalize $dir]
        break
    }
}

if {$PROJ_DIR eq "" || ![file isdirectory "$PROJ_DIR/rtl"]} {
    puts "============================================================"
    puts "\[ERROR\] Could not locate the minimal_mcu/rtl directory!"
    puts "Current directory : [pwd]"
    puts "Please set your project path before sourcing:"
    puts "    set PROJ_DIR \"/path/to/minimal_mcu\""
    puts "    source \$PROJ_DIR/syn/dc.tcl"
    puts "============================================================"
    return
}

# Directory configurations:
set SCRIPT_DIR   [expr {$script_dir_guess ne "" ? $script_dir_guess : "$PROJ_DIR/syn"}]
set DESIGN_TOP   "rv32ima_mcu"

set outputs_dir  "$RUN_DIR/results"
set RESULTS_DIR  $outputs_dir
set REPORTS_DIR  "$RUN_DIR/reports"

file mkdir $outputs_dir
file mkdir $REPORTS_DIR

# =============================================================================
# Multicore / Parallel Processing Configuration
# =============================================================================
# Enable 8 parallel cores (verified working with lab license)
set_host_options -max_cores 16
report_host_options

# Discover PDK directory (checks local project, parent folders, and standard locations)
set PDK_DIR ""
set pdk_candidates [list \
    "$PROJ_DIR/pdk" \
    [file normalize [file join $RUN_DIR "minimal_mcu/pdk"]] \
    "/home/asron/minimal_mcu/pdk" \
    "/home/rithicks/minimal_mcu/pdk" \
    "/home/rithicks/pdk" \
    "/home/asron/pdk" \
    "$RUN_DIR/pdk" \
    "$RUN_DIR/../pdk" \
    "$RUN_DIR/../../pdk" \
]

foreach p $pdk_candidates {
    if {[file isdirectory $p] && [file exists "$p/saed32rvt_ss0p75v125c.db"]} {
        set PDK_DIR [file normalize $p]
        break
    }
}

if {$PDK_DIR eq ""} {
    set PDK_DIR "$PROJ_DIR/pdk"
}

# Explicitly define all 4 SAED library file paths
set SAED_RVT  "$PDK_DIR/saed32rvt_ss0p75v125c.db"
set SAED_HVT  "$PDK_DIR/saed32hvt_ss0p75v125c.db"
set SAED_LVT  "$PDK_DIR/saed32lvt_ss0p75v125c.db"
set SAED_SRAM "$PDK_DIR/saed32sramlp_ss0p75v125c_i0p75v.db"

# Configure Synopsys global search path so all files, scripts, and libraries are found
set_app_var search_path [concat $search_path [list \
    "." \
    $RUN_DIR \
    $PROJ_DIR \
    $SCRIPT_DIR \
    "$PROJ_DIR/syn" \
    $PDK_DIR \
    "$PROJ_DIR/rtl" \
    "$PROJ_DIR/rtl/core" \
    "$PROJ_DIR/rtl/pipeline" \
    "$PROJ_DIR/rtl/bus" \
    "$PROJ_DIR/rtl/memory" \
    "$PROJ_DIR/rtl/peripherals" \
]]

puts "============================================================"
puts " Synopsys Design Compiler - RV32IMA MCU Synthesis"
puts " Project Root : $PROJ_DIR"
puts " Run Dir      : $RUN_DIR"
puts " Reports Dir  : $REPORTS_DIR"
puts " Results Dir  : $outputs_dir"
puts " PDK Dir      : $PDK_DIR"
puts "============================================================"

# Check if PDK directory exists and contains the SAED libraries
if {[file exists $SAED_RVT]} {
    puts "\[INFO\] Found SAED PDK libraries in: $PDK_DIR"
    
    # Target library: RVT standard cells for primary logic mapping
    set_app_var target_library [list [file tail $SAED_RVT] $SAED_RVT]
    
    # Link library: Include wildcard "*", all standard cells (RVT, HVT, LVT) + SRAM macro
    set LINK_LIST [list "*"]
    foreach lib [list $SAED_RVT $SAED_HVT $SAED_LVT $SAED_SRAM] {
        if {[file exists $lib]} {
            lappend LINK_LIST [file tail $lib]
            lappend LINK_LIST $lib
            puts "\[INFO\] Added to link_library: [file tail $lib]"
        }
    }
    catch {
        set_app_var synthetic_library [list standard.sldb]
        lappend LINK_LIST standard.sldb
    }
    set_app_var link_library   $LINK_LIST
    set_app_var symbol_library ""
    
    puts "\[INFO\] Target Library : $target_library"
    puts "\[INFO\] Link Library   : $link_library"
    
} elseif {[info exists env(SAED_DB)] && [file exists $env(SAED_DB)]} {
    puts "\[INFO\] Using SAED target library from env(SAED_DB): $env(SAED_DB)"
    set_app_var target_library [list $env(SAED_DB)]
    set_app_var link_library   [list "*" $env(SAED_DB)]
    set_app_var symbol_library ""
} else {
    puts "============================================================"
    puts "\[ERROR\] SAED PDK libraries not found in '$PDK_DIR'!"
    puts "Please ensure saed32rvt_ss0p75v125c.db exists in '$PDK_DIR'."
    puts "============================================================"
    return
}

# =============================================================================
# 2. Read Source Files
# =============================================================================
# Read all RTL files in strict dependency order with absolute paths
set RTL_FILES [list \
    "$PROJ_DIR/rtl/core/rv32_pkg.sv" \
    "$PROJ_DIR/rtl/core/alu.sv" \
    "$PROJ_DIR/rtl/core/regfile.sv" \
    "$PROJ_DIR/rtl/core/immediate_gen.sv" \
    "$PROJ_DIR/rtl/core/decoder.sv" \
    "$PROJ_DIR/rtl/core/pc_reg.sv" \
    "$PROJ_DIR/rtl/pipeline/if_id.sv" \
    "$PROJ_DIR/rtl/pipeline/id_ex.sv" \
    "$PROJ_DIR/rtl/pipeline/ex_mem.sv" \
    "$PROJ_DIR/rtl/pipeline/mem_wb.sv" \
    "$PROJ_DIR/rtl/core/branch_unit.sv" \
    "$PROJ_DIR/rtl/core/forwarding_unit.sv" \
    "$PROJ_DIR/rtl/core/hazard_unit.sv" \
    "$PROJ_DIR/rtl/core/rv32_core.sv" \
    "$PROJ_DIR/rtl/core/atomic_unit.sv" \
    "$PROJ_DIR/rtl/bus/bus_decoder.sv" \
    "$PROJ_DIR/rtl/memory/rom.sv" \
    "$PROJ_DIR/rtl/memory/ram.sv" \
    "$PROJ_DIR/rtl/memory/saed_sram_wrapper.sv" \
    "$PROJ_DIR/rtl/memory/memory_wrapper.sv" \
    "$PROJ_DIR/rtl/peripherals/uart.sv" \
    "$PROJ_DIR/rtl/peripherals/gpio.sv" \
    "$PROJ_DIR/rtl/rv32ima_mcu.sv" \
]

# Verify and analyze all SystemVerilog files
set missing_count 0
foreach f $RTL_FILES {
    if {![file exists $f]} {
        puts "\[ERROR\] Cannot find RTL file: $f"
        incr missing_count
    }
}
if {$missing_count > 0} {
    puts "\[ERROR\] $missing_count RTL files are missing from $PROJ_DIR/rtl! Aborting."
    return
}

# Reset any previous design in memory to allow clean re-runs
catch { remove_design -designs }

puts "\[INFO\] Analyzing [llength $RTL_FILES] SystemVerilog RTL files in dependency order..."
analyze -format sverilog $RTL_FILES
elaborate $DESIGN_TOP

# Ensure top-level design is active and properly linked
current_design $DESIGN_TOP
link
list_libs
check_design

# =============================================================================
# 3. Uniquify to Avoid Multiple-Driver Issues
# =============================================================================
uniquify

if {[file exists "$RUN_DIR/constraints.sdc"]} {
    puts "\[INFO\] Applying constraints from: $RUN_DIR/constraints.sdc"
    source "$RUN_DIR/constraints.sdc"
} elseif {[file exists "$SCRIPT_DIR/constraints.sdc"]} {
    puts "\[INFO\] Applying constraints from: $SCRIPT_DIR/constraints.sdc"
    source "$SCRIPT_DIR/constraints.sdc"
} elseif {[file exists "$PROJ_DIR/syn/constraints.sdc"]} {
    puts "\[INFO\] Applying constraints from: $PROJ_DIR/syn/constraints.sdc"
    source "$PROJ_DIR/syn/constraints.sdc"
} else {
    puts "\[WARNING\] constraints.sdc not found in run or syn directories!"
}

# =============================================================================
# 5. Synthesis Compile (Standard compile)
# =============================================================================
# Standard compile with timing-driven mapping and low area effort
puts "\[INFO\] Starting standard compile synthesis..."
compile -map_effort medium -area_effort low

# =============================================================================
# 6. Reports
# =============================================================================
report_timing  -path_type full -max_paths 10 > $REPORTS_DIR/timing.rpt
report_area                                  > $REPORTS_DIR/area.rpt
report_power                                 > $REPORTS_DIR/power.rpt
report_constraint -all_violators             > $REPORTS_DIR/violations.rpt
report_design                                > $REPORTS_DIR/design.rpt
report_cell                                  > $REPORTS_DIR/cell.rpt

# =============================================================================
# 7. Write Outputs
# =============================================================================
# Gate-level netlists (.v)
write_file -format verilog -hierarchy -output [file join $outputs_dir rv32_netlist.v]
write_file -format verilog -hier      -output [file join $outputs_dir ${DESIGN_TOP}_netlist.v]

# SDC timing constraints (.sdc)
write_sdc [file join $outputs_dir rv32.sdc]
write_sdc [file join $outputs_dir ${DESIGN_TOP}.sdc]

# Design Database (ddc) and delay format (sdf)
write_file -format ddc -hier -output [file join $outputs_dir ${DESIGN_TOP}.ddc]
write_sdf [file join $outputs_dir ${DESIGN_TOP}.sdf]

puts "============================================================"
puts " Synthesis Complete: $DESIGN_TOP"
puts " Netlist : [file join $outputs_dir rv32_netlist.v]"
puts " SDC     : [file join $outputs_dir rv32.sdc]"
puts " Reports : $REPORTS_DIR/"
puts "============================================================"

# Launch GUI if DISPLAY is available, otherwise complete gracefully
catch {
    if {[info exists env(DISPLAY)] && $env(DISPLAY) ne ""} {
        start_gui
    }
}
