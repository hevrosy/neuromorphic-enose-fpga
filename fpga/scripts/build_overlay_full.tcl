close_project -quiet

set proj_dir   "C:/fpga_work/overlay_edge"
set rtl_dir    "C:/fpga_work/rtl"
set ip_repo    "C:/fpga_work/ip_repo"
set proj_name  "overlay_edge"
set part       "xc7z020clg400-1"
set board      "tul.com.tw:pynq-z2:part0:1.0"

# --------------------------------------------------------
# 0. Изчистване на Кеша
# --------------------------------------------------------
create_project -force temp_proj ${proj_dir}/temp_proj -part ${part}
config_ip_cache -clear_local_cache
close_project
puts "  \[OK\] Кешът е изчистен!"

# --------------------------------------------------------
# 1. Инжектиране на новите тегла и препакетиране на SNN
# --------------------------------------------------------
puts "=========================================="
puts " 1. RE-PACKAGING SNN IP WITH NEW WEIGHTS  "
puts "=========================================="
set ip_root_accel "${ip_repo}/enose_accel_1.0"
file copy -force ${rtl_dir}/w1.mem ${ip_root_accel}/src/w1.mem
file copy -force ${rtl_dir}/w2.mem ${ip_root_accel}/src/w2.mem

create_project -force ip_pkg_accel ${proj_dir}/ip_pkg_accel -part ${part}
add_files -norecurse [glob ${ip_root_accel}/src/*]
set_property top enose_accel [current_fileset]
update_compile_order -fileset sources_1
ipx::package_project -root_dir ${ip_root_accel} -vendor user.org -library user -taxonomy /UserIP -import_files -set_current false
close_project

# --------------------------------------------------------
# 2. Препакетиране на Препроцесора
# --------------------------------------------------------
puts "=========================================="
puts " 2. PACKAGING PREPROCESSOR IP             "
puts "=========================================="
set ip_root_preproc "${ip_repo}/enose_preproc_1.0"
file delete -force ${ip_root_preproc}
file mkdir ${ip_root_preproc}/src
file copy -force ${rtl_dir}/enose_preproc.v ${ip_root_preproc}/src/

create_project -force ip_pkg_preproc ${proj_dir}/ip_pkg_preproc -part ${part}
add_files -norecurse ${ip_root_preproc}/src/enose_preproc.v
set_property top enose_preproc [current_fileset]
update_compile_order -fileset sources_1
ipx::package_project -root_dir ${ip_root_preproc} -vendor user.org -library user -taxonomy /UserIP -import_files -set_current false
close_project

# --------------------------------------------------------
# 3. Изграждане на финалната система
# --------------------------------------------------------
puts "=========================================="
puts " 3. CREATING PURE HARDWARE PIPELINE       "
puts "=========================================="
file delete -force ${proj_dir}/${proj_name}
create_project -force ${proj_name} ${proj_dir}/${proj_name} -part ${part}
set_property board_part ${board} [current_project]
set_property ip_repo_paths ${ip_repo} [current_fileset]
update_ip_catalog

create_bd_design "system"

set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1"} $ps
set_property -dict [list CONFIG.PCW_USE_S_AXI_HP0 {0} CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} CONFIG.PCW_I2C0_PERIPHERAL_ENABLE {1} CONFIG.PCW_I2C0_I2C0_IO {EMIO}] $ps
make_bd_intf_pins_external  [get_bd_intf_pins ps7/IIC_0]
set_property name IIC_BME688 [get_bd_intf_ports IIC_0_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:xadc_wiz:3.3 xadc_wiz_0
set_property -dict [list CONFIG.INTERFACE_SELECTION {Enable_AXI} CONFIG.ENABLE_AXI4STREAM {false} CONFIG.CHANNEL_AVERAGING {16} CONFIG.CHANNEL_ENABLE_VAUXP1_VAUXN1 {true} CONFIG.CHANNEL_ENABLE_VAUXP6_VAUXN6 {true} CONFIG.CHANNEL_ENABLE_VAUXP9_VAUXN9 {true} CONFIG.SEQUENCER_MODE {Continuous} CONFIG.XADC_STARUP_SELECTION {channel_sequencer}] [get_bd_cells xadc_wiz_0]
make_bd_intf_pins_external  [get_bd_intf_pins xadc_wiz_0/Vaux1]
make_bd_intf_pins_external  [get_bd_intf_pins xadc_wiz_0/Vaux6]
make_bd_intf_pins_external  [get_bd_intf_pins xadc_wiz_0/Vaux9]

set accel [create_bd_cell -type ip -vlnv user.org:user:enose_accel:1.0 enose_accel_0]
set preproc [create_bd_cell -type ip -vlnv user.org:user:enose_preproc:1.0 enose_preproc_0]

connect_bd_intf_net [get_bd_intf_pins enose_preproc_0/m_axis] [get_bd_intf_pins enose_accel_0/s_axis]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins enose_preproc_0/s_axi_aclk]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins enose_accel_0/s00_axi_aclk]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/ps7/M_AXI_GP0} Slave {/enose_accel_0/s00_axi} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins enose_accel_0/s00_axi]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/ps7/M_AXI_GP0} Slave {/enose_preproc_0/s_axi} intc_ip {Auto} master_apm {0}}  [get_bd_intf_pins enose_preproc_0/s_axi]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/ps7/M_AXI_GP0} Slave {/xadc_wiz_0/s_axi_lite} intc_ip {Auto} master_apm {0}}  [get_bd_intf_pins xadc_wiz_0/s_axi_lite]

validate_bd_design
save_bd_design

make_wrapper -files [get_files system.bd] -top
add_files -norecurse ${proj_dir}/${proj_name}/${proj_name}.gen/sources_1/bd/system/hdl/system_wrapper.v
set constr_file "${proj_dir}/${proj_name}/${proj_name}.srcs/constrs_1/new/sensors.xdc"
file mkdir [file dirname $constr_file]
set f [open $constr_file w]
puts $f "set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33   PULLUP true } \[get_ports { IIC_BME688_sda_io }\];"
puts $f "set_property -dict { PACKAGE_PIN P16   IOSTANDARD LVCMOS33   PULLUP true } \[get_ports { IIC_BME688_scl_io }\];"
close $f
add_files -fileset constrs_1 -norecurse $constr_file

set_property synth_checkpoint_mode None [get_files system.bd]
generate_target all [get_files system.bd]

puts "=========================================="
puts " 4. RUNNING SYNTHESIS & IMPLEMENTATION    "
puts "=========================================="
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
puts "  \[OK\] BITSTREAM GENERATED SUCCESSFULLY!"

# --------------------------------------------------------
# 5. ЕКСПОРТ НА ДАННИ ЗА ДИСЕРТАЦИЯТА (АКАДЕМИЧНИ РЕПОРТИ)
# --------------------------------------------------------
puts "=========================================="
puts " 5. EXTRACTING DISSERTATION DATA (PPA)    "
puts "=========================================="

set rep_dir "C:/fpga_work/Dissertation_Reports"
file mkdir $rep_dir

# Отваряме реализирания дизайн (Силиция след рутиране)
open_run impl_1

# 1. Използвани ресурси (Общо)
report_utilization -file ${rep_dir}/1_Utilization_Summary.txt -name util_1

# 2. Използвани ресурси (Йерархично) - Показва точно колко заема SNN мрежата спрямо Zynq!
report_utilization -hierarchical -file ${rep_dir}/2_Utilization_Hierarchical.txt

# 3. Оценка на мощността (Консумация в mW) - Доказва, че е Edge AI!
report_power -file ${rep_dir}/3_Power_Consumption.txt -name power_1

# 4. Времеви анализ (Timing & Fmax) - Показва максималната скорост на невронната мрежа
report_timing_summary -file ${rep_dir}/4_Timing_Summary.txt -name timing_1

# 5. Анализ на RAM паметта (Къде са запазени теглата)
report_ram_utilization -file ${rep_dir}/5_BRAM_Details.txt

# 6. Генериране на блок-схема (Архитектура)
write_bd_layout -format pdf -orientation landscape -force ${rep_dir}/6_Hardware_Architecture.pdf

puts "========================================================="
puts "  \[УСПЕХ\] ВСИЧКИ ДАННИ ЗА ДИСЕРТАЦИЯТА СА ГЕНЕРИРАНИ!  "
puts "  Проверете папката: C:/fpga_work/Dissertation_Reports   "
puts "========================================================="