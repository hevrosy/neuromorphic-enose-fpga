###############################################################################
# build_overlay1.tcl — Packages the Real SNN Core and builds the Block Design
###############################################################################

set proj_dir   "C:/fpga_work/overlay1"
set rtl_dir    "C:/fpga_work/rtl"
set ip_repo    "C:/fpga_work/ip_repo"
set proj_name  "overlay1"
set part       "xc7z020clg400-1"
set board      "tul.com.tw:pynq-z2:part0:1.0"
set ip_root    "${ip_repo}/enose_accel_1.0"

# ─────────────────────────────────────────────────────
#  STEP 1: Create IP manually (Real SNN Core)
# ─────────────────────────────────────────────────────
puts "=========================================="
puts " STEP 1: Create IP (enose_accel)"
puts "=========================================="

# Clean old IP
file delete -force ${ip_root}
file mkdir ${ip_root}
file mkdir ${ip_root}/src

# Copy ALL RTL sources and Memory files
file copy -force ${rtl_dir}/enose_accel.v ${ip_root}/src/enose_accel.v
file copy -force ${rtl_dir}/w1.mem ${ip_root}/src/w1.mem
file copy -force ${rtl_dir}/w2.mem ${ip_root}/src/w2.mem

# Create a temporary project context for ipx commands
file delete -force ${proj_dir}/ip_pkg
create_project -force ip_pkg ${proj_dir}/ip_pkg -part ${part}

# Create the IP core
ipx::create_core user.org user enose_accel 1.0
set core [ipx::current_core]

set_property root_directory ${ip_root} $core
set_property name           enose_accel $core
set_property display_name   "E-Nose SNN Accelerator" $core
set_property description    "Real SNN inference engine: 12-32-3 LIF network" $core
set_property version        1.0 $core
set_property vendor         user.org $core
set_property library        user $core
set_property taxonomy       /UserIP $core
set_property supported_families {zynq Production} $core

# ── Add source files (Synthesis) ──
ipx::add_file_group -type verilog:synthesis xilinx_verilogsynthesis $core
ipx::add_file src/enose_accel.v [ipx::get_file_groups xilinx_verilogsynthesis -of_objects $core]
set_property type verilogSource [ipx::get_files src/enose_accel.v -of_objects [ipx::get_file_groups xilinx_verilogsynthesis -of_objects $core]]

# Add mem files to synthesis
ipx::add_file src/w1.mem [ipx::get_file_groups xilinx_verilogsynthesis -of_objects $core]
set_property type {Memory File} [ipx::get_files src/w1.mem -of_objects [ipx::get_file_groups xilinx_verilogsynthesis -of_objects $core]]
ipx::add_file src/w2.mem [ipx::get_file_groups xilinx_verilogsynthesis -of_objects $core]
set_property type {Memory File} [ipx::get_files src/w2.mem -of_objects [ipx::get_file_groups xilinx_verilogsynthesis -of_objects $core]]

set_property model_name enose_accel [ipx::get_file_groups xilinx_verilogsynthesis -of_objects $core]

# ── Add source files (Simulation) ──
ipx::add_file_group -type verilog:simulation xilinx_verilogbehavioralsimulation $core
ipx::add_file src/enose_accel.v [ipx::get_file_groups xilinx_verilogbehavioralsimulation -of_objects $core]
set_property type verilogSource [ipx::get_files src/enose_accel.v -of_objects [ipx::get_file_groups xilinx_verilogbehavioralsimulation -of_objects $core]]

ipx::add_file src/w1.mem [ipx::get_file_groups xilinx_verilogbehavioralsimulation -of_objects $core]
set_property type {Memory File} [ipx::get_files src/w1.mem -of_objects [ipx::get_file_groups xilinx_verilogbehavioralsimulation -of_objects $core]]
ipx::add_file src/w2.mem [ipx::get_file_groups xilinx_verilogbehavioralsimulation -of_objects $core]
set_property type {Memory File} [ipx::get_files src/w2.mem -of_objects [ipx::get_file_groups xilinx_verilogbehavioralsimulation -of_objects $core]]

