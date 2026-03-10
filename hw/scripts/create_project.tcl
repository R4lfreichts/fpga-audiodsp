set proj_name "i2s_sine"
set proj_dir  "./vivado_project"

create_project $proj_name $proj_dir -part xc7z007sclg400-1 -force

add_files ../rtl/i2s_transceiver.vhd
add_files ../rtl/i2s_playback.vhd
add_files ../constraints/cora_z7_i2s.xdc

set_property top i2s_playback [current_fileset]

source ./create_clk_wiz.tcl

update_compile_order -fileset sources_1
save_project_as $proj_name $proj_dir -force