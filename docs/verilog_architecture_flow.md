# Verilog RTL Architecture & Module-to-Module Dataflow Specification

**Project:** Hardware-Accelerated AES-128 Cryptographic SoC for Edge Silicon  
**Problem Statement:** PS 16 (Wildcard Hardware Innovation)  
**Team:** QuadraX (Akif Mohamed J, Pavissh, Selvi Stella, Sowbarnikha)  

---

## 1. System Module Hierarchy & Structural Decomposition

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                   fpga_top_basys3.v                                    │
│  (100MHz->50MHz Clock Divider | Button Synchronizers | Physical Demo Sequencer)        │
└───────────────────────────────────────────┬────────────────────────────────────────────┘
                                            │
                                            ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                     aes_soc_top.v                                      │
│  (Top-Level Cryptographic SoC Wrapper | Interconnect Buses | Status LED Multiplexing)  │
├───────────────────────────────────────────┬────────────────────────────────────────────┤
│                                           │                                            │
│   ┌───────────────────────────────────┐   │   ┌────────────────────────────────────┐   │
│   │         axi4_lite_slave.v         │   │   │     aes_core_bidirectional.v       │   │
│   │  - 32-bit AMBA AXI4-Lite Slave    │   │   │  - 10-Round Iterative State FSM    │   │
│   │  - Non-blocking Handshaking       │◀──┼──▶│  - Real-Time Parity Monitor        │   │
│   │  - Memory-Mapped Regs (0x00-0x34) │   │   │  - 1-Cycle Fault Abort Controller  │   │
│   └───────────────────────────────────┘   │   └─────────────────┬──────────────────┘   │
│                                           │                     │                      │
└───────────────────────────────────────────┴─────────────────────┼──────────────────────┘
                                                                  │
              ┌───────────────────────────┬───────────────────────┴──────────────────────┐
              │                           │                                              │
              ▼                           ▼                                              ▼
┌───────────────────────────┐┌───────────────────────────┐┌────────────────────────────────┐
│    key_expand_shared.v    ││    sub_bytes_shared.v     ││      shift_rows_shared.v       │
│ - On-The-Fly Round Keys   ││ - 16 Parallel Instances   ││ - 128-bit Forward/Inverse      │
│ - Forward / Reverse Index ││   of aes_sbox_shared.v    ││   Permutation Multiplexers     │
│ - 1-Cycle Key Zeroization │└─────────────┬─────────────┘└────────────────────────────────┘
└───────────────────────────┘              │
                                           ▼
                             ┌───────────────────────────┐┌────────────────────────────────┐
                             │     aes_sbox_shared.v     ││      mix_columns_shared.v      │
                             │ - Forward/Inv Affine Maps ││ - 4 Parallel Column Units      │
                             │ - Reuses gf_inv_shared.v  ││ - Galois Mult Sharing (2,3,9) │
                             └─────────────┬─────────────┘└────────────────┬───────────────┘
                                           │                               │
                                           ▼                               ▼
                             ┌───────────────────────────┐┌────────────────────────────────┐
                             │      gf_inv_shared.v      ││   mix_single_column_shared.v   │
                             │ - Shared Multiplicative   ││ - Galois xtime Multiplication  │
                             │   Inverter in GF(2^8)     ││   Sharing (x*2, x*4, x*8)      │
                             └───────────────────────────┘└────────────────────────────────┘
