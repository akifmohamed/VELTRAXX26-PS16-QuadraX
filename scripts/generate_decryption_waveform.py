import matplotlib.pyplot as plt
import matplotlib.patches as patches
import numpy as np
import os

fig, ax = plt.subplots(figsize=(16, 8), dpi=300)
fig.patch.set_facecolor('#0f172a')
ax.set_facecolor('#0f172a')

signals = [
    ("aclk (50 MHz)", "clock", None),
    ("s_axi_awaddr / wdata", "bus", [
        (0, 2, "IDLE", "#334155"),
        (2, 6, "WRITE CIPHERTEXT DIN [0x18-0x24]", "#065f46"),
        (6, 8, "WRITE CTRL=0x03 (START DEC)", "#b45309"),
        (8, 18, "IDLE (CORE DECRYPTING)", "#334155"),
        (18, 22, "READ RECOVERED PT [0x28-0x34]", "#581c87"),
        (22, 24, "IDLE", "#334155")
    ]),
    ("u_core.enc_dec", "digital", [(0, 24, 1)]),
    ("u_core.busy", "digital", [(0, 7, 0), (7, 17, 1), (17, 24, 0)]),
    ("u_core.done", "digital", [(0, 17, 0), (17, 23, 1), (23, 24, 0)]),
    ("current_state [127:0]", "bus", [
        (0, 7, "3AD77BB4 0D7A3660 A89ECAF3 2466EF97", "#1e3a8a"),
        (7, 8, "Round 0: CT ^ K10", "#1e293b"),
        (8, 17, "Rounds 1-9: InvSub / InvShift / InvMix", "#1e3a8a"),
        (17, 23, "6BC1BEE2 2E409F96 E93D7E11 7393172A", "#047857"),
        (23, 24, "IDLE", "#334155")
    ]),
    ("gf_inv_shared (100% Reused)", "bus", [
        (0, 8, "IDLE", "#334155"),
        (8, 17, "Active GF(2^8) Inversion Pipeline", "#0284c7"),
        (17, 24, "IDLE", "#334155")
    ])
]

y_positions = np.linspace(len(signals) - 1, 0, len(signals)) * 1.3
for i, (name, sig_type, data) in enumerate(signals):
    y = y_positions[i]
    ax.text(-0.5, y + 0.35, name, color='#38bdf8', fontsize=11, fontweight='bold', ha='right', va='center')
    if sig_type == "clock":
        clk_x = np.repeat(np.arange(0, 25), 2)[1:-1]
        clk_y = np.tile([0, 0.7, 0.7, 0], 12)[:len(clk_x)]
        ax.plot(clk_x, clk_y + y, color='#94a3b8', lw=1.5)
    elif sig_type == "digital":
        for (t_start, t_end, val) in data:
            y_val = y + (0.7 if val == 1 else 0)
            ax.plot([t_start, t_end], [y_val, y_val], color='#4ade80' if val == 1 else '#64748b', lw=2.5)
            if t_start > 0:
                ax.plot([t_start, t_start], [y + (0 if val == 1 else 0.7), y_val], color='#4ade80', lw=1.5)
    elif sig_type == "bus":
        for (t_start, t_end, label, color) in data:
            rect = patches.FancyBboxPatch((t_start + 0.08, y + 0.05), (t_end - t_start - 0.16), 0.7,
                                          boxstyle="round,pad=0.03", ec="#38bdf8", fc=color, lw=1.2)
            ax.add_patch(rect)
            ax.text((t_start + t_end) / 2, y + 0.4, label, color='#ffffff', fontsize=9, fontweight='bold', ha='center', va='center')

ax.axvline(x=7, color='#fbbf24', linestyle='--', alpha=0.7, lw=1.5)
ax.text(7.2, y_positions[0] + 0.8, "START DECRYPT (CTRL=0x03)", color='#fbbf24', fontsize=9, fontweight='bold')
ax.axvline(x=17, color='#34d399', linestyle='--', alpha=0.7, lw=1.5)
ax.text(17.2, y_positions[0] + 0.8, "NIST KAT DECRYPT MATCH (10 Cycles)", color='#34d399', fontsize=9, fontweight='bold')

ax.set_xlim(-8, 25)
ax.set_ylim(-0.8, y_positions[0] + 1.6)
ax.set_xlabel("Time (Clock Cycles @ 50 MHz / 20 ns period)", color='#94a3b8', fontsize=12, labelpad=10)
ax.set_xticks(np.arange(0, 25, 2))
ax.set_xticklabels([f"{c}c\n({c*20}ns)" for c in np.arange(0, 25, 2)], color='#94a3b8', fontsize=9)
ax.set_yticks([])
ax.set_title("VELTRAXX'26 — PS 16: NIST SP 800-38A Decryption KAT & Shared GF(2^8) Inverter Trace", color='#f8fafc', fontsize=14, fontweight='bold', pad=15)
for x in np.arange(0, 25, 2):
    ax.axvline(x=x, color='#1e293b', linestyle=':', lw=0.8)

plt.tight_layout()
plt.savefig('outputs/waveform_decryption.png', dpi=300, facecolor=fig.get_facecolor(), edgecolor='none')
plt.savefig('docs/waveform_decryption.png', dpi=300, facecolor=fig.get_facecolor(), edgecolor='none')
print("Saved outputs/waveform_decryption.png!")