set_property model_name enose_accel [ipx::get_file_groups xilinx_verilogbehavioralsimulation -of_objects $core]

# ── Define ports ──
ipx::add_port s00_axi_aclk $core
set_property direction in [ipx::get_ports s00_axi_aclk -of_objects $core]
ipx::add_port s00_axi_aresetn $core
set_property direction in [ipx::get_ports s00_axi_aresetn -of_objects $core]

foreach {pname dir width} {
    s00_axi_awaddr  in  7    s00_axi_awprot  in  3
    s00_axi_awvalid in  1    s00_axi_awready out 1
    s00_axi_wdata   in  32   s00_axi_wstrb   in  4
    s00_axi_wvalid  in  1    s00_axi_wready  out 1
    s00_axi_bresp   out 2    s00_axi_bvalid  out 1
    s00_axi_bready  in  1    s00_axi_araddr  in  7
    s00_axi_arprot  in  3    s00_axi_arvalid in  1
    s00_axi_arready out 1    s00_axi_rdata   out 32
    s00_axi_rresp   out 2    s00_axi_rvalid  out 1
    s00_axi_rready  in  1
} {
    ipx::add_port $pname $core
    set_property direction $dir [ipx::get_ports $pname -of_objects $core]
    if {$width > 1} {
        set_property size_left [expr {$width - 1}] [ipx::get_ports $pname -of_objects $core]
        set_property size_right 0 [ipx::get_ports $pname -of_objects $core]
    }
}

foreach {pname dir width} {
    s_axis_tdata   in  32   s_axis_tvalid  in  1
    s_axis_tready  out 1    s_axis_tlast   in  1
} {
    ipx::add_port $pname $core
    set_property direction $dir [ipx::get_ports $pname -of_objects $core]
    if {$width > 1} {
        set_property size_left [expr {$width - 1}] [ipx::get_ports $pname -of_objects $core]
        set_property size_right 0 [ipx::get_ports $pname -of_objects $core]
    }
}

# ── Bus Interfaces ──
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

ipx::add_bus_interface s00_axi_aresetn $core
set rst_if [ipx::get_bus_interfaces s00_axi_aresetn -of_objects $core]
set_property bus_type_vlnv xilinx.com:signal:reset:1.0 $rst_if
set_property abstraction_type_vlnv xilinx.com:signal:reset_rtl:1.0 $rst_if
set_property interface_mode slave $rst_if
ipx::add_port_map RST $rst_if
set_property physical_name s00_axi_aresetn [ipx::get_port_maps RST -of_objects $rst_if]
ipx::add_bus_parameter POLARITY $rst_if
set_property value ACTIVE_LOW [ipx::get_bus_parameters POLARITY -of_objects $rst_if]

ipx::add_bus_interface s00_axi $core
set axi_if [ipx::get_bus_interfaces s00_axi -of_objects $core]
set_property bus_type_vlnv xilinx.com:interface:aximm:1.0 $axi_if
set_property abstraction_type_vlnv xilinx.com:interface:aximm_rtl:1.0 $axi_if
set_property interface_mode slave $axi_if
foreach {log phys} {
    AWADDR s00_axi_awaddr AWPROT s00_axi_awprot AWVALID s00_axi_awvalid AWREADY s00_axi_awready
    WDATA s00_axi_wdata WSTRB s00_axi_wstrb WVALID s00_axi_wvalid WREADY s00_axi_wready
    BRESP s00_axi_bresp BVALID s00_axi_bvalid BREADY s00_axi_bready
    ARADDR s00_axi_araddr ARPROT s00_axi_arprot ARVALID s00_axi_arvalid ARREADY s00_axi_arready
    RDATA s00_axi_rdata RRESP s00_axi_rresp RVALID s00_axi_rvalid RREADY s00_axi_rready
} { ipx::add_port_map $log $axi_if; set_property physical_name $phys [ipx::get_port_maps $log -of_objects $axi_if] }

