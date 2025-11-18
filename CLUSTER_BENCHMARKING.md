# Cluster Benchmarking Guide

Guide for running IPPL benchmarks on Alps/Piz Daint cluster.

## Prerequisites

1. **Built IPPL on the cluster** with both branches:
   - Task-parallel branch in `build-cuda/`
   - Master branch in `build-cuda-master/`

2. **Correct CMake configuration** (without the `**` formatting):
   ```bash
   cmake .. -DCMAKE_BUILD_TYPE=Release \
            -DKokkos_ARCH_HOPPER90=ON \
            -DCMAKE_CXX_STANDARD=20 \
            -DIPPL_ENABLE_FFT=ON \
            -DIPPL_ENABLE_TESTS=ON \
            -DIPPL_ENABLE_UNIT_TESTS=ON \
            -DIPPL_ENABLE_SOLVERS=ON \
            -DIPPL_ENABLE_ALPINE=ON \
            -DIPPL_PLATFORMS=CUDA \
            -DHeffte_VERSION=git.v2.4.1 \
            -DCMAKE_CUDA_ARCHITECTURES=90
   ```

3. **Build the target**:
   ```bash
   make IndependentParticlesTest -j
   ```

## Workflow

### Step 1: Generate Job Scripts

Run the benchmark generator script:

```bash
./benchmark_cuda_comparison_cluster.sh
```

This will:
- Create a timestamped results directory
- Generate individual SLURM job scripts for each particle count (2^20 to 2^30)
- Create both task-parallel and master branch jobs
- Generate a `submit_all.sh` convenience script

**Configuration options** (via environment variables):

```bash
# Override SLURM account
export SLURM_ACCOUNT=your_account_name

# Override IPPL directories
export IPPL_DIR=/path/to/ippl
export TASK_PARALLEL_BUILD_DIR=/path/to/build-cuda
export MASTER_BUILD_DIR=/path/to/build-cuda-master

# Then run
./benchmark_cuda_comparison_cluster.sh
```

### Step 2: Submit Jobs

Navigate to the results directory:

```bash
cd results/benchmark_cuda_comparison_cluster_YYYYMMDD_HHMMSS/
```

**Option A: Submit all jobs at once**
```bash
./submit_all.sh
```

**Option B: Submit individual jobs**
```bash
sbatch job_taskparallel_2p20.sh
sbatch job_master_2p20.sh
# ... etc
```

**Option C: Submit in batches**
```bash
# Submit smaller particle counts first
for job in job_*_2p2[0-4].sh; do sbatch $job; done

# Wait and submit larger ones later
for job in job_*_2p2[5-9].sh; do sbatch $job; done
for job in job_*_2p30.sh; do sbatch $job; done
```

### Step 3: Monitor Jobs

Check job status:
```bash
squeue -u $USER
```

Check specific job output:
```bash
tail -f taskparallel_2p20.out
```

Check for errors:
```bash
cat taskparallel_2p20.err
```

### Step 4: Process Results

After jobs complete, process the results:

```bash
cd /path/to/ippl-benchmarks
./process_cluster_results.sh results/benchmark_cuda_comparison_cluster_YYYYMMDD_HHMMSS/
```

This will:
- Parse all output files
- Extract timing information
- Calculate speedups and throughput
- Generate `results.csv` and `summary.txt`

### Step 5: Visualize Results

Plot the results:

```bash
./plot_cuda_comparison.py results/benchmark_cuda_comparison_cluster_YYYYMMDD_HHMMSS/
```

Or download results to your local machine for plotting:

```bash
# On your local machine
scp -r daint:/path/to/ippl-benchmarks/results/benchmark_cuda_comparison_cluster_YYYYMMDD_HHMMSS/ .
./plot_cuda_comparison.py benchmark_cuda_comparison_cluster_YYYYMMDD_HHMMSS/
```

## Test Parameters

- **Grid size**: 128×128×128 (fixed)
- **Timesteps**: 1024 (2^10)
- **Particle counts**: 2^20, 2^21, 2^22, 2^23, 2^24, 2^25, 2^26, 2^27, 2^28, 2^29, 2^30
  - That's 1,048,576 to 1,073,741,824 particles
