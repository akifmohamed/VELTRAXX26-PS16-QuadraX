# Architecture & Mathematical Formulation

## 1. Unified Galois Field $GF(((2^2)^2)^2)$ S-Box / InvS-Box Architecture

In standard AES-128 (NIST FIPS PUB 197), the forward SubBytes step applies a non-linear substitution byte-by-byte:
$$S(x) = M \cdot x^{-1} \oplus c$$
where $M$ is the forward affine transformation matrix, $x^{-1}$ is the multiplicative inverse in Galois Field $GF(2^8)$ modulo irreducible polynomial $P(x) = x^8 + x^4 + x^3 + x + 1$, and $c = 0\text{x}63$.

The inverse SubBytes step applies:
$$S^{-1}(y) = \left(M^{-1} \cdot (y \oplus c)\right)^{-1}$$
where $M^{-1}$ is the inverse affine matrix.

### Unified Resource Sharing:
Rather than implementing two distinct ROMs (256 bytes for forward S-Box and 256 bytes for inverse S-Box):
1. For **Forward Encryption (`enc_dec = 0`)**:
   - Step 1: Pass input byte $x$ directly to shared $GF(2^8)$ inverter $\rightarrow x^{-1}$.
   - Step 2: Apply Forward Affine Transform $M \cdot x^{-1} \oplus c \rightarrow S(x)$.
2. For **Inverse Decryption (`enc_dec = 1`)**:
   - Step 1: Pre-apply Inverse Affine Transform $M^{-1} \cdot (x \oplus c) \rightarrow \hat{x}$.
   - Step 2: Pass $\hat{x}$ into the **exact same shared $GF(2^8)$ inverter** $\rightarrow (\hat{x})^{-1} = S^{-1}(x)$.

**Result:** 100% of the core multiplicative inversion logic is shared across forward encryption and decryption, eliminating redundant cell area.

---

## 2. Dynamic Bidirectional Datapath Scheduling

The AES core operates on a 128-bit state matrix $\mathbf{S} \in GF(2^8)^{4 \times 4}$.

### Round Sequences:
- **Forward Encryption (10 Rounds):**
  - Initial Round (Round 0): $\mathbf{S}_0 = \mathbf{PT} \oplus \mathbf{K}_0$
  - Standard Rounds (Rounds 1–9): $\mathbf{S}_r = \text{MixColumns}(\text{ShiftRows}(\text{SubBytes}(\mathbf{S}_{r-1}))) \oplus \mathbf{K}_r$
  - Final Round (Round 10): $\mathbf{S}_{10} = \text{ShiftRows}(\text{SubBytes}(\mathbf{S}_9)) \oplus \mathbf{K}_{10}$

- **Inverse Decryption (10 Rounds):**
  - Initial Round (Round 0): $\mathbf{S}_0 = \mathbf{CT} \oplus \mathbf{K}_{10}$
  - Standard Rounds (Rounds 1–9): $\mathbf{S}_r = \text{InvSubBytes}(\text{InvShiftRows}(\text{InvMixColumns}(\mathbf{S}_{r-1} \oplus \mathbf{K}_{10-r})))$
  - Final Round (Round 10): $\mathbf{S}_{10} = \text{InvSubBytes}(\text{InvShiftRows}(\mathbf{S}_9 \oplus \mathbf{K}_0))$

Both paths complete in **10 clock cycles** (200 ns @ 50 MHz clock).

---

## 3. Active Fault-Tamper Zeroization Engine

To mitigate Differential Fault Analysis (DFA) attacks:
1. Every round state $\mathbf{S}_r$ is monitored by an XOR parity calculation network.
2. If an internal fault or glitch is detected:
   - Synchronous clear pulses immediately wipe $\mathbf{K}_0 \dots \mathbf{K}_{10}$ to all zeros (`128'h0`).
   - The state machine immediately halts execution and returns to `S_IDLE`.
   - The unmaskable hardware interrupt `security_irq` is asserted high.
   - Status bit `fault_detected` (bit 2) is latched until software clears the condition.
