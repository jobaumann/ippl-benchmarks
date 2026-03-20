#!/bin/bash
# =============================================================================
# LB Strong Scaling Benchmark — Generator Script (CPU/OpenMP, SLURM)
#
# Generates and submits one SLURM job per (ranks, particles) combination.
# Results land in results/benchmark_lb_strong_scaling_cluster_<timestamp>/
#
# Usage:
#   ./benchmark_lb_strong_scaling_cluster.sh        # submit all 16 jobs
#   ./benchmark_lb_strong_scaling_cluster.sh --dry-run  # generate scripts only
# =============================================================================

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# ── Cluster config ────────────────────────────────────────────────────────────
ACCOUNT="c41"
TIME_LIMIT="00:30:00"
UENV="prgenv-gnu/25.6:v2"
CPUS_PER_TASK=1   # OMP_NUM_THREADS per MPI rank

# ── Binary ────────────────────────────────────────────────────────────────────
BUILD_DIR="${IPPL_DIR:-${SCRIPT_DIR}/../ippl}/build-openmp"
EXE="${BUILD_DIR}/alpine/ExamplesWithoutPicManager/IndependentParticlesTest"

# ── Benchmark parameters ──────────────────────────────────────────────────────
RANKS_LIST=(4 9 19 39)
PARTICLES_LIST=(100000 200000 500000 1000000)
TIMESTEPS=200
LBFREQ=20

# ── Results directory ─────────────────────────────────────────────────────────
RESULTS_DIR="${SCRIPT_DIR}/results/benchmark_lb_strong_scaling_cluster_$(date +%Y%m%d_%H%M%S)"
mkdir -p "${RESULTS_DIR}"

DRY_RUN=false
if [[ "${1}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "=== DRY RUN — scripts will be generated but not submitted ==="
fi

echo "Results directory: ${RESULTS_DIR}"
echo ""

# =============================================================================
# Generate one job script per (ranks, particles) pair
# =============================================================================
for RANKS in "${RANKS_LIST[@]}"; do
for NP in "${PARTICLES_LIST[@]}"; do

    LABEL="ranks${RANKS}_np${NP}"
    JOB_SCRIPT="${RESULTS_DIR}/job_${LABEL}.sh"
    OUT_FILE="${RESULTS_DIR}/${LABEL}.out"
    ERR_FILE="${RESULTS_DIR}/${LABEL}.err"
    TXT_FILE="${RESULTS_DIR}/${LABEL}.txt"
    DAT_FILE="${RESULTS_DIR}/${LABEL}_timing.dat"

    cat > "${JOB_SCRIPT}" << EOF
#!/bin/bash
#SBATCH --job-name=ippl_lb_${LABEL}
#SBATCH --account=${ACCOUNT}
#SBATCH --time=${TIME_LIMIT}
#SBATCH --ntasks=${RANKS}
#SBATCH --cpus-per-task=${CPUS_PER_TASK}
#SBATCH --exclusive
#SBATCH --uenv=${UENV}
#SBATCH --view=default
#SBATCH --output=${OUT_FILE}
#SBATCH --error=${ERR_FILE}

echo "============================================"
echo "IPPL LB Strong Scaling Benchmark"
echo "Ranks:     ${RANKS}"
echo "Particles: ${NP}"
echo "Timesteps: ${TIMESTEPS}"
echo "LB freq:   ${LBFREQ}"
echo "============================================"
echo ""

export WRAPPER=/user-environment/wrapper-mpi.sh
export OMP_NUM_THREADS=1
export OMP_PROC_BIND=spread
export OMP_PLACES=threads

EXE="${EXE}"
if [ ! -f "\${EXE}" ]; then
    echo "ERROR: Executable not found: \${EXE}"
    exit 1
fi

echo "Running: srun \${WRAPPER} \${EXE} ${NP} ${TIMESTEPS} ${LBFREQ} --info 10"
echo ""

srun \${WRAPPER} "\${EXE}" ${NP} ${TIMESTEPS} ${LBFREQ} --info 10 > "${TXT_FILE}" 2>&1

# Copy timing.dat if produced (written to the cwd = job launch dir)
if [ -f timing.dat ]; then
    cp timing.dat "${DAT_FILE}"
fi

echo ""
echo "Done. Output: ${TXT_FILE}"
EOF

    chmod +x "${JOB_SCRIPT}"

    if [ "${DRY_RUN}" = false ]; then
        sbatch "${JOB_SCRIPT}"
        echo "  Submitted: ${LABEL}"
    else
        echo "  Generated: ${JOB_SCRIPT}"
    fi

done
done

echo ""
echo "All jobs submitted (${#RANKS_LIST[@]} ranks × ${#PARTICLES_LIST[@]} particle counts = $((${#RANKS_LIST[@]} * ${#PARTICLES_LIST[@]})) jobs)"
echo ""
echo "Monitor with:  squeue -u \$USER"
echo "Parse results: ${SCRIPT_DIR}/process_lb_cluster_results.sh ${RESULTS_DIR}"
