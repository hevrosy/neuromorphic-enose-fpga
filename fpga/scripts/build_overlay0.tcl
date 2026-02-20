###############################################################################
# build_overlay0.tcl  v4 — fixed IP sub-modules and top module name
#
# Close all projects first, then run:
#   source C:/fpga_work/build_overlay0.tcl
###############################################################################

set proj_dir   "C:/fpga_work/overlay0"
set rtl_dir    "C:/fpga_work/rtl"
set ip_repo    "C:/fpga_work/ip_repo"
set proj_name  "overlay0"
set part       "xc7z020clg400-1"
set board      "tul.com.tw:pynq-z2:part0:1.0"
set ip_root    "${ip_repo}/enose_accel_stub_1.0"

# ─────────────────────────────────────────────────────
#  STEP 1: Create IP manually (no package_project)
# ─────────────────────────────────────────────────────
puts "=========================================="
puts " STEP 1: Create IP (manual)"
puts "=========================================="

# Clean
file delete -force ${ip_root}
file mkdir ${ip_root}
file mkdir ${ip_root}/src

# Copy ALL RTL sources
file copy -force ${rtl_dir}/enose_accel_stub.v ${ip_root}/src/enose_accel_stub.v


# Create component.xml directly via ipx API
# We need a temporary project context for ipx commands
file delete -force ${proj_dir}/ip_pkg
create_project -force ip_pkg ${proj_dir}/ip_pkg -part ${part}

# Create the IP core from scratch
ipx::create_core user.org user enose_accel_stub 1.0
set core [ipx::current_core]

set_property root_directory ${ip_root} $core
set_property name           enose_accel_stub $core
set_property display_name   "E-Nose Accel Stub" $core
set_property description    "Stub accelerator: AXI-Stream popcount + AXI-Lite regs" $core
set_property version        1.0 $core
set_property vendor         user.org $core
set_property library        user $core
set_property taxonomy       /UserIP $core
set_property supported_families {zynq Production} $core

# ── Add source files ──
ipx::add_file_group -type verilog:synthesis xilinx_verilogsynthesis $core
foreach f {enose_accel_stub.v } {
    ipx::add_file src/$f [ipx::get_file_groups xilinx_verilogsynthesis -of_objects $core]
    set_property type verilogSource [ipx::get_files src/$f -of_objects [ipx::get_file_groups xilinx_verilogsynthesis -of_objects $core]]
}
# FORCE the correct top module name
set_property model_name enose_accel_stub [ipx::get_file_groups xilinx_verilogsynthesis -of_objects $core]

# Also add for simulation
ipx::add_file_group -type verilog:simulation xilinx_verilogbehavioralsimulation $core
foreach f {enose_accel_stub.v } {
    ipx::add_file src/$f [ipx::get_file_groups xilinx_verilogbehavioralsimulation -of_objects $core]
    set_property type verilogSource [ipx::get_files src/$f -of_objects [ipx::get_file_groups xilinx_verilogbehavioralsimulation -of_objects $core]]
}
set_property model_name enose_accel_stub [ipx::get_file_groups xilinx_verilogbehavioralsimulation -of_objects $core]

# ── Define ports (must match RTL exactly) ──
# Clock + Reset
ipx::add_port s00_axi_aclk $core
set_property direction in [ipx::get_ports s00_axi_aclk -of_objects $core]
ipx::add_port s00_axi_aresetn $core
set_property direction in [ipx::get_ports s00_axi_aresetn -of_objects $core]

# AXI-Lite slave ports
foreach {pname dir width} {
    s00_axi_awaddr  in  7
    s00_axi_awprot  in  3
    s00_axi_awvalid in  1
    s00_axi_awready out 1
    s00_axi_wdata   in  32
    s00_axi_wstrb   in  4
    s00_axi_wvalid  in  1
    s00_axi_wready  out 1
    s00_axi_bresp   out 2
    s00_axi_bvalid  out 1
    s00_axi_bready  in  1
    s00_axi_araddr  in  7
    s00_axi_arprot  in  3
    s00_axi_arvalid in  1
    s00_axi_arready out 1
    s00_axi_rdata   out 32
    s00_axi_rresp   out 2
    s00_axi_rvalid  out 1
    s00_axi_rready  in  1
} {
    ipx::add_port $pname $core
    set_property direction $dir [ipx::get_ports $pname -of_objects $core]
    if {$width > 1} {
        set_property size_left [expr {$width - 1}] [ipx::get_ports $pname -of_objects $core]
        set_property size_right 0 [ipx::get_ports $pname -of_objects $core]
    }
}

