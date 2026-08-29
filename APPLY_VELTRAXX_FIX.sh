#!/usr/bin/env bash
# APPLY_VELTRAXX_FIX.sh - integrity fix for VELTRAXX26-PS16-QuadraX
# 1) removes the unexecuted ASIC-signoff layer (old project GDS/layout/numbers)
# 2) installs the fixed multi-KAT testbench + true 9/9 log
# 3) installs the honest synthesis/verification report
# 4) patches README (scope: RTL + Yosys + FPGA per PS16)
# 5) cleans stray binaries, moves helper scripts
# Run from the repo root:  bash APPLY_VELTRAXX_FIX.sh
set -euo pipefail
[ -d .git ] || { echo "run from repo root"; exit 1; }
P="$(dirname "$0")"

echo "== 1. remove unexecuted ASIC layer and scratch =="
git rm -q gds/aes_soc.gds docs/rtl_to_gdsii_signoff.md 2>/dev/null || true
git rm -q -r docs/layout_views 2>/dev/null || true
git rm -q sim_fpga_demo sim_multi_kat sim_quadraX 2>/dev/null || true
rmdir gds 2>/dev/null || true

echo "== 2. fixed testbench + true log =="
cp -v "$P/tb_aes_multi_kat.v" tb/tb_aes_multi_kat.v
cp -v "$P/sim_multi_kat.log" logs/sim_multi_kat.log

echo "== 3. honest synthesis report =="
cp -v "$P/synthesis_and_timing_report.md" docs/synthesis_and_timing_report.md

echo "== 4. move helper scripts =="
git mv generate_waveform_images.py scripts/ 2>/dev/null || true
git mv generate_decryption_waveform.py scripts/ 2>/dev/null || true

echo "== 5. README scope patch =="
python3 - <<'EOF'
s = open('README.md').read()

s = s.replace(
"**Target Hardware:** Digilent Basys3 (AMD Artix-7 `xc7a35tcpg236-1`) & SkyWater 130nm Standard-Cell ASIC (`sky130_fd_sc_hd`)",
"**Target Hardware:** Digilent Basys3 (AMD Artix-7 `xc7a35tcpg236-1`) - FPGA hardware prototype (PS 16 custom-domain scope; SkyWater 130nm ASIC flow = future work)")

s = s.replace("production-grade, silicon-hardened, and bidirectional",
              "production-grade, hardware-verified, and bidirectional")

s = s.replace("## 6. Physical Signoff & Implementation Metrics",
              "## 6. Hardware Verification & Implementation Metrics")

