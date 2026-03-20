#!/usr/bin/env python3
"""
Plot cluster LB strong scaling results (multiple particle counts).

Usage:
    python3 plot_lb_cluster_scaling.py results/benchmark_lb_strong_scaling_cluster_20260320_092412
"""

import sys
import os
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.cm as cm
import numpy as np

if len(sys.argv) < 2:
    print("Usage: plot_lb_cluster_scaling.py <results_dir>")
    sys.exit(1)

results_dir = sys.argv[1]
csv_path = os.path.join(results_dir, "results.csv")
df = pd.read_csv(csv_path)
df = df.sort_values(["Particles", "Ranks"])

particle_counts = sorted(df["Particles"].unique())
colors = cm.tab10(np.linspace(0, 0.6, len(particle_counts)))
labels = {p: f"{p//1000}k" if p < 1_000_000 else f"{p//1_000_000}M" for p in particle_counts}

fig, axes = plt.subplots(2, 2, figsize=(13, 9))
fig.suptitle("IndependentParticlesTest — MPI Strong Scaling (Daint, CPU/OpenMP)",
             fontsize=13, fontweight="bold")

# -- 1. Total runtime ----------------------------------------------------------
ax = axes[0, 0]
for p, color in zip(particle_counts, colors):
    sub = df[df["Particles"] == p]
    ax.plot(sub["Ranks"], sub["Total_s"], "o-", color=color, linewidth=2,
            markersize=7, label=labels[p])
ax.set_xlabel("MPI Ranks")
ax.set_ylabel("Wall time (s)")
ax.set_title("Total Runtime")
ax.set_xscale("log", base=2)
ranks_all = sorted(df["Ranks"].unique())
ax.set_xticks(ranks_all); ax.set_xticklabels(ranks_all)
ax.legend(title="Particles", fontsize=9)
ax.grid(True, alpha=0.3)

# -- 2. Speedup ----------------------------------------------------------------
ax = axes[0, 1]
for p, color in zip(particle_counts, colors):
    sub = df[df["Particles"] == p]
    ax.plot(sub["Ranks"], sub["Speedup"], "o-", color=color, linewidth=2,
            markersize=7, label=labels[p])
min_ranks = df["Ranks"].min()
max_ranks = df["Ranks"].max()
ideal_x = [min_ranks, max_ranks]
ideal_y = [1, max_ranks / min_ranks]
ax.plot(ideal_x, ideal_y, "--", color="gray", linewidth=1.5, label="Ideal")
ax.set_xlabel("MPI Ranks")
ax.set_ylabel("Speedup")
ax.set_title("Speedup vs Ideal")
ax.set_xscale("log", base=2)
ax.set_xticks(ranks_all); ax.set_xticklabels(ranks_all)
ax.legend(title="Particles", fontsize=9)
ax.grid(True, alpha=0.3)

# -- 3. Parallel efficiency ----------------------------------------------------
ax = axes[1, 0]
for p, color in zip(particle_counts, colors):
    sub = df[df["Particles"] == p]
    ax.plot(sub["Ranks"], sub["Efficiency_pct"], "o-", color=color, linewidth=2,
            markersize=7, label=labels[p])
ax.axhline(100, color="gray", linestyle="--", linewidth=1.5)
ax.set_xlabel("MPI Ranks")
ax.set_ylabel("Parallel Efficiency (%)")
ax.set_title("Parallel Efficiency")
ax.set_xscale("log", base=2)
ax.set_xticks(ranks_all); ax.set_xticklabels(ranks_all)
ax.set_ylim(0, 110)
ax.legend(title="Particles", fontsize=9)
ax.grid(True, alpha=0.3)

# -- 4. Per-stage breakdown for largest particle count -------------------------
ax = axes[1, 1]
p_max = max(particle_counts)
sub = df[df["Particles"] == p_max].sort_values("Ranks")
stage_cols   = ["Stage1_s", "Stage2_s", "Stage3_s"]
stage_labels = ["Stage 1: Simulation", "Stage 2: Birth/Death", "Stage 3: Load Balance"]
stage_colors = ["steelblue", "darkorange", "green"]
x = range(len(sub))
bottoms = [0.0] * len(sub)
for col, slabel, scolor in zip(stage_cols, stage_labels, stage_colors):
    vals = pd.to_numeric(sub[col], errors="coerce").fillna(0).tolist()
    ax.bar(x, vals, bottom=bottoms, label=slabel, color=scolor, alpha=0.8)
    bottoms = [b + v for b, v in zip(bottoms, vals)]
ax.set_xticks(list(x)); ax.set_xticklabels(sub["Ranks"].tolist())
ax.set_xlabel("MPI Ranks")
ax.set_ylabel("Wall avg time (s)")
ax.set_title(f"Per-Stage Breakdown ({labels[p_max]} particles)")
ax.legend(fontsize=9)
ax.grid(True, alpha=0.3, axis="y")

plt.tight_layout()
out_png = os.path.join(results_dir, "strong_scaling_cluster.png")
plt.savefig(out_png, dpi=150, bbox_inches="tight")
print(f"Saved: {out_png}")
if os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"):
    plt.show()
