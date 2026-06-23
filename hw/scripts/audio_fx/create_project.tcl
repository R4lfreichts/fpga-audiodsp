catch {terminate_runs synth_1 impl_1}
catch {close_project}
catch {close_design -delete}

set section_name "audio_fx"
set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize [file join $script_dir ../..]]
set proj_name  "audio_fx"
set proj_dir   [file join $script_dir vivado_project]

create_project $proj_name $proj_dir -part xc7z007sclg400-1 -force

add_files [file join $root_dir rtl $section_name audio_fx_top.vhd]
add_files [file join $root_dir rtl $section_name fx_gain.vhd]
add_files [file join $root_dir rtl $section_name i2s_transceiver.vhd]
add_files [file join $root_dir rtl $section_name button_onepulse.vhd]
add_files [file join $root_dir rtl $section_name fx_clipping.vhd]
add_files [file join $root_dir rtl $section_name fx_softclipping.vhd]
add_files [file join $root_dir rtl $section_name fx_delay.vhd]
add_files [file join $root_dir constraints cons_audio_fx.xdc]

source [file join $script_dir create_clk_wiz.tcl]

update_compile_order -fileset sources_1
