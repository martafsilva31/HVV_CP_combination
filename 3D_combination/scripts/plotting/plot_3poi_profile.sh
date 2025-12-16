#!/bin/bash
# Plot 3POI profile scan results showing profiled values of floating Wilson coefficients
#
# Usage: ./plot_3poi_profile.sh [options]
#
# Options:
#   --name NAME           Scan name (default: linear_asimov)
#   --model MODEL         Model type: linear_only or quadratic (default: linear_only)
#   --stat-type TYPE      Stat type: stat_only or full_syst (default: stat_only)
#   --data-type TYPE      Data type: asimov or obs (default: asimov)
#   --poi POI             Scanned POI (default: cHWtil_combine)
#   --base-dir DIR        Base directory for output (default: ../../output)
#   --output-dir DIR      Output directory for plots (default: auto from base-dir)
#   --all                 Run for all POIs
#   --all-models          Run for both linear_only and quadratic models
#   -h, --help            Show this help message
#
# Examples:
#   ./plot_3poi_profile.sh --poi cHWtil_combine
#   ./plot_3poi_profile.sh --all --model linear_only
#   ./plot_3poi_profile.sh --all --all-models

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Default base directory is relative to the 3D_combination folder
BASE_DIR="${SCRIPT_DIR}/../../output"

# Default values
NAME="linear_asimov"
MODEL="linear_only"
STAT_TYPE="stat_only"
DATA_TYPE="asimov"
POI="cHWtil_combine"
OUTPUT_DIR=""
RUN_ALL=false
ALL_MODELS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            NAME="$2"
            shift 2
            ;;
        --model)
            MODEL="$2"
            shift 2
            ;;
        --stat-type)
            STAT_TYPE="$2"
            shift 2
            ;;
        --data-type)
            DATA_TYPE="$2"
            shift 2
            ;;
        --poi)
            POI="$2"
            shift 2
            ;;
        --base-dir)
            BASE_DIR="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --all)
            RUN_ALL=true
            shift
            ;;
        --all-models)
            ALL_MODELS=true
            shift
            ;;
        -h|--help)
            head -25 "$0" | tail -24
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Resolve BASE_DIR to absolute path
BASE_DIR="$(cd "${BASE_DIR}" 2>/dev/null && pwd)" || {
    echo "Error: Base directory not found: ${BASE_DIR}"
    exit 1
}

# Function to plot a single POI
plot_single_poi() {
    local model="$1"
    local poi="$2"
    
    # Update name based on model
    local name
    if [[ "${model}" == "linear_only" ]]; then
        name="linear_${DATA_TYPE}"
    else
        name="quad_${DATA_TYPE}"
    fi
    
    # Determine paths
    local input_dir="${BASE_DIR}/3POI_1D_scans/${model}/${STAT_TYPE}/${DATA_TYPE}/root_${name}_${poi}_sequential"
    local output_dir="${OUTPUT_DIR:-${BASE_DIR}/3POI_1D_scans/${model}/${STAT_TYPE}/${DATA_TYPE}/plots}"
    
    # Determine labels
    local data_label
    if [[ "${DATA_TYPE}" == "asimov" ]]; then
        data_label="Asimov"
    else
        data_label="Data"
    fi
    
    local model_label
    if [[ "${model}" == "linear_only" ]]; then
        model_label="Linear"
    else
        model_label="Quadratic"
    fi
    
    # POI display name
    local poi_label
    case "${poi}" in
        cHWtil_combine)
            poi_label="cHWtil"
            ;;
        cHBtil_combine)
            poi_label="cHBtil"
            ;;
        cHWBtil_combine)
            poi_label="cHWBtil"
            ;;
        *)
            poi_label="${poi}"
            ;;
    esac
    
    # Output file name
    local output_file="profile_${name}_${poi}.pdf"
    
    echo "=============================================="
    echo "3POI Profile Plot"
    echo "=============================================="
    echo "Name:      ${name}"
    echo "Model:     ${model} (${model_label})"
    echo "Stat type: ${STAT_TYPE}"
    echo "Data type: ${DATA_TYPE} (${data_label})"
    echo "POI:       ${poi} (${poi_label})"
    echo ""
    echo "Input:     ${input_dir}"
    echo "Output:    ${output_dir}/${output_file}"
    echo "=============================================="
    
    # Check if input directory exists
    if [[ ! -d "${input_dir}" ]]; then
        echo "Warning: Input directory not found: ${input_dir}"
        echo "Skipping..."
        echo ""
        return 1
    fi
    
    # Create output directory
    mkdir -p "${output_dir}"
    
    # Run the plotting script
    python3 "${SCRIPT_DIR}/plot_3poi_profile.py" \
        --input "${input_dir}" \
        --poi "${poi}" \
        --output "${output_file}" \
        --output-dir "${output_dir}" \
        --data-type "${data_label}" \
        --title "${model_label} EFT - ${poi_label} Scan (${data_label})"
    
    echo ""
    echo "Done: ${output_dir}/${output_file}"
    echo ""
}

# Define all POIs
ALL_POIS=("cHWtil_combine" "cHBtil_combine" "cHWBtil_combine")

# Define models to run
if [[ "${ALL_MODELS}" == true ]]; then
    MODELS=("linear_only" "quadratic")
else
    MODELS=("${MODEL}")
fi

# Run plotting
if [[ "${RUN_ALL}" == true ]]; then
    echo "Running for all POIs..."
    for model in "${MODELS[@]}"; do
        for poi in "${ALL_POIS[@]}"; do
            plot_single_poi "${model}" "${poi}" || true
        done
    done
else
    plot_single_poi "${MODEL}" "${POI}"
fi

echo "All done!"