old62 = """### 6.2 Implementation Signoff Summary

| Metric | FPGA Target (Digilent Basys3) | ASIC Target (SkyWater 130nm) |
|---|---|---|
| **Target Technology** | AMD Xilinx Artix-7 (`xc7a35tcpg236-1`) | SkyWater 130nm High-Density (`sky130_fd_sc_hd`) |
| **Operating Frequency** | 50 MHz (20.0 ns Clock Period) | 50 MHz Target Clock ($F_{\\text{max}} \\approx 168\\text{ MHz}$) |
| **Timing Slack** | Positive Slack Verified | **+14.07 ns (TT)**, **+7.22 ns (SS Worst Corner)** |
| **Die Area / Utilization** | Fits Basys3 Artix-7 slices | **240,307 µm²** (Core Utilization: 54% - 67.6%) |
| **Design-for-Test (DFT)** | Hardware Status LEDs & Switches | **745 Scan Flops (100% sequential coverage)** |
| **Computation Latency** | 10 Clock Cycles (200 ns per 128-bit block) | 10 Clock Cycles (200 ns per 128-bit block) |
| **Hardware vs SW Speedup**| 114x – 128x vs ARM Cortex-M4 (1,136c) | 114x – 128x vs ARM Cortex-M4 (1,136c) |
| **Sustained Throughput** | 0.64 Gbps sustained raw block rate | 0.64 Gbps sustained raw block rate |
| **Physical Signoff** | Verified on Basys3 Hardware (LEDs & UART) | DRC Clean (0 errors), LVS Clean Match, 9-Corner Timing Clean |
| **Power Consumption** | USB-powered (3.3V I/O, 1.0V core) | **6.08 mW (0.122 mW/MHz)**, Worst IR drop: 0.021% |
| **Tamper Resistance** | 1-Cycle Abort + Unmaskable Security IRQ | Real-time Parity Checking + Atomic Key Zeroization |"""
new62 = """### 6.2 Implementation Results Summary (executed evidence only)

| Metric | Value | Evidence |
|---|---|---|
| Target | Digilent Basys3, Artix-7 `xc7a35tcpg236-1` @ 50 MHz | docs/fpga_demo photos |
| Synthesis | Yosys 0.9, gate-level netlist committed | logs/synth.log, outputs/aes_soc_netlist.v |
| Functional regression | 9 / 9 PASS (4x encrypt KAT, 4x decrypt KAT, fault+zeroize) | logs/sim_multi_kat.log |
| Directive verification | 3 / 3 PASS (bidirectional, tamper/zeroize, AXI4-Lite) | logs/sim.log |
| Datapath | Iterative 10-round, shared GF S-Box forward/inverse | src/, GTKWave evidence in outputs/ |
| Hardware demo | Encrypt 0x97, Decrypt 0x2A, Tamper wipeout 0x00 | docs/fpga_demo photos |

Note: a SkyWater 130nm ASIC physical flow (OpenLane/OpenROAD, DRC/LVS,
multi-corner STA) is future work for this `aes_soc_top` integration and is
not claimed here. PS 16 is a custom-domain statement; the delivered scope
is RTL + synthesis + simulation + live FPGA verification."""
assert old62 in s, "6.2 table not found"
s = s.replace(old62, new62)

s = s.replace("""### Running Static Timing Analysis (STA)
```bash
yosys -p "read_verilog outputs/aes_soc_netlist.v; hierarchy -check -top aes_soc_top; proc; ltp"
```""",
"""### Logic Depth Check (Yosys)
```bash
yosys -p "read_verilog outputs/aes_soc_netlist.v; hierarchy -check -top aes_soc_top; proc; ltp"
```""")

s = s.replace("""│   ├── rtl_to_gdsii_signoff.md   # OpenLane 2 / SkyWater 130nm ASIC signoff data
│   ├── synthesis_and_timing_report.md # Gate counts, cell area & 9-corner timing
│   ├── layout_views/             # High-resolution KLayout layout renders
│   └── fpga_demo/                # Basys3 Artix-7 physical hardware verification""",
"""│   ├── synthesis_and_timing_report.md # Gate counts (Yosys) & verification summary
│   └── fpga_demo/                # Basys3 Artix-7 physical hardware verification""")

s = s.replace("""├── gds/                    # Silicon GDSII Stream Deliverable
│   └── aes_soc.gds               # Full-chip physical layout file
""", "")

s = s.replace("""│   └── openlane_config.json      # SkyWater 130nm ASIC physical configuration""",
"""│   └── build_basys3_bitstream.tcl # Vivado batch bitstream build""")

open('README.md','w').write(s)
print("README patched")
EOF

echo "== 6. verify the regression honestly =="
iverilog -g2012 -o /tmp/quadraX_check.vvp tb/tb_aes_multi_kat.v src/*.v
timeout 120 vvp /tmp/quadraX_check.vvp | tee /tmp/quadraX_check.log | tail -4
grep -q "9 / 9 TEST CASES PASSED - ALL VECTORS VERIFIED" /tmp/quadraX_check.log \
  && echo "REGRESSION 9/9 CONFIRMED" || { echo "REGRESSION NOT CLEAN - STOP"; exit 2; }

git add -A
git status --short
git commit -m "fix(tb+docs): correct multi-KAT decrypt input typos + honest 9/9 regression; scope repo to executed evidence (RTL + Yosys 0.9 + FPGA demo per PS16); remove pre-existing GDS/layout/signoff artifacts not generated for this design"
git push origin main || { echo "push rejected - run: git pull --rebase origin main && git push origin main"; exit 3; }
echo "DONE - repository now matches executed evidence."
