catch {terminate_runs synth_1 impl_1}
catch {close_project}
catch {close_design -delete}

set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize [file join $script_dir ..]]
set proj_name  "i2s_sine"
set proj_dir   [file join $script_dir vivado_project]

create_project $proj_name $proj_dir -part xc7z007sclg400-1 -force

# Quellen hinzufügen, die vom Block Design als Module Reference gebraucht werden
add_files [file join $root_dir rtl i2s_transceiver.vhd]
add_files [file join $root_dir rtl audio_stream_consumer.vhd]
add_files [file join $root_dir rtl i2s_audio_sink.vhd]

# Optional / Altbestand
# add_files [file join $root_dir rtl i2s_playback.vhd]
# add_files [file join $root_dir rtl button_onepulse.vhd]

# Constraints
add_files [file join $root_dir constraints cons.xdc]

# Clock Wizard erzeugen
source [file join $script_dir create_clk_wiz.tcl]

update_compile_order -fileset sources_1

# Block Design erzeugen
source [file join $script_dir create_bd.tcl]

# Output Products des Block Designs erzeugen
generate_target all [get_files [file join $proj_dir $proj_name.srcs sources_1 bd audio_dma_bd audio_dma_bd.bd]]

# HDL-Wrapper erzeugen und als Top verwenden
make_wrapper -files [get_files [file join $proj_dir $proj_name.srcs sources_1 bd audio_dma_bd audio_dma_bd.bd]] -top

add_files -norecurse [file join $proj_dir $proj_name.gen sources_1 bd audio_dma_bd hdl audio_dma_bd_wrapper.v]

set_property top audio_dma_bd_wrapper [current_fileset]

update_compile_order -fileset sources_1