catch {terminate_runs synth_1 impl_1}
catch {close_project}
catch {close_design -delete}

set section_name "wav_playback"
set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize [file join $script_dir ../..]]
set proj_name  "wav_player"
set proj_dir   [file join $script_dir vivado_project]

create_project $proj_name $proj_dir -part xc7z007sclg400-1 -force
set_property board_part digilentinc.com:cora-z7-07s:part0:1.1 [current_project]

add_files [file join $root_dir rtl $section_name i2s_transceiver.vhd]
add_files [file join $root_dir rtl $section_name audio_stream_consumer.vhd]
add_files [file join $root_dir rtl $section_name i2s_audio_sink.vhd]
add_files [file join $root_dir constraints cons.xdc]

source [file join $script_dir create_clk_wiz.tcl]

update_compile_order -fileset sources_1

source [file join $script_dir create_bd.tcl]

generate_target all [get_files [file join $proj_dir $proj_name.srcs sources_1 bd audio_dma_bd audio_dma_bd.bd]]

make_wrapper -files [get_files [file join $proj_dir $proj_name.srcs sources_1 bd audio_dma_bd audio_dma_bd.bd]] -top

add_files -norecurse [file join $proj_dir $proj_name.gen sources_1 bd audio_dma_bd hdl audio_dma_bd_wrapper.v]

set_property top audio_dma_bd_wrapper [current_fileset]

update_compile_order -fileset sources_1