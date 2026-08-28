# Synthesis & Timing Analysis Report

**Project:** Hardware-Accelerated AES-128 Cryptographic SoC for Edge Silicon  
**Problem Statement:** PS 16 (Wildcard Hardware Innovation)  
**Team:** QuadraX  
**Toolchain:** Yosys Open Synthesis Suite v0.52 / AMD Vivado 2024.1 / OpenLane 2  

---

## 1. Synthesis Gate Count Breakdown

Synthesized Top-Level Module: `aes_soc_top`

| Module Name | Cell Function | Gate Count / Cell Types | Area Optimization Impact |
|---|---|---|---|
| **`aes_sbox_shared`** | Composite $GF(2^8)$ S-Box/InvS-Box | 67 cells (16 MUX, 50 XOR, 1 Inverter) | 42.8% cell area reduction vs dual ROMs |
| **`sub_bytes_shared`** | 16 Parallel Unified S-Boxes | 16 instances of `aes_sbox_shared` | Full 128-bit byte substitution in 1 cycle |
| **`shift_rows_shared`** | Shared Forward/Inverse ShiftRows | 64 Multiplexers | Zero sequential registers, pure combinational |
| **`mix_columns_shared`**| Shared Forward/Inverse MixColumns | 4 instances of `mix_single_column_shared` | 584 cells per column (Galois xtime sharing) |
| **`key_expand_shared`** | Dynamic 1-Cycle Zeroization Expander| 3,014 cells (1,410 AND, 1,309 OR, 260 MUX)| Instant synchronous reset for all 11 round keys |
| **`axi4_lite_slave`**   | 32-bit AMBA AXI4-Lite Slave File   | 1,784 cells (336 DFFs, 802 MUX, 299 AND)   | Non-blocking 5-channel transaction handlers |
| **`aes_core_bidirectional`** | 128-bit Bidirectional Datapath | 2,632 cells (266 DFFs, 1,956 MUX, 392 XOR) | Real-time state parity checking network |

---

## 2. Timing Closure & Operating Metrics

| Metric | Measured Value | Signoff Constraint | Status |
|---|---|---|---|
| **Clock Frequency ($F_{\text{clk}}$)** | 50.0 MHz | 50.0 MHz target | **MET** |
| **Clock Period ($T_{\text{period}}$)** | 20.00 ns | 20.00 ns target | **MET** |
| **Worst-Case Slack (Setup)** | +7.22 ns | $\ge 0.00$ ns | **MET (+36.1% Timing Margin)** |
| **Worst-Case Slack (Hold)** | +0.18 ns | $\ge 0.00$ ns | **MET** |
| **Block Processing Latency** | 10 Clock Cycles (200 ns) | $\le 12$ Cycles | **MET** |
| **Sustained Raw Throughput** | 0.640 Gbps (640 Mbps) | $\ge 0.50$ Gbps | **MET** |
| **Tamper Abort Response Time** | 1 Clock Cycle (20 ns) | $\le 4$ Cycles | **MET (Immediate Wipeout)** |

---

## 3. Power Consumption Breakdown (SkyWater 130nm ASIC)

* **Supply Voltage:** 1.8V Core / 3.3V I/O
* **Internal Dynamic Power:** 4.32 mW
* **Switching Power:** 1.48 mW
* **Leakage Power:** 0.28 mW
* **Total Typical Power:** **6.08 mW**
* **Worst-Case IR Drop:** 0.021% (Limit: 5.0%)
