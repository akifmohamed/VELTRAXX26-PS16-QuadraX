# Synthesis & Verification Report

**Project:** Hardware-Accelerated AES-128 Cryptographic SoC for Edge Silicon
**Problem Statement:** PS 16 (Wildcard Hardware Innovation)
**Team:** QuadraX
**Toolchain:** Yosys 0.9 (logs/synth.log), Icarus Verilog (scripts/build_iverilog.sh), GTKWave, AMD Vivado (FPGA bitstream; see scripts/build_basys3_bitstream.tcl)

**Scope note:** PS 16 is a custom-domain problem statement. The delivered
evidence scope is: RTL design, Yosys synthesis, self-checking simulation
regression, and live FPGA hardware verification. A SkyWater 130nm ASIC
physical flow (OpenLane/OpenROAD) is identified as future work and is not
claimed in this repository.

---

## 1. Synthesis Gate Count Breakdown (Yosys 0.9, netlist: outputs/aes_soc_netlist.v)

Synthesized Top-Level Module: `aes_soc_top`

| Module Name | Cell Function | Gate Count / Cell Types | Area Optimization Impact |
|---|---|---|---|
| **`aes_sbox_shared`** | Composite GF(2^8) S-Box/InvS-Box | 67 cells (16 MUX, 50 XOR, 1 Inverter) | 42.8% cell area reduction vs dual ROMs |
| **`sub_bytes_shared`** | 16 Parallel Unified S-Boxes | 16 instances of `aes_sbox_shared` | Full 128-bit byte substitution in 1 cycle |
| **`shift_rows_shared`** | Shared Forward/Inverse ShiftRows | 64 Multiplexers | Zero sequential registers, pure combinational |
| **`mix_columns_shared`** | Shared Forward/Inverse MixColumns | 4 instances of `mix_single_column_shared` | Galois xtime sharing |
| **`key_expand_shared`** | Dynamic 1-Cycle Zeroization Expander | 3,014 cells (1,410 AND, 1,309 OR, 260 MUX) | Instant synchronous reset for all 11 round keys |
| **`axi4_lite_slave`** | 32-bit AMBA AXI4-Lite Slave File | 1,784 cells (336 DFFs, 802 MUX, 299 AND) | Non-blocking 5-channel transaction handlers |
| **`aes_core_bidirectional`** | 128-bit Bidirectional Datapath | 2,632 cells (266 DFFs, 1,956 MUX, 392 XOR) | Real-time state parity checking network |

Source of truth: `logs/synth.log` and the committed gate-level netlist.

## 2. Functional Verification Results (simulation evidence)

| Suite | Result | Log |
|---|---|---|
| Directive verification: encrypt KAT, decrypt KAT, fault/zeroization + security IRQ | 3 / 3 PASS | logs/sim.log |
| NIST SP 800-38A ECB-AES128 4-vector regression, encrypt | 4 / 4 PASS | logs/sim_multi_kat.log |
| NIST SP 800-38A 4-vector regression, decrypt | 4 / 4 PASS | logs/sim_multi_kat.log |
| Active fault injection, 1-cycle abort, IRQ assert | PASS | logs/sim_multi_kat.log |
| **Total regression** | **9 / 9 PASS** | logs/sim_multi_kat.log |

Note (documented for transparency): the initial commit of
`tb/tb_aes_multi_kat.v` contained two testbench typos in the decrypt input
load (two words sourced from `test_pt` instead of `test_ct`) and a
hard-coded summary line, which produced a false "100%" claim on a 4/9 run.
The RTL was correct throughout (hardware decrypt returned the expected
byte). The testbench was fixed, and the current committed log shows the
true 9 / 9 result.

## 3. FPGA Hardware Verification (Digilent Basys3, Artix-7 xc7a35tcpg236-1)

| Demonstration Mode | Button | LED Evidence | Result |
|---|---|---|---|
| NIST SP 800-38A Encryption | btnU | 0x97 | PASS |
| NIST SP 800-38A Decryption | btnD | 0x2A | PASS |
| Active Tamper / Zeroization | btnR/btnC | 0x00 | PASS |

Photos: docs/fpga_demo/. Waveform evidence: outputs/ (GTKWave captures of
encrypt KAT, decrypt KAT, and 1-cycle key zeroization).

## 4. Future Work

- Full SkyWater 130nm physical implementation (OpenLane 2 / OpenRoad:
  floorplan, CTS, routing, DRC/LVS, multi-corner STA) for the `aes_soc_top`
  integration including the AXI4-Lite subsystem.
- Formal AXI4-Lite protocol compliance check (e.g., reuse of ARM AXI
  verification IP or Sachem/SV-A assertions).
