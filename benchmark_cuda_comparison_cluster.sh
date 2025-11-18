#!/bin/bash

# CUDA Branch Comparison Benchmark for Cluster (SLURM)
# Compares task-parallel vs master branch on CUDA with powers of 2 particle counts
# Designed for Alps/Piz Daint cluster with GH200 GPUs

set -e

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Configuration
ACCOUNT="${SLURM_ACCOUNT:-c41}"  # Override with your account
TIME_LIMIT="01:00:00"  # Adjust as needed
NODES=1
TASKS_PER_NODE=1
GPUS_PER_TASK=1
CPUS_PER_TASK=72

# IPPL configuration
IPPL_DIR="${IPPL_DIR:-${SCRIPT_DIR}/../ippl}"
TASK_PARALLEL_BUILD_DIR="${TASK_PARALLEL_BUILD_DIR:-${IPPL_DIR}/build-cuda}"
MASTER_BUILD_DIR="${MASTER_BUILD_DIR:-${IPPL_DIR}/build-cuda-master}"

# Test parameters
TIMESTEPS=1024  # 2^10
NX=128
NY=128
NZ=128
SOLVER="FFT"
LBFREQ=10
OVERALLOC=1.0

# Particle counts: 2^20 to 2^30
declare -a PARTICLE_POWERS=(20 21 22 23 24 25 26 27 28 29 30)

# Results directory
RESULTS_DIR="${SCRIPT_DIR}/results/benchmark_cuda_comparison_cluster_$(date +%Y%m%d_%H%M%S)"
mkdir -p ${RESULTS_DIR}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== IPPL CUDA Cluster Benchmark Generator ===${NC}"
echo "Cluster: Alps/Piz Daint"
echo "Results directory: ${RESULTS_DIR}"
echo ""
echo "Test configuration:"
echo "  Grid: ${NX}x${NY}x${NZ}"
echo "  Timesteps: ${TIMESTEPS} (2^10)"
echo "  Particle counts: 2^20 to 2^30"
echo ""
echo "SLURM configuration:"
echo "  Account: ${ACCOUNT}"
echo "  Time limit: ${TIME_LIMIT}"
echo "  Nodes: ${NODES}"
echo "  GPUs per task: ${GPUS_PER_TASK}"
echo ""

# Function to generate SLURM job script
generate_job_script() {
    local power=$1
    local particles=$2
    local label=$3
    local branch=$4
    local build_dir=$5
    local output_file=$6

    cat > ${output_file} << EOF
#!/bin/bash
#SBATCH --job-name=ippl_${branch}_${label}
#SBATCH --account=${ACCOUNT}
#SBATCH --time=${TIME_LIMIT}
#SBATCH --nodes=${NODES}
#SBATCH --ntasks-per-node=${TASKS_PER_NODE}
#SBATCH --gpus-per-task=${GPUS_PER_TASK}
#SBATCH --cpus-per-task=${CPUS_PER_TASK}
#SBATCH --exclusive
#SBATCH --uenv=/capstor/store/cscs/cscs/public/uenvs/opal-x-gh200-mpich-gcc-2025-09-28-cuda12.8.squashfs
#SBATCH --view=develop
#SBATCH --output=${RESULTS_DIR}/${branch}_${label}.out
#SBATCH --error=${RESULTS_DIR}/${branch}_${label}.err

echo "=========================================="
echo "IPPL CUDA Benchmark"
echo "Branch: ${branch}"
echo "Particles: ${particles} (2^${power})"
echo "Timesteps: ${TIMESTEPS}"
echo "=========================================="
echo ""

# Environment
export WRAPPER=/user-environment/wrapper-mpi.sh
export OMP_PROC_BIND=spread
export OMP_PLACES=threads
export OMP_NUM_THREADS=${CPUS_PER_TASK}

# Executable
EXE="${build_dir}/alpine/ExamplesWithoutPicManager/IndependentParticlesTest"

if [ ! -f "\${EXE}" ]; then
    echo "ERROR: Executable not found: \${EXE}"
    exit 1
fi

echo "Running benchmark..."
echo "Command: srun \${WRAPPER} \${EXE} ${NX} ${NY} ${NZ} ${particles} ${TIMESTEPS} ${SOLVER} ${LBFREQ} --overallocate ${OVERALLOC} --info 10"
echo ""

# Run benchmark
srun \${WRAPPER} \${EXE} ${NX} ${NY} ${NZ} ${particles} ${TIMESTEPS} ${SOLVER} ${LBFREQ} --overallocate ${OVERALLOC} --info 10 > ${RESULTS_DIR}/${branch}_${label}.txt 2>&1

# Copy timing data if it exists
if [ -f timing.dat ]; then
    cp timing.dat ${RESULTS_DIR}/${branch}_${label}_timing.dat
fi

echo ""
echo "Benchmark complete!"
echo "Results saved to: ${RESULTS_DIR}/${branch}_${label}.txt"
EOF

    chmod +x ${output_file}
}

# Generate job scripts for each particle count
echo -e "${GREEN}Generating SLURM job scripts...${NC}"
echo ""

for power in "${PARTICLE_POWERS[@]}"; do
    particles=$((2**power))
    label="2p${power}"  # e.g., 2p20 for 2^20

    echo "  Particle count: 2^${power} = ${particles}"

    # Generate task-parallel job script
    tp_script="${RESULTS_DIR}/job_taskparallel_${label}.sh"
    generate_job_script ${power} ${particles} ${label} "taskparallel" ${TASK_PARALLEL_BUILD_DIR} ${tp_script}

    # Generate master job script
    master_script="${RESULTS_DIR}/job_master_${label}.sh"
    generate_job_script ${power} ${particles} ${label} "master" ${MASTER_BUILD_DIR} ${master_script}
done

echo ""
echo -e "${BLUE}Job scripts generated successfully!${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Review the generated scripts in: ${RESULTS_DIR}"
echo ""
echo "2. Submit all jobs at once:"
echo "   cd ${RESULTS_DIR}"
echo "   for job in job_*.sh; do sbatch \$job; done"
echo ""
echo "3. Or submit individual jobs:"
echo "   sbatch ${RESULTS_DIR}/job_taskparallel_2p20.sh"
echo "   sbatch ${RESULTS_DIR}/job_master_2p20.sh"
echo ""
echo "4. Monitor job status:"
echo "   squeue -u \$USER"
echo ""
echo "5. After jobs complete, process results:"
echo "   ${SCRIPT_DIR}/process_cluster_results.sh ${RESULTS_DIR}"
echo ""

# Create results processing script
cat > ${RESULTS_DIR}/submit_all.sh << 'EOFSUBMIT'
#!/bin/bash
# Submit all benchmark jobs

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${SCRIPT_DIR}

echo "Submitting all benchmark jobs..."
echo ""

for job in job_*.sh; do
    echo "Submitting: $job"
    sbatch $job
    sleep 1  # Small delay to avoid overwhelming scheduler
done

echo ""
echo "All jobs submitted!"
echo "Monitor with: squeue -u \$USER"
EOFSUBMIT

chmod +x ${RESULTS_DIR}/submit_all.sh

echo -e "${GREEN}Quick submit script created: ${RESULTS_DIR}/submit_all.sh${NC}"
echo ""
echo "To submit all jobs: ${RESULTS_DIR}/submit_all.sh"
