catch {terminate_runs synth_1 impl_1}
catch {close_project}
catch {close_design -delete}

set section_name "bypass"
set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize [file join $script_dir ../..]]
set proj_name  "bypass"
set proj_dir   [file join $script_dir vivado_project]

create_project $proj_name $proj_dir -part xc7z007sclg400-1 -force

add_files [file join $root_dir rtl $section_name i2s_bypass.vhd]
add_files [file join $root_dir rtl $section_name i2s_transceiver.vhd]
add_files [file join $root_dir constraints cons_bypass.xdc]

source [file join $script_dir create_clk_wiz.tcl]

update_compile_order -fileset sources_1
