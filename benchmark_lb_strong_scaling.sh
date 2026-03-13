#!/bin/bash

# MPI Strong Scaling Benchmark for IndependentParticlesTest (tree-based load balancing)
#
# Fixes total particle count and varies the number of MPI ranks.
# Reports per-stage wall times (stage1Simulation, stage2BirthDeath, stage3LoadBalance)
# and total elapsed time, plus parallel efficiency.
#
# Usage:
#   ./benchmark_lb_strong_scaling.sh
#
# Override defaults via environment variables:
#   PARTICLES=50000 TIMESTEPS=200 LBFREQ=20 MPI_RANKS="1 2 4 8" ./benchmark_lb_strong_scaling.sh

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IPPL_DIR="${IPPL_DIR:-${SCRIPT_DIR}/../ippl}"
BUILD_DIR="${BUILD_DIR:-${IPPL_DIR}/build-openmp}"
BINARY="${BUILD_DIR}/alpine/ExamplesWithoutPicManager/IndependentParticlesTest"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Benchmark parameters
PARTICLES="${PARTICLES:-10000}"
TIMESTEPS="${TIMESTEPS:-100}"
LBFREQ="${LBFREQ:-20}"
MPI_RANKS="${MPI_RANKS:-1 2 4 8}"

# One OpenMP thread per rank so we measure pure MPI scaling
export OMP_NUM_THREADS=1

RESULTS_DIR="${SCRIPT_DIR}/results/benchmark_lb_strong_scaling_$(date +%Y%m%d_%H%M%S)"
mkdir -p "${RESULTS_DIR}"

# ============================================================
# Helper: extract a named timer's Wall avg from timing.dat
# Usage: extract_stage <file> <timer_name>
# ============================================================
extract_stage() {
    local file="$1"
    local name="$2"
    awk -v key="${name}" '
        $0 ~ key {
            # Line format: <name>...  <ranks>  <Wall max>  <Wall min>  <Wall avg>
            print $NF
            exit
        }
    ' "${file}"
}

extract_elapsed() {
    grep "Elapsed time:" "$1" | tail -1 | awk '{print $3}'
}

echo -e "${CYAN}=== IndependentParticlesTest — MPI Strong Scaling Benchmark ===${NC}"
echo "Binary:      ${BINARY}"
echo "Build dir:   ${BUILD_DIR}"
echo "Particles:   ${PARTICLES}"
echo "Timesteps:   ${TIMESTEPS}"
echo "LB freq:     ${LBFREQ}"
echo "MPI ranks:   ${MPI_RANKS}"
echo "OMP threads: ${OMP_NUM_THREADS}"
echo "Results dir: ${RESULTS_DIR}"
echo ""

if [ ! -f "${BINARY}" ]; then
    echo -e "${GREEN}Binary not found, building...${NC}"
    cd "${BUILD_DIR}"
    cmake --build . -j$(nproc) --target IndependentParticlesTest
fi

# ============================================================
# Run for each rank count
# ============================================================

declare -A TIME_TOTAL
declare -A TIME_STAGE1
declare -A TIME_STAGE2
declare -A TIME_STAGE3

for NP in ${MPI_RANKS}; do
    echo -e "${YELLOW}--- Running with ${NP} MPI rank(s) ---${NC}"

    OUT="${RESULTS_DIR}/ranks_${NP}.txt"
    DAT="${RESULTS_DIR}/ranks_${NP}_timing.dat"

    # Run from the binary's directory so timing.dat lands there
    RUN_DIR="$(dirname "${BINARY}")"
    cd "${RUN_DIR}"

    mpirun -n "${NP}" "${BINARY}" "${PARTICLES}" "${TIMESTEPS}" "${LBFREQ}" --info 10 \
        > "${OUT}" 2>&1

    if [ -f timing.dat ]; then
        cp timing.dat "${DAT}"
    fi

    TIME_TOTAL[${NP}]=$(extract_elapsed "${OUT}")
    TIME_STAGE1[${NP}]=$(extract_stage "${DAT}" "stage1Simulation")
    TIME_STAGE2[${NP}]=$(extract_stage "${DAT}" "stage2BirthDeath")
    TIME_STAGE3[${NP}]=$(extract_stage "${DAT}" "stage3LoadBalance")

    echo -e "  Elapsed:        ${TIME_TOTAL[${NP}]} s"
    echo -e "  stage1 (sim):   ${TIME_STAGE1[${NP}]} s (Wall avg)"
    echo -e "  stage2 (b/d):   ${TIME_STAGE2[${NP}]} s (Wall avg)"
    echo -e "  stage3 (LB):    ${TIME_STAGE3[${NP}]} s (Wall avg)"
    echo ""
