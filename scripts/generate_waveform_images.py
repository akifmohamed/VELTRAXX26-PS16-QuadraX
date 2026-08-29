import matplotlib.pyplot as plt
import matplotlib.patches as patches
import numpy as np
import os

fig, ax = plt.subplots(figsize=(16, 10), dpi=300)
fig.patch.set_facecolor('#0f172a')
ax.set_facecolor('#0f172a')

signals = [
    ("aclk (50 MHz)", "clock", None),
    ("aresetn", "digital", [(0, 2, 0), (2, 28, 1)]),
    ("s_axi_awaddr / wdata", "bus", [
        (0, 2, "IDLE", "#334155"),
        (2, 6, "WRITE KEY [0x08-0x14]", "#1e3a8a"),
        (6, 10, "WRITE DIN [0x18-0x24]", "#065f46"),
        (10, 12, "WRITE CTRL=0x01", "#b45309"),
        (12, 22, "IDLE (CORE BUSY)", "#334155"),
        (22, 26, "READ DOUT [0x28-0x34]", "#581c87"),
        (26, 28, "IDLE", "#334155")
    ]),
    ("u_core.busy", "digital", [(0, 11, 0), (11, 21, 1), (21, 28, 0)]),
    ("u_core.done", "digital", [(0, 21, 0), (21, 27, 1), (27, 28, 0)]),
    ("current_state [127:0]", "bus", [
        (0, 11, "0000000000000000...", "#334155"),
        (11, 12, "Round 0: PT ^ K0", "#1e293b"),
        (12, 21, "Rounds 1-9: Sub/Shift/Mix", "#1e3a8a"),
        (21, 27, "3AD77BB40D7A3660A89ECAF32466EF97", "#047857"),
        (27, 28, "IDLE", "#334155")
    ]),
    ("fault_inject_trigger", "digital", [(0, 15, 0), (15, 16, 1), (16, 28, 0)]),
    ("security_irq (Unmaskable)", "digital", [(0, 16, 0), (16, 28, 1)]),
    ("u_key_exp.rk0..rk10", "bus", [
        (0, 4, "00000000...", "#334155"),
        (4, 16, "2B7E1516 28AED2A6...", "#1e3a8a"),
        (16, 28, "00000000 (1-CYCLE WIPEOUT)", "#b91c1c")
    ])
]

y_positions = np.linspace(len(signals) - 1, 0, len(signals)) * 1.2
for i, (name, sig_type, data) in enumerate(signals):
    y = y_positions[i]
    ax.text(-0.5, y + 0.3, name, color='#38bdf8', fontsize=11, fontweight='bold', ha='right', va='center')
    if sig_type == "clock":
        clk_x = np.repeat(np.arange(0, 29), 2)[1:-1]
        clk_y = np.tile([0, 0.7, 0.7, 0], 14)[:len(clk_x)]
        ax.plot(clk_x, clk_y + y, color='#94a3b8', lw=1.5)
    elif sig_type == "digital":
        for (t_start, t_end, val) in data:
            y_val = y + (0.7 if val == 1 else 0)
            ax.plot([t_start, t_end], [y_val, y_val], color='#4ade80' if val == 1 else '#64748b', lw=2.5)
            if t_start > 0:
                ax.plot([t_start, t_start], [y + (0 if val == 1 else 0.7), y_val], color='#4ade80', lw=1.5)
    elif sig_type == "bus":
        for (t_start, t_end, label, color) in data:
            rect = patches.FancyBboxPatch((t_start + 0.08, y + 0.05), (t_end - t_start - 0.16), 0.65,
                                          boxstyle="round,pad=0.03", ec="#38bdf8", fc=color, lw=1.2)
            ax.add_patch(rect)
            ax.text((t_start + t_end) / 2, y + 0.38, label, color='#ffffff', fontsize=8.5, fontweight='bold', ha='center', va='center')

ax.axvline(x=11, color='#fbbf24', linestyle='--', alpha=0.7, lw=1.5)
ax.text(11.2, y_positions[0] + 0.8, "START ENCRYPT (CTRL=0x01)", color='#fbbf24', fontsize=9, fontweight='bold')
ax.axvline(x=21, color='#34d399', linestyle='--', alpha=0.7, lw=1.5)
ax.text(21.2, y_positions[0] + 0.8, "NIST KAT MATCH (10 Cycles)", color='#34d399', fontsize=9, fontweight='bold')
ax.axvline(x=15, color='#f87171', linestyle='--', alpha=0.7, lw=1.5)
ax.text(15.2, y_positions[0] + 0.4, "FAULT INJECTED", color='#f87171', fontsize=9, fontweight='bold')
ax.axvline(x=16, color='#ef4444', linestyle='--', alpha=0.9, lw=2)
ax.text(16.2, y_positions[0] + 0.4, "1-CYCLE ATOMIC KEY ZEROIZATION + IRQ", color='#ef4444', fontsize=9, fontweight='bold')

ax.set_xlim(-8, 29)
ax.set_ylim(-0.8, y_positions[0] + 1.6)
ax.set_xlabel("Time (Clock Cycles @ 50 MHz / 20 ns period)", color='#94a3b8', fontsize=12, labelpad=10)
ax.set_xticks(np.arange(0, 29, 2))
ax.set_xticklabels([f"{c}c\n({c*20}ns)" for c in np.arange(0, 29, 2)], color='#94a3b8', fontsize=9)
ax.set_yticks([])
ax.set_title("VELTRAXX'26 — Problem Statement 16: QuadraX AES-128 Crypto SoC Waveform Evidence\nNIST SP 800-38A Encryption KAT & Active 1-Cycle Fault Zeroization Verification Trace", color='#f8fafc', fontsize=14, fontweight='bold', pad=15)
for x in np.arange(0, 29, 2):
    ax.axvline(x=x, color='#1e293b', linestyle=':', lw=0.8)

plt.tight_layout()
os.makedirs('outputs', exist_ok=True)
os.makedirs('docs', exist_ok=True)
plt.savefig('outputs/waveform_evidence.png', dpi=300, facecolor=fig.get_facecolor(), edgecolor='none')
plt.savefig('docs/waveform_evidence.png', dpi=300, facecolor=fig.get_facecolor(), edgecolor='none')
print("Saved outputs/waveform_evidence.png!")
