#!/bin/bash
set -e
mkdir -p outputs logs

echo "================================================================="
echo "  Compiling & Running Icarus Verilog Simulation for QuadraX      "
echo "================================================================="

iverilog -g2012 -o sim_quadraX \
  src/aes_sbox_shared.v \
  src/sub_bytes_shared.v \
  src/shift_rows_shared.v \
  src/mix_columns_shared.v \
  src/key_expand_shared.v \
  src/aes_core_bidirectional.v \
  src/axi4_lite_slave.v \
  src/aes_soc_top.v \
  tb/tb_aes_axi_top.v

vvp sim_quadraX | tee logs/sim.log

echo "================================================================="
echo "  Simulation Complete! Log: logs/sim.log                         "
echo "  Waveform: outputs/aes_axi_fault_sim.vcd                        "
echo "================================================================="
