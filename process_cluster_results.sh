#!/bin/bash

# Process CUDA cluster benchmark results
# Parses output files and generates CSV summary

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <results_directory>"
    echo ""
    echo "Example:"
    echo "  $0 results/benchmark_cuda_comparison_cluster_20251118_120000/"
    exit 1
fi

RESULTS_DIR=$1

if [ ! -d "${RESULTS_DIR}" ]; then
    echo "Error: Directory not found: ${RESULTS_DIR}"
    exit 1
fi

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Processing IPPL CUDA Cluster Benchmark Results ===${NC}"
echo "Results directory: ${RESULTS_DIR}"
echo ""

# Function to extract elapsed time from output
extract_time() {
    local file=$1
    if [ -f "${file}" ]; then
        grep "Elapsed time:" ${file} | awk '{print $3}' 2>/dev/null || echo "N/A"
    else
        echo "N/A"
    fi
}

# Initialize CSV file
CSV_FILE="${RESULTS_DIR}/results.csv"
echo "Label,Power,Particles,TaskParallel_Time_s,Master_Time_s,Speedup,TaskParallel_Throughput,Master_Throughput" > ${CSV_FILE}

echo -e "${GREEN}Parsing results...${NC}"
echo ""

# Define particle powers
PARTICLE_POWERS=(20 21 22 23 24 25 26 27 28 29 30)
TIMESTEPS=1024

printf "%-10s %-15s %-20s %-20s %-15s\n" "Label" "Particles" "Task-Parallel (s)" "Master (s)" "Speedup"
printf "%-10s %-15s %-20s %-20s %-15s\n" "------" "----------" "------------------" "----------" "-------"

for power in "${PARTICLE_POWERS[@]}"; do
    particles=$((2**power))
    label="2p${power}"

    # Get times
    tp_file="${RESULTS_DIR}/taskparallel_${label}.txt"
    master_file="${RESULTS_DIR}/master_${label}.txt"

    tp_time=$(extract_time ${tp_file})
    master_time=$(extract_time ${master_file})

    # Check if both results exist
    if [ "$tp_time" != "N/A" ] && [ "$master_time" != "N/A" ]; then
        # Calculate speedup
        speedup=$(echo "scale=4; ${master_time} / ${tp_time}" | bc 2>/dev/null || echo "N/A")

        # Calculate throughput (particle-updates per second)
        # throughput = particles * timesteps / time
        tp_throughput=$(echo "scale=2; ${particles} * ${TIMESTEPS} / ${tp_time}" | bc 2>/dev/null || echo "N/A")
        master_throughput=$(echo "scale=2; ${particles} * ${TIMESTEPS} / ${master_time}" | bc 2>/dev/null || echo "N/A")

        # Print summary
        printf "%-10s %-15s %-20s %-20s %-15s\n" "${label}" "${particles}" "${tp_time}" "${master_time}" "${speedup}x"

        # Write to CSV
        echo "${label},${power},${particles},${tp_time},${master_time},${speedup},${tp_throughput},${master_throughput}" >> ${CSV_FILE}
    else
        echo -e "${YELLOW}Skipping ${label}: Missing results (TP=${tp_time}, Master=${master_time})${NC}"
    fi
done

echo ""

# Count completed vs total
total_tests=$((${#PARTICLE_POWERS[@]} * 2))  # 2 branches per particle count
completed_tp=$(ls ${RESULTS_DIR}/taskparallel_*.txt 2>/dev/null | wc -l)
completed_master=$(ls ${RESULTS_DIR}/master_*.txt 2>/dev/null | wc -l)
completed=$((completed_tp + completed_master))

echo -e "${BLUE}Results Summary:${NC}"
echo "  Total tests expected: ${total_tests}"
echo "  Completed: ${completed}"
echo "  Task-parallel: ${completed_tp}/${#PARTICLE_POWERS[@]}"
echo "  Master: ${completed_master}/${#PARTICLE_POWERS[@]}"
echo ""

if [ ${completed} -eq ${total_tests} ]; then
    echo -e "${GREEN}All tests completed successfully!${NC}"
else
    echo -e "${YELLOW}Warning: Some tests are incomplete or failed${NC}"
    echo ""
    echo "Check SLURM output files for errors:"
    echo "  ${RESULTS_DIR}/*.err"
fi

echo ""
echo "CSV results saved to: ${CSV_FILE}"
echo ""
echo "To plot results:"
echo "  ${0%/*}/plot_cuda_comparison.py ${RESULTS_DIR}"
echo ""

# Generate a summary statistics file
SUMMARY_FILE="${RESULTS_DIR}/summary.txt"
{
    echo "IPPL CUDA Cluster Benchmark Results"
    echo "===================================="
    echo ""
    echo "Date: $(date)"
    echo "Results directory: ${RESULTS_DIR}"
    echo ""
    echo "Test Configuration:"
    echo "  Grid: 128x128x128"
    echo "  Timesteps: 1024 (2^10)"
    echo "  Particle counts: 2^20 to 2^30"
    echo ""
    echo "Results:"
    echo "--------"
    cat ${CSV_FILE} | column -t -s,
    echo ""

    # Calculate average speedup if we have results
    if [ -f "${CSV_FILE}" ]; then
        avg_speedup=$(awk -F, 'NR>1 && $6!="N/A" {sum+=$6; count++} END {if(count>0) printf "%.3f", sum/count; else print "N/A"}' ${CSV_FILE})
        echo "Average Speedup: ${avg_speedup}x"
        echo ""
    fi

    echo "Statistics:"
    echo "-----------"
    echo "  Total tests: ${total_tests}"
    echo "  Completed: ${completed}"
    echo "  Success rate: $((100 * completed / total_tests))%"

} > ${SUMMARY_FILE}

echo "Summary saved to: ${SUMMARY_FILE}"
echo ""
echo -e "${GREEN}Processing complete!${NC}"
