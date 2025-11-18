# IPPL Benchmarks

Performance benchmarking suite for the Independent Parallel Particle Layer (IPPL) library.

## Overview

This repository contains benchmark scripts and plotting tools to measure and analyze the performance of IPPL across different configurations, including:

- Task-parallel vs master branch comparisons
- CPU (OpenMP) vs GPU (CUDA) performance
- Scaling studies (strong scaling with different thread counts)
- Problem size scaling (varying particle counts and grid sizes)

## Repository Structure

```
ippl-benchmarks/
├── benchmark_task_parallel.sh       # Task-parallel vs master comparison (OpenMP)
├── benchmark_scaling.sh             # Thread scaling benchmark (OpenMP)
├── benchmark_gpu_scaling.sh         # GPU particle count scaling
├── benchmark_gpu_vs_cpu.sh          # GPU vs CPU comparison
├── benchmark_cuda_comparison.sh     # Task-parallel vs master on CUDA
├── plot_scaling.py                  # Plot scaling benchmark results
├── plot_gpu_scaling.py              # Plot GPU scaling results
├── plot_cuda_comparison.py          # Plot CUDA comparison results
└── results/                         # Benchmark results (timestamped subdirectories)
```

## Prerequisites

- IPPL repository located at `../ippl` (relative to this directory)
- Built IPPL with appropriate backends:
  - For OpenMP benchmarks: `../ippl/build-openmp` and `../ippl/build-openmp-master`
  - For CUDA benchmarks: `../ippl/build-cuda` and `../ippl/build-cuda-master`
- Python 3 with matplotlib and pandas for plotting scripts
- `bc` command-line calculator for bash scripts

## Usage

### Running Benchmarks

Each benchmark script is self-contained and creates a timestamped results directory under `results/`:

```bash
# Task-parallel vs master comparison (OpenMP)
./benchmark_task_parallel.sh

# Thread scaling study
./benchmark_scaling.sh

# GPU particle count scaling
./benchmark_gpu_scaling.sh

# GPU vs CPU comparison
./benchmark_gpu_vs_cpu.sh

# CUDA branch comparison
./benchmark_cuda_comparison.sh
```

### Customizing Build Directories

You can override the default build directory locations using environment variables:

```bash
# For OpenMP benchmarks
export TASK_PARALLEL_BUILD_DIR=/path/to/task-parallel/build
export MASTER_BUILD_DIR=/path/to/master/build
./benchmark_task_parallel.sh

# For CUDA benchmarks
export CUDA_BUILD_DIR=/path/to/cuda/build
./benchmark_gpu_scaling.sh
```

### Plotting Results

After running benchmarks, use the plotting scripts to visualize the results:

```bash
# Plot scaling benchmark (finds most recent results automatically)
./plot_scaling.py

# Plot CUDA comparison (specify results directory)
./plot_cuda_comparison.py results/benchmark_cuda_comparison_20251117_120000/

# Plot GPU scaling
./plot_gpu_scaling.py
```

## Benchmark Descriptions

### benchmark_task_parallel.sh

Compares the task-parallel branch against the master branch using OpenMP on a single problem size. Tests both branches with the same parameters and reports speedup.

**Default Parameters:**
- Grid: 64×64×64
- Particles: 100,000
- Timesteps: 10,000
- Threads: 16

### benchmark_scaling.sh

Performs a strong scaling study by testing multiple thread counts with a fixed problem size. Measures parallel efficiency for both task-parallel and master branches.

**Default Thread Counts:** 1, 2, 4, 8, 16, 32

### benchmark_gpu_scaling.sh

Tests GPU performance with varying particle counts on a fixed grid size. Useful for understanding how performance scales with problem size on GPUs.

**Particle Counts Tested:** 50K, 100K, 250K, 500K, 1M, 2M, 5M

### benchmark_gpu_vs_cpu.sh

Direct comparison between CUDA (GPU) and OpenMP (CPU) implementations across different problem sizes.

**Problem Sizes:** Small, Medium, Large, XLarge (varying grid and particle counts)

### benchmark_cuda_comparison.sh

Compares task-parallel and master branches on CUDA with multiple particle counts. Similar to `benchmark_task_parallel.sh` but for GPU builds.

## Results Format

Each benchmark creates a timestamped directory in `results/` containing:

- Raw output files (`*_output.txt`)
- Timing data (`*_timing.dat`)
- CSV summary (`results.csv`)
- Summary text file (`summary.txt`)
- Generated plots (PNG and PDF)

## Notes

- Benchmark scripts automatically handle git branch switching for comparisons
- Results are stored locally and not committed to git (see `.gitignore`)
- Scripts use absolute paths to maintain correct working directories
- The IPPL directory location can be customized via the `IPPL_DIR` environment variable

## Related Links

- [IPPL Repository](https://github.com/IPPL-framework/ippl)
- IPPL Documentation

## License

This benchmark suite follows the same license as IPPL (GNU GPL version 3).
