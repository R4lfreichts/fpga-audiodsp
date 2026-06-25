catch {close_project}
catch {close_design}

set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize [file join $script_dir ../..]]
set proj_name  "i2s_sine"
set proj_dir   [file join $script_dir vivado_project]

create_project $proj_name $proj_dir -part xc7z007sclg400-1 -force

add_files [file join $root_dir rtl sine_generator i2s_transceiver.vhd]
add_files [file join $root_dir rtl sine_generator i2s_playback.vhd]
add_files [file join $root_dir constraints cons_sine.xdc]

set_property top i2s_playback [current_fileset]

source [file join $script_dir create_clk_wiz.tcl]

update_compile_order -fileset sources_1