- **Solver**: FFT
- **Load balance frequency**: 10

## SLURM Configuration

Default settings (can be adjusted in the script):
- **Account**: `csstaff` (override with `SLURM_ACCOUNT` env var)
- **Time limit**: 1 hour per job
- **Nodes**: 1
- **GPUs**: 1 GH200 GPU
- **CPUs per task**: 72
- **Exclusive node**: Yes

## Troubleshooting

### Jobs fail immediately

Check the `.err` files:
```bash
cat results/*/taskparallel_2p20.err
```

Common issues:
- Executable not found: Check build directories
- Out of memory: Reduce particle count or increase nodes
- CUDA errors: Check GPU availability

### Missing results

Some jobs may fail for large particle counts. Check:
```bash
ls results/benchmark_cuda_comparison_cluster_*/taskparallel_*.txt
ls results/benchmark_cuda_comparison_cluster_*/master_*.txt
```

Resubmit failed jobs:
```bash
sbatch results/benchmark_cuda_comparison_cluster_YYYYMMDD_HHMMSS/job_taskparallel_2p30.sh
```

### Time limit exceeded

For large particle counts, you may need to increase the time limit. Edit the script and change:
```bash
TIME_LIMIT="02:00:00"  # 2 hours
```

Or for specific jobs, edit the generated job script before submitting:
```bash
vim results/benchmark_cuda_comparison_cluster_*/job_taskparallel_2p30.sh
# Change #SBATCH --time=XX:XX:XX
sbatch results/benchmark_cuda_comparison_cluster_*/job_taskparallel_2p30.sh
```

## File Structure

After running benchmarks:

```
results/benchmark_cuda_comparison_cluster_YYYYMMDD_HHMMSS/
├── submit_all.sh                      # Convenience script to submit all jobs
├── job_taskparallel_2p20.sh          # Individual SLURM job scripts
├── job_master_2p20.sh
├── ... (more job scripts)
├── taskparallel_2p20.txt             # Benchmark output
├── taskparallel_2p20.out             # SLURM stdout
├── taskparallel_2p20.err             # SLURM stderr
├── taskparallel_2p20_timing.dat      # Detailed timing data
├── master_2p20.txt
├── master_2p20.out
├── master_2p20.err
├── master_2p20_timing.dat
├── ... (more outputs)
├── results.csv                        # Processed results CSV
└── summary.txt                        # Human-readable summary
```

## Tips

1. **Start small**: Test with smaller particle counts first (2^20-2^23) to verify everything works
2. **Monitor resources**: Use `squeue` and check `.out` files for memory usage
3. **Batch submission**: Submit jobs in groups to avoid overwhelming the scheduler
4. **Save configurations**: Keep note of successful configurations for future runs
5. **Compare carefully**: Ensure both branches are built with identical CMake options

## Example Complete Workflow

```bash
# 1. Generate job scripts
cd /path/to/ippl-benchmarks
./benchmark_cuda_comparison_cluster.sh

# Output shows: Results directory: results/benchmark_cuda_comparison_cluster_20251118_143022

# 2. Submit test jobs (small particle counts)
cd results/benchmark_cuda_comparison_cluster_20251118_143022
sbatch job_taskparallel_2p20.sh
sbatch job_master_2p20.sh

# 3. Monitor
squeue -u $USER
# Wait for completion...

# 4. If test successful, submit all remaining jobs
./submit_all.sh

# 5. Monitor all jobs
watch -n 30 'squeue -u $USER'

# 6. After completion, process results
cd ../..
./process_cluster_results.sh results/benchmark_cuda_comparison_cluster_20251118_143022/

# 7. View results
cat results/benchmark_cuda_comparison_cluster_20251118_143022/summary.txt

# 8. Plot (on cluster or local machine)
./plot_cuda_comparison.py results/benchmark_cuda_comparison_cluster_20251118_143022/
```