```

---

## 2. Module-by-Module Dataflow & Operational Walkthrough

Here is the exact step-by-step path data follows from the host processor bus down to the lowest Galois Field arithmetic primitives:

---

### Phase 1: Bus Ingestion & Register Staging (`axi4_lite_slave.v`)
1. **Input Bus:** The host processor (or on-chip CPU) performs standard 32-bit AXI4-Lite write transactions:
   - Writes the 128-bit Master Key into `KEY0`–`KEY3` (Offsets `0x08`, `0x0C`, `0x10`, `0x14`).
   - Writes the 128-bit Input Data into `DIN0`–`DIN3` (Offsets `0x18`, `0x1C`, `0x20`, `0x24`).
   - Writes the Control Register `CTRL` (Offset `0x00`) with:
     - Bit `[0]`: `start_pulse = 1` (Auto-clearing trigger pulse).
     - Bit `[1]`: `mode_enc_dec` (`0` = Encryption, `1` = Decryption).
2. **Channel Handshaking:** `axi4_lite_slave` asserts `s_axi_awready` and `s_axi_wready`. Upon latching, it generates `s_axi_bvalid` with response code `2'b00` (`OKAY`).

---

### Phase 2: Core Datapath Initialization & Round 0 (`aes_core_bidirectional.v`)
1. **State Latching:** When `start_pulse` arrives in the `S_IDLE` state:
   - `busy` asserts High (`1`).
   - `round_num` is initialized to `4'd1`.
2. **Initial AddRoundKey (Round 0):**
   - **For Encryption (`mode_enc_dec = 0`):**  
     $$\mathbf{State}_0 = \mathbf{DIN} \oplus \mathbf{K}_0 \quad (\text{where } \mathbf{K}_0 = \text{Master Key})$$
   - **For Decryption (`mode_enc_dec = 1`):**  
     $$\mathbf{State}_0 = \mathbf{DIN} \oplus \mathbf{K}_{10} \quad (\text{where } \mathbf{K}_{10} = \text{Final Expanded Round Key})$$

---

### Phase 3: Iterative Round Execution (Rounds 1 to 9)

On every rising clock edge, the 128-bit state matrix flows through four pipelined transformation modules:

#### Step 3A: Unified SubBytes / InvSubBytes (`sub_bytes_shared.v`)
* Contains **16 parallel instances** of `aes_sbox_shared.v` processing all 16 state bytes concurrently.
* **Encryption Path (`enc_dec = 0`):**
  $$\text{Input Byte } x \longrightarrow \text{Shared } GF(2^8) \text{ Inversion } (x^{-1}) \longrightarrow \text{Forward Affine Transform} \longrightarrow S(x)$$
* **Decryption Path (`enc_dec = 1`):**
  $$\text{Input Byte } y \longrightarrow \text{Inverse Affine Transform} \longrightarrow \text{Shared } GF(2^8) \text{ Inversion } (y^{-1}) \longrightarrow S^{-1}(y)$$
* **Hardware Area Impact:** **100% of the core multiplicative inversion logic is shared**, eliminating duplicate reverse lookup tables.

#### Step 3B: Shared ShiftRows / InvShiftRows (`shift_rows_shared.v`)
* Pure combinational multiplexer network reordering the 16 state bytes:
  - **Forward ShiftRows:** Row 0 shifts 0, Row 1 shifts left 1, Row 2 shifts left 2, Row 3 shifts left 3.
  - **Inverse ShiftRows:** Row 0 shifts 0, Row 1 shifts right 1, Row 2 shifts right 2, Row 3 shifts right 3.
* Consumes **zero sequential registers** (pure routing and 64 multiplexers).

#### Step 3C: Shared MixColumns / InvMixColumns (`mix_columns_shared.v`)
* Contains **4 parallel column processing units** (`mix_single_column_shared.v`).
* Uses shared Galois Field modular multiplication ($xtime$ doubling):
  - **Forward MixColumns Matrix:** Multiplies each 4-byte column by polynomials $\{02, 03, 01, 01\}$.
  - **Inverse MixColumns Matrix:** Multiplies by polynomials $\{0E, 0B, 0D, 09\}$.
* In round 10 (the final round), MixColumns is bypassed as per NIST FIPS-197.