ipx::add_memory_map s00_axi $core
set_property slave_memory_map_ref s00_axi $axi_if
ipx::add_address_block reg0 [ipx::get_memory_maps s00_axi -of_objects $core]
set ab [ipx::get_address_blocks reg0 -of_objects [ipx::get_memory_maps s00_axi -of_objects $core]]
set_property range 128 $ab
set_property usage register $ab
set_property width 32 $ab

ipx::add_bus_interface s_axis $core
set axis_if [ipx::get_bus_interfaces s_axis -of_objects $core]
set_property bus_type_vlnv xilinx.com:interface:axis:1.0 $axis_if
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 $axis_if
set_property interface_mode slave $axis_if
foreach {log phys} {
    TDATA s_axis_tdata TVALID s_axis_tvalid TREADY s_axis_tready TLAST s_axis_tlast
} { ipx::add_port_map $log $axis_if; set_property physical_name $phys [ipx::get_port_maps $log -of_objects $axis_if] }

# ── Save ──
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::save_core $core
close_project
puts "  \[OK\] IP created at: ${ip_root}"

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

set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1"} $ps
set_property -dict [list CONFIG.PCW_USE_S_AXI_HP0 {1} CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} CONFIG.PCW_USE_FABRIC_INTERRUPT {1} CONFIG.PCW_IRQ_F2P_INTR {1}] $ps

set dma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0]
set_property -dict [list CONFIG.c_include_s2mm {0} CONFIG.c_include_mm2s {1} CONFIG.c_m_axi_mm2s_data_width {32} CONFIG.c_m_axis_mm2s_tdata_width {32} CONFIG.c_include_sg {0} CONFIG.c_sg_include_stscntrl_strm {0} CONFIG.c_mm2s_burst_size {16}] $dma

set accel [create_bd_cell -type ip -vlnv user.org:user:enose_accel:1.0 enose_accel_0]

connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins enose_accel_0/s_axis]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Clk_master "Auto" Clk_slave "Auto" Clk_xbar "Auto" Master "/ps7/M_AXI_GP0" Slave "/axi_dma_0/S_AXI_LITE" intc_ip "New AXI Interconnect" master_apm "0"} [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Clk_master "Auto" Clk_slave "Auto" Clk_xbar "Auto" Master "/ps7/M_AXI_GP0" Slave "/enose_accel_0/s00_axi" intc_ip "Auto" master_apm "0"} [get_bd_intf_pins enose_accel_0/s00_axi]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Clk_master "Auto" Clk_slave "Auto" Clk_xbar "Auto" Master "/axi_dma_0/M_AXI_MM2S" Slave "/ps7/S_AXI_HP0" intc_ip "Auto" master_apm "0"} [get_bd_intf_pins ps7/S_AXI_HP0]

connect_bd_net [get_bd_pins axi_dma_0/mm2s_introut] [get_bd_pins ps7/IRQ_F2P]

validate_bd_design
save_bd_design
puts "  \[OK\] Block design validated"

# ─────────────────────────────────────────────────────
#  STEP 3: Generate Wrapper & Bitstream (Global Synth)
# ─────────────────────────────────────────────────────
puts "=========================================="
puts " STEP 3: Generate Wrapper & Bitstream"
puts "=========================================="

# Force Global Synthesis to avoid parallel OOC bugs
set_property synth_checkpoint_mode None [get_files system.bd]
generate_target all [get_files system.bd]

make_wrapper -files [get_files system.bd] -top
add_files -norecurse ${proj_dir}/${proj_name}/${proj_name}.gen/sources_1/bd/system/hdl/system_wrapper.v
update_compile_order -fileset sources_1

# Launch runs (reduced to 4 jobs to save RAM)
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "  \[OK\] Bitstream Generation Complete!"