# AXI-Stream slave ports
foreach {pname dir width} {
    s_axis_tdata   in  32
    s_axis_tvalid  in  1
    s_axis_tready  out 1
    s_axis_tlast   in  1
} {
    ipx::add_port $pname $core
    set_property direction $dir [ipx::get_ports $pname -of_objects $core]
    if {$width > 1} {
        set_property size_left [expr {$width - 1}] [ipx::get_ports $pname -of_objects $core]
        set_property size_right 0 [ipx::get_ports $pname -of_objects $core]
    }
}

# ── Clock interface ──
ipx::add_bus_interface s00_axi_aclk $core
set clk_if [ipx::get_bus_interfaces s00_axi_aclk -of_objects $core]
set_property bus_type_vlnv xilinx.com:signal:clock:1.0 $clk_if
set_property abstraction_type_vlnv xilinx.com:signal:clock_rtl:1.0 $clk_if
set_property interface_mode slave $clk_if
ipx::add_port_map CLK $clk_if
set_property physical_name s00_axi_aclk [ipx::get_port_maps CLK -of_objects $clk_if]
ipx::add_bus_parameter ASSOCIATED_BUSIF $clk_if
set_property value {s00_axi:s_axis} [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects $clk_if]
ipx::add_bus_parameter ASSOCIATED_RESET $clk_if
set_property value s00_axi_aresetn [ipx::get_bus_parameters ASSOCIATED_RESET -of_objects $clk_if]

# ── Reset interface ──
ipx::add_bus_interface s00_axi_aresetn $core
set rst_if [ipx::get_bus_interfaces s00_axi_aresetn -of_objects $core]
set_property bus_type_vlnv xilinx.com:signal:reset:1.0 $rst_if
set_property abstraction_type_vlnv xilinx.com:signal:reset_rtl:1.0 $rst_if
set_property interface_mode slave $rst_if
ipx::add_port_map RST $rst_if
set_property physical_name s00_axi_aresetn [ipx::get_port_maps RST -of_objects $rst_if]
ipx::add_bus_parameter POLARITY $rst_if
set_property value ACTIVE_LOW [ipx::get_bus_parameters POLARITY -of_objects $rst_if]

# ── AXI-Lite slave interface ──
ipx::add_bus_interface s00_axi $core
set axi_if [ipx::get_bus_interfaces s00_axi -of_objects $core]
set_property bus_type_vlnv xilinx.com:interface:aximm:1.0 $axi_if
set_property abstraction_type_vlnv xilinx.com:interface:aximm_rtl:1.0 $axi_if
set_property interface_mode slave $axi_if

foreach {log phys} {
    AWADDR  s00_axi_awaddr   AWPROT  s00_axi_awprot
    AWVALID s00_axi_awvalid  AWREADY s00_axi_awready
    WDATA   s00_axi_wdata    WSTRB   s00_axi_wstrb
    WVALID  s00_axi_wvalid   WREADY  s00_axi_wready
    BRESP   s00_axi_bresp    BVALID  s00_axi_bvalid
    BREADY  s00_axi_bready
    ARADDR  s00_axi_araddr   ARPROT  s00_axi_arprot
    ARVALID s00_axi_arvalid  ARREADY s00_axi_arready
    RDATA   s00_axi_rdata    RRESP   s00_axi_rresp
    RVALID  s00_axi_rvalid   RREADY  s00_axi_rready
} {
    ipx::add_port_map $log $axi_if
    set_property physical_name $phys [ipx::get_port_maps $log -of_objects $axi_if]
}

# Memory map
ipx::add_memory_map s00_axi $core
set_property slave_memory_map_ref s00_axi $axi_if
ipx::add_address_block reg0 [ipx::get_memory_maps s00_axi -of_objects $core]
set ab [ipx::get_address_blocks reg0 -of_objects [ipx::get_memory_maps s00_axi -of_objects $core]]
set_property range 128 $ab
set_property usage register $ab
set_property width 32 $ab

# ── AXI-Stream slave interface ──
ipx::add_bus_interface s_axis $core
set axis_if [ipx::get_bus_interfaces s_axis -of_objects $core]
set_property bus_type_vlnv xilinx.com:interface:axis:1.0 $axis_if
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 $axis_if
set_property interface_mode slave $axis_if