#### Step 3D: Dynamic Round Key Generation (`key_expand_shared.v`)
* Computes round keys on-the-fly using 10 unrolled combinational step units (`key_expand_step.v`).
* **Directional Indexing:**
  - For **Encryption:** Selects forward key index: $\mathbf{K}_r$ for $r \in [1 \dots 10]$.
  - For **Decryption:** Selects reversed key index: $\mathbf{K}_{10-r}$ for $r \in [1 \dots 10]$.
* State is updated: $\mathbf{State}_{r} = \mathbf{State}_{\text{Mix/Shift}} \oplus \mathbf{K}_r$.

---

### Phase 4: Real-Time Parity Monitoring & 1-Cycle Tamper Wipeout

1. **Parity Check Network:**  
   On every clock cycle, `aes_core_bidirectional.v` computes the XOR parity of the active state vector:
   $$\text{Parity} = \bigoplus_{i=0}^{127} \mathbf{State}[i]$$
2. **Tamper Event Response:**  
   If an illegal state transition, parity corruption, or diagnostic fault glitch (`fault_inject`) is detected:
   - **Immediate Abort (1 Clock Cycle):** The state machine halts instantly and resets to `S_IDLE`. `busy` drops to `0`.
   - **Atomic Key Zeroization:** The `zeroize_all` trigger immediately forces all 11 round key registers (`rk0` to `rk10`, 1,408 bits total) and internal datapath registers to `128'h00000000000000000000000000000000`.
   - **Interrupt Assertion:** The unmaskable hardware pin **`security_irq`** asserts High (`1`), and the status register latches `0x0000000C` (`security_irq=1`, `fault_detected=1`).

---

### Phase 5: Output Readback (`axi4_lite_slave.v`)
1. In normal operation, after exactly **10 clock cycles (200 ns @ 50 MHz)**:
   - `busy` drops to `0`, and `done` pulses High (`1`).
   - The final 128-bit result is latched into output registers `DOUT0`–`DOUT3` (Offsets `0x28`, `0x2C`, `0x30`, `0x34`).
2. The host processor reads `STATUS` (`0x04`), observes `done = 1`, and retrieves the completed ciphertext or recovered plaintext via AXI read transactions.

---

## 3. Signal Interconnect Table (Pin-to-Pin Mapping)

| Source Module | Signal Name | Destination Module | Bit Width | Purpose |
|---|---|---|:---:|---|
| `axi4_lite_slave` | `start_pulse` | `aes_core_bidirectional` | 1 | Single-cycle pulse initiating computation |
| `axi4_lite_slave` | `mode_enc_dec` | `aes_core_bidirectional` | 1 | `0` = Forward Encrypt, `1` = Inverse Decrypt |
| `axi4_lite_slave` | `key_out[127:0]` | `aes_core_bidirectional` | 128 | 128-bit Master Cipher Key |
| `axi4_lite_slave` | `din_out[127:0]` | `aes_core_bidirectional` | 128 | 128-bit Plaintext / Ciphertext |
| `aes_core_bidirectional`| `data_out[127:0]`| `axi4_lite_slave` | 128 | Computed 128-bit output result |
| `aes_core_bidirectional`| `busy` / `done` | `axi4_lite_slave` | 2 | Handshake status flags to AXI `STATUS` register |
| `aes_core_bidirectional`| `security_irq` | Top Level / Pin | 1 | Unmaskable hardware tamper interrupt |
| `aes_core_bidirectional`| `zeroize_all` | `key_expand_shared` | 1 | Synchronous 1-cycle key wipeout strobe |
| `key_expand_shared` | `current_round_key`| `aes_core_bidirectional` | 128 | Dynamically selected forward/reverse round key |
| `sub_bytes_shared` | `state_out[127:0]` | `aes_core_bidirectional` | 128 | 16-byte substituted Galois Field vector |
| `shift_rows_shared`| `state_out[127:0]` | `aes_core_bidirectional` | 128 | Forward / inverse byte permutation matrix |
| `mix_columns_shared`| `state_out[127:0]` | `aes_core_bidirectional` | 128 | Forward / inverse Galois column matrix product |