done

# ============================================================
# Summary table
# ============================================================

# Determine baseline (smallest rank count)
BASE_NP=$(echo ${MPI_RANKS} | awk '{print $1}')
BASE_TIME=${TIME_TOTAL[${BASE_NP}]}

echo -e "${CYAN}=== STRONG SCALING RESULTS ===${NC}"
echo ""
printf "%-8s %-14s %-12s %-12s %-12s %-10s %-12s\n" \
    "Ranks" "Total(s)" "Stage1(s)" "Stage2(s)" "Stage3(s)" "Speedup" "Efficiency"
printf "%-8s %-14s %-12s %-12s %-12s %-10s %-12s\n" \
    "-----" "--------" "---------" "---------" "---------" "-------" "----------"

for NP in ${MPI_RANKS}; do
    T=${TIME_TOTAL[${NP}]}
    S1=${TIME_STAGE1[${NP}]}
    S2=${TIME_STAGE2[${NP}]}
    S3=${TIME_STAGE3[${NP}]}

    if [ -n "${T}" ] && [ -n "${BASE_TIME}" ]; then
        SPEEDUP=$(awk "BEGIN {printf \"%.2f\", ${BASE_TIME}/${T}}")
        EFF=$(awk "BEGIN {printf \"%.1f\", 100*${BASE_TIME}/(${T}*${NP})}")
        printf "%-8s %-14s %-12s %-12s %-12s %-10s %-12s\n" \
            "${NP}" "${T}" "${S1:-N/A}" "${S2:-N/A}" "${S3:-N/A}" "${SPEEDUP}x" "${EFF}%"
    else
        printf "%-8s %-14s %-12s %-12s %-12s %-10s %-12s\n" \
            "${NP}" "N/A" "N/A" "N/A" "N/A" "N/A" "N/A"
    fi
done

# ============================================================
# CSV output
# ============================================================

CSV="${RESULTS_DIR}/results.csv"
echo "Ranks,Total_s,Stage1_s,Stage2_s,Stage3_s,Speedup,Efficiency_pct" > "${CSV}"

for NP in ${MPI_RANKS}; do
    T=${TIME_TOTAL[${NP}]}
    S1=${TIME_STAGE1[${NP}]:-N/A}
    S2=${TIME_STAGE2[${NP}]:-N/A}
    S3=${TIME_STAGE3[${NP}]:-N/A}

    if [ -n "${T}" ] && [ -n "${BASE_TIME}" ]; then
        SPEEDUP=$(awk "BEGIN {printf \"%.4f\", ${BASE_TIME}/${T}}")
        EFF=$(awk "BEGIN {printf \"%.2f\", 100*${BASE_TIME}/(${T}*${NP})}")
        echo "${NP},${T},${S1},${S2},${S3},${SPEEDUP},${EFF}" >> "${CSV}"
    fi
done

echo ""
echo "Results saved to: ${RESULTS_DIR}"
echo "  CSV: ${CSV}"

# ============================================================
# Summary file
# ============================================================

cat > "${RESULTS_DIR}/summary.txt" <<EOF
IndependentParticlesTest — MPI Strong Scaling Benchmark
========================================================
Date:      $(date)
Binary:    ${BINARY}
Particles: ${PARTICLES}
Timesteps: ${TIMESTEPS}
LB freq:   ${LBFREQ}
OMP threads per rank: ${OMP_NUM_THREADS}

Baseline: ${BASE_NP} rank(s), ${BASE_TIME} s

Ranks | Total(s) | Stage1(s) | Stage2(s) | Stage3(s) | Speedup | Efficiency
EOF

for NP in ${MPI_RANKS}; do
    T=${TIME_TOTAL[${NP}]}
    S1=${TIME_STAGE1[${NP}]:-N/A}
    S2=${TIME_STAGE2[${NP}]:-N/A}
    S3=${TIME_STAGE3[${NP}]:-N/A}

    if [ -n "${T}" ] && [ -n "${BASE_TIME}" ]; then
        SPEEDUP=$(awk "BEGIN {printf \"%.2f\", ${BASE_TIME}/${T}}")
        EFF=$(awk "BEGIN {printf \"%.1f\", 100*${BASE_TIME}/(${T}*${NP})}")
        echo "${NP}    | ${T}       | ${S1}      | ${S2}      | ${S3}      | ${SPEEDUP}x  | ${EFF}%" \
            >> "${RESULTS_DIR}/summary.txt"
    fi
done

echo "  Summary: ${RESULTS_DIR}/summary.txt"