foreach {log phys} {
    TDATA  s_axis_tdata   TVALID s_axis_tvalid
    TREADY s_axis_tready  TLAST  s_axis_tlast
} {
    ipx::add_port_map $log $axis_if
    set_property physical_name $phys [ipx::get_port_maps $log -of_objects $axis_if]
}

# ── Parameters (matching RTL defaults) ──
ipx::add_user_parameter C_S00_AXI_DATA_WIDTH $core
set_property value 32 [ipx::get_user_parameters C_S00_AXI_DATA_WIDTH -of_objects $core]
set_property value_format long [ipx::get_user_parameters C_S00_AXI_DATA_WIDTH -of_objects $core]

ipx::add_user_parameter C_S00_AXI_ADDR_WIDTH $core
set_property value 7 [ipx::get_user_parameters C_S00_AXI_ADDR_WIDTH -of_objects $core]
set_property value_format long [ipx::get_user_parameters C_S00_AXI_ADDR_WIDTH -of_objects $core]

# ── Save ──
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::save_core $core
close_project

puts "  \[OK\] IP created at: ${ip_root}"
puts "  Files:"
foreach f [glob -nocomplain ${ip_root}/src/*] { puts "    $f" }

# ─────────────────────────────────────────────────────
#  STEP 2: Create block design
# ─────────────────────────────────────────────────────
puts "=========================================="
puts " STEP 2: Create Block Design"
puts "=========================================="

file delete -force ${proj_dir}/${proj_name}
create_project -force ${proj_name} ${proj_dir}/${proj_name} -part ${part}
set_property board_part ${board} [current_project]
set_property ip_repo_paths ${ip_repo} [current_fileset]
update_ip_catalog

create_bd_design "system"

# ── Zynq PS ──
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1"} $ps

set_property -dict [list \
    CONFIG.PCW_USE_S_AXI_HP0 {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
    CONFIG.PCW_IRQ_F2P_INTR {1} \
] $ps

# ── AXI DMA ──
set dma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0]
set_property -dict [list \
    CONFIG.c_include_s2mm {0} \
    CONFIG.c_include_mm2s {1} \
    CONFIG.c_m_axi_mm2s_data_width {32} \
    CONFIG.c_m_axis_mm2s_tdata_width {32} \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_include_stscntrl_strm {0} \
    CONFIG.c_mm2s_burst_size {16} \
] $dma

# ── Our custom IP ──
set accel [create_bd_cell -type ip -vlnv user.org:user:enose_accel_stub:1.0 enose_accel_0]

# ── Stream: DMA → accel ──
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] \
                    [get_bd_intf_pins enose_accel_0/s_axis]

# ── AXI-Lite: PS → DMA + accel ──
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {Clk_master "Auto" Clk_slave "Auto" Clk_xbar "Auto" \
             Master "/ps7/M_AXI_GP0" Slave "/axi_dma_0/S_AXI_LITE" \
             intc_ip "New AXI Interconnect" master_apm "0"} \
    [get_bd_intf_pins axi_dma_0/S_AXI_LITE]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {Clk_master "Auto" Clk_slave "Auto" Clk_xbar "Auto" \
             Master "/ps7/M_AXI_GP0" Slave "/enose_accel_0/s00_axi" \
             intc_ip "Auto" master_apm "0"} \
    [get_bd_intf_pins enose_accel_0/s00_axi]

# ── HP0: DMA reads DDR ──
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {Clk_master "Auto" Clk_slave "Auto" Clk_xbar "Auto" \
             Master "/axi_dma_0/M_AXI_MM2S" Slave "/ps7/S_AXI_HP0" \
             intc_ip "Auto" master_apm "0"} \
    [get_bd_intf_pins ps7/S_AXI_HP0]

# ── Interrupt ──
connect_bd_net [get_bd_pins axi_dma_0/mm2s_introut] \
               [get_bd_pins ps7/IRQ_F2P]

validate_bd_design
save_bd_design

puts "  \[OK\] Block design validated"

# ─────────────────────────────────────────────────────
#  STEP 3: HDL Wrapper
# ─────────────────────────────────────────────────────
puts "=========================================="
puts " STEP 3: Generate Wrapper"
puts "=========================================="

make_wrapper -files [get_files system.bd] -top
add_files -norecurse ${proj_dir}/${proj_name}/${proj_name}.gen/sources_1/bd/system/hdl/system_wrapper.v
update_compile_order -fileset sources_1

puts "  \[OK\] All done!"
puts ""