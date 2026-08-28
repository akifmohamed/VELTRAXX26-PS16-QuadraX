#!/bin/bash
set -e
mkdir -p logs outputs

echo "================================================================="
echo "  Running Yosys RTL Synthesis for VELTRAXX'26 PS16 (QuadraX)     "
echo "================================================================="

yosys -p "
read_verilog -sv src/aes_sbox_shared.v \
                 src/sub_bytes_shared.v \
                 src/shift_rows_shared.v \
                 src/mix_columns_shared.v \
                 src/key_expand_shared.v \
                 src/aes_core_bidirectional.v \
                 src/axi4_lite_slave.v \
                 src/aes_soc_top.v
hierarchy -check -top aes_soc_top
proc; opt; fsm; opt; memory; opt
techmap; opt
stat
write_verilog outputs/aes_soc_netlist.v
" | tee logs/synth.log

echo "================================================================="
echo "  Synthesis Complete! Netlist: outputs/aes_soc_netlist.v         "
echo "  Synthesis Log: logs/synth.log                                  "
echo "================================================================="
