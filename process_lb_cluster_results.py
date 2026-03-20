#!/usr/bin/env python3
"""
Parse cluster LB strong scaling results into a CSV.

Usage:
    python3 process_lb_cluster_results.py results/benchmark_lb_strong_scaling_cluster_20260320_092412
"""

import sys
import os
import re
import csv

if len(sys.argv) < 2:
    print("Usage: process_lb_cluster_results.py <results_dir>")
    sys.exit(1)

results_dir = sys.argv[1]

def extract_elapsed(text):
    """Max elapsed time across all ranks."""
    times = [float(m) for m in re.findall(r"^Elapsed time:\s+([\d.]+)", text, re.MULTILINE)]
    return max(times) if times else None

def extract_wall_avg(text, timer_name):
    """Wall avg for a named timer from the inline Timings block."""
    pattern = rf"{re.escape(timer_name)}.*?Wall avg\s*=\s*([\d.e+\-]+)"
    m = re.search(pattern, text, re.DOTALL)
    return float(m.group(1)) if m else None

rows = []
for fname in os.listdir(results_dir):
    if not fname.endswith(".txt"):
        continue
    m = re.match(r"ranks(\d+)_np(\d+)\.txt", fname)
    if not m:
        continue
    ranks, particles = int(m.group(1)), int(m.group(2))
    with open(os.path.join(results_dir, fname)) as f:
        text = f.read()
    total   = extract_elapsed(text)
    stage1  = extract_wall_avg(text, "stage1Simulation")
    stage2  = extract_wall_avg(text, "stage2BirthDeath")
    stage3  = extract_wall_avg(text, "stage3LoadBalance")
    if total is None:
        print(f"  WARNING: no elapsed time found in {fname}")
        continue
    rows.append(dict(Ranks=ranks, Particles=particles,
                     Total_s=total, Stage1_s=stage1,
                     Stage2_s=stage2, Stage3_s=stage3))

# Compute speedup and efficiency per particle count (baseline = min ranks)
rows.sort(key=lambda r: (r["Particles"], r["Ranks"]))
baselines = {}
for r in rows:
    p = r["Particles"]
    if p not in baselines:
        baselines[p] = r["Total_s"]
    base = baselines[p]
    r["Speedup"]        = round(base / r["Total_s"], 4)
    r["Efficiency_pct"] = round(100 * base / (r["Total_s"] * r["Ranks"] / min(
        rr["Ranks"] for rr in rows if rr["Particles"] == p)), 2)

csv_path = os.path.join(results_dir, "results.csv")
fields = ["Ranks", "Particles", "Total_s", "Stage1_s", "Stage2_s", "Stage3_s",
          "Speedup", "Efficiency_pct"]
with open(csv_path, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=fields)
    w.writeheader()
    w.writerows(rows)

print(f"Wrote {len(rows)} rows to {csv_path}")

# Print summary table
print(f"\n{'Particles':>12} {'Ranks':>6} {'Total(s)':>10} {'Speedup':>9} {'Efficiency':>11}")
print("-" * 54)
for r in rows:
    print(f"{r['Particles']:>12} {r['Ranks']:>6} {r['Total_s']:>10.3f} "
          f"{r['Speedup']:>9.2f}x {r['Efficiency_pct']:>10.1f}%")
