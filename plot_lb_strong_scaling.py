#!/usr/bin/env python3
"""
Plot MPI strong scaling results for IndependentParticlesTest (tree-based load balancing).

Usage:
    # Automatically picks the most recent benchmark_lb_strong_scaling_* directory:
    python3 plot_lb_strong_scaling.py

    # Or point to a specific results directory:
    python3 plot_lb_strong_scaling.py results/benchmark_lb_strong_scaling_20260311_124907
"""

import sys
import os
import matplotlib.pyplot as plt
import pandas as pd

# ── Locate results directory ──────────────────────────────────────────────────
script_dir = os.path.dirname(os.path.abspath(__file__))
results_base = os.path.join(script_dir, "results")

if len(sys.argv) > 1:
    results_dir = sys.argv[1]
else:
    candidates = sorted(
        d for d in os.listdir(results_base)
        if d.startswith("benchmark_lb_strong_scaling_")
    )
    if not candidates:
        print("No benchmark_lb_strong_scaling_* directories found in results/")
        sys.exit(1)
    results_dir = os.path.join(results_base, candidates[-1])

csv_file = os.path.join(results_dir, "results.csv")
print(f"Reading results from: {csv_file}")

df = pd.read_csv(csv_file)
df = df.sort_values("Ranks")

# Read parameters from summary for the title
summary_file = os.path.join(results_dir, "summary.txt")
particles, timesteps, lbfreq = "?", "?", "?"
if os.path.exists(summary_file):
    with open(summary_file) as f:
        for line in f:
            if "Particles:" in line:
                particles = line.split(":")[-1].strip()
            elif "Timesteps:" in line:
                timesteps = line.split(":")[-1].strip()
            elif "LB freq:" in line:
                lbfreq = line.split(":")[-1].strip()

title = (
    f"IndependentParticlesTest — MPI Strong Scaling\n"
    f"{particles} particles, {timesteps} timesteps, LB freq={lbfreq}, OMP_NUM_THREADS=1"
)

# ── Ideal speedup reference line ──────────────────────────────────────────────
ranks = df["Ranks"]
ideal = ranks / ranks.iloc[0]

# ── Figure: 4 subplots ────────────────────────────────────────────────────────
fig, axes = plt.subplots(2, 2, figsize=(13, 9))
fig.suptitle(title, fontsize=13, fontweight="bold")

# -- 1. Total runtime vs ranks -------------------------------------------------
ax = axes[0, 0]
ax.plot(ranks, df["Total_s"], "o-", linewidth=2, markersize=8, label="Total elapsed")
ax.set_xlabel("MPI Ranks")
ax.set_ylabel("Wall time (s)")
ax.set_title("Total Runtime vs MPI Ranks")
ax.set_xscale("log", base=2)
ax.set_xticks(ranks)
ax.set_xticklabels(ranks)
ax.grid(True, alpha=0.3)
ax.legend()

# -- 2. Speedup vs ideal -------------------------------------------------------
ax = axes[0, 1]
ax.plot(ranks, df["Speedup"], "o-", color="steelblue", linewidth=2, markersize=8, label="Measured")
ax.plot(ranks, ideal, "--", color="gray", linewidth=1.5, label="Ideal")
ax.set_xlabel("MPI Ranks")
ax.set_ylabel("Speedup")
ax.set_title("Speedup vs Ideal")
ax.set_xscale("log", base=2)
ax.set_xticks(ranks)
ax.set_xticklabels(ranks)
ax.grid(True, alpha=0.3)
ax.legend()

# -- 3. Parallel efficiency ----------------------------------------------------
ax = axes[1, 0]
ax.plot(ranks, df["Efficiency_pct"], "o-", color="green", linewidth=2, markersize=8)
ax.axhline(y=100, color="gray", linestyle="--", linewidth=1.5, label="Perfect efficiency")
ax.set_xlabel("MPI Ranks")
ax.set_ylabel("Parallel Efficiency (%)")
ax.set_title("Parallel Efficiency")
ax.set_xscale("log", base=2)
ax.set_xticks(ranks)
ax.set_xticklabels(ranks)
ax.set_ylim(0, 110)
ax.grid(True, alpha=0.3)
ax.legend()

# -- 4. Per-stage breakdown (stacked bar) --------------------------------------
ax = axes[1, 1]

stage_cols = ["Stage1_s", "Stage2_s", "Stage3_s"]
stage_labels = ["Stage 1: Simulation", "Stage 2: Birth/Death", "Stage 3: Load Balance"]
colors = ["steelblue", "darkorange", "green"]

# Drop rows where any stage is missing / non-numeric
stage_df = df[["Ranks"] + stage_cols].copy()
for col in stage_cols:
    stage_df[col] = pd.to_numeric(stage_df[col], errors="coerce")
stage_df = stage_df.dropna()

if not stage_df.empty:
    x = range(len(stage_df))
    bottoms = [0.0] * len(stage_df)
    for col, label, color in zip(stage_cols, stage_labels, colors):
        vals = stage_df[col].tolist()
        ax.bar(x, vals, bottom=bottoms, label=label, color=color, alpha=0.8)
        bottoms = [b + v for b, v in zip(bottoms, vals)]
    ax.set_xticks(list(x))
    ax.set_xticklabels(stage_df["Ranks"].tolist())
else:
    ax.text(0.5, 0.5, "No per-stage data", ha="center", va="center", transform=ax.transAxes)

ax.set_xlabel("MPI Ranks")
ax.set_ylabel("Wall avg time (s)")
ax.set_title("Per-Stage Time Breakdown")
ax.legend(fontsize=9)
ax.grid(True, alpha=0.3, axis="y")

# ── Save ──────────────────────────────────────────────────────────────────────
plt.tight_layout()
out_png = os.path.join(results_dir, "strong_scaling.png")
plt.savefig(out_png, dpi=150, bbox_inches="tight")
print(f"Saved: {out_png}")
if os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"):
    plt.show()
