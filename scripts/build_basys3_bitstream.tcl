create_project -force quadrax_basys3 ./fpga_build -part xc7a35tcpg236-1
add_files [glob src/*.v]
add_files -fileset constrs_1 constraints/basys3.xdc
set_property top fpga_top_basys3 [current_fileset]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
puts "=== BITSTREAM GENERATION COMPLETE: ./fpga_build/quadrax_basys3.runs/impl_1/fpga_top_basys3.bit ==="
