# AMBA AXI4-Lite Register Interface Specification

This document details the memory-mapped register space and handshaking protocol for the **QuadraX AES-128 Cryptographic Accelerator SoC** (Problem Statement 16).

---

## 1. Register Memory Map Summary

All registers are 32 bits wide and aligned on 4-byte boundaries.

| Offset | Register Name | Access | Reset Value | Description |
|:---:|:---|:---:|:---:|:---|
| **`0x00`** | `CTRL` | R/W | `0x00000000` | Core Control & Mode Configuration |
| **`0x04`** | `STATUS` | RO | `0x00000000` | Cryptographic & Security Hardware Status |
| **`0x08`** | `KEY0` | WO | `0x00000000` | 128-bit Master Cipher Key Word 0 (`[31:0]`) |
| **`0x0C`** | `KEY1` | WO | `0x00000000` | 128-bit Master Cipher Key Word 1 (`[63:32]`) |
| **`0x10`** | `KEY2` | WO | `0x00000000` | 128-bit Master Cipher Key Word 2 (`[95:64]`) |
| **`0x14`** | `KEY3` | WO | `0x00000000` | 128-bit Master Cipher Key Word 3 (`[127:96]`) |
| **`0x18`** | `DIN0` | WO | `0x00000000` | 128-bit Input Data Word 0 (`[31:0]`) |
| **`0x1C`** | `DIN1` | WO | `0x00000000` | 128-bit Input Data Word 1 (`[63:32]`) |
| **`0x20`** | `DIN2` | WO | `0x00000000` | 128-bit Input Data Word 2 (`[95:64]`) |
| **`0x24`** | `DIN3` | WO | `0x00000000` | 128-bit Input Data Word 3 (`[127:96]`) |
| **`0x28`** | `DOUT0` | RO | `0x00000000` | 128-bit Output Data Word 0 (`[31:0]`) |
| **`0x2C`** | `DOUT1` | RO | `0x00000000` | 128-bit Output Data Word 1 (`[63:32]`) |
| **`0x30`** | `DOUT2` | RO | `0x00000000` | 128-bit Output Data Word 2 (`[95:64]`) |
| **`0x34`** | `DOUT3` | RO | `0x00000000` | 128-bit Output Data Word 3 (`[127:96]`) |

---

## 2. Bitfield Definitions

### Control Register (`CTRL`, Offset: `0x00`)
- **Bit `[0]` — `start`**: Active-high pulse / strobe to initiate AES-128 cryptographic execution.
- **Bit `[1]` — `enc_dec`**:
  - `0`: Forward AES-128 Encryption (`Cipher`).
  - `1`: Inverse AES-128 Decryption (`InvCipher`).
- **Bit `[2]` — `soft_reset`**: Software-controlled core reset. Resets internal datapath registers without affecting AXI register file.
- **Bit `[3]` — `fault_inject_test`**: Dynamic diagnostic fault trigger to verify 1-cycle key wipeout and unmaskable interrupt.

### Status Register (`STATUS`, Offset: `0x04`)
- **Bit `[0]` — `busy`**: Asserted high (`1`) while the 10-round AES datapath is executing.
- **Bit `[1]` — `done`**: Asserted high (`1`) when output ciphertext or plaintext is valid in `DOUT0` - `DOUT3`.
- **Bit `[2]` — `fault_detected`**: Asserted high (`1`) upon detection of datapath parity corruption or glitch.
- **Bit `[3]` — `security_irq`**: Hardware unmaskable interrupt line driven to processor core or system management unit.

---

## 3. Bus Transaction Timing & Sequence

### Typical Encryption Sequence:
1. Master writes 128-bit key across `KEY0` (`0x08`), `KEY1` (`0x0C`), `KEY2` (`0x10`), and `KEY3` (`0x14`).
2. Master writes 128-bit plaintext across `DIN0` (`0x18`), `DIN1` (`0x1C`), `DIN2` (`0x20`), and `DIN3` (`0x24`).
3. Master writes `0x00000001` (`start=1, enc_dec=0`) to `CTRL` (`0x00`).
4. Master polls `STATUS` (`0x04`) until Bit `[1]` (`done`) is `1`.
5. Master reads 128-bit ciphertext across `DOUT0` (`0x28`), `DOUT1` (`0x2C`), `DOUT2` (`0x30`), and `DOUT3` (`0x34`).

### Active Tamper / Zeroization Sequence:
1. If fault occurs during computation, `security_irq` asserts within 1 clock cycle.
2. Status register reads `0x0000000C` (`security_irq=1, fault_detected=1, busy=0`).
3. `KEY0` - `KEY3` and all internal 11 round keys are erased to `0x00000000`.
