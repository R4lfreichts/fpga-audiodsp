catch {terminate_runs synth_1 impl_1}
catch {close_project}
catch {close_design -delete}

set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize [file join $script_dir ..]]
set proj_name  "i2s_sine"
set proj_dir   [file join $script_dir vivado_project]

create_project $proj_name $proj_dir -part xc7z007sclg400-1 -force

add_files [file join $root_dir rtl i2s_transceiver.vhd]
# add_files [file join $root_dir rtl i2s_playback.vhd]
add_files [file join $root_dir rtl button_onepulse.vhd]
add_files [file join $root_dir constraints cons.xdc]
add_files [file join $root_dir rtl audio_stream_consumer.vhd]
add_files [file join $root_dir rtl i2s_audio_sink.vhd]


set_property top i2s_audio_sinkaudio [current_fileset]

source [file join $script_dir create_clk_wiz.tcl]

update_compile_order -fileset sources_1