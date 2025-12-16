#!/bin/bash
# Plot 3POI profile scan results showing profiled values of floating Wilson coefficients
#
# Usage: ./plot_3poi_profile.sh --input <dir> --poi <poi> [options]
#
# Required:
#   --input DIR           Input directory containing ROOT scan files (fit_<poi>_*.root)
#   --poi POI             Scanned POI name (e.g., cHWtil_combine)
#
# Optional:
#   --output FILE         Output filename (default: profile_<poi>.pdf)
#   --output-dir DIR      Output directory (default: same as input/../plots)
#   --title TITLE         Plot title (default: auto-generated)
#   --data-type TYPE      Data type label: Data or Asimov (default: auto from path)
#   --no-atlas            Disable ATLAS label
#   --no-legend           Disable legend
#   --no-errors           Disable uncertainty bands
#   -h, --help            Show this help message
#
# Examples:
#   # Basic usage with explicit input
#   ./plot_3poi_profile.sh --input /path/to/root_files --poi cHWtil_combine
#
#   # Custom output location
#   ./plot_3poi_profile.sh --input /path/to/root_files --poi cHWtil_combine \
#       --output my_plot.pdf --output-dir /path/to/plots
#
#   # With custom title
#   ./plot_3poi_profile.sh --input /path/to/root_files --poi cHWtil_combine \
#       --title "Linear EFT - cHWtil Scan (Asimov)"

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
INPUT_DIR=""
POI=""
OUTPUT_FILE=""
OUTPUT_DIR=""
TITLE=""
DATA_TYPE=""
NO_ATLAS=""
NO_LEGEND=""
NO_ERRORS=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --input|-i)
            INPUT_DIR="$2"
            shift 2
            ;;
        --poi|-p)
            POI="$2"
            shift 2
            ;;
        --output|-o)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --title|-t)
            TITLE="$2"
            shift 2
            ;;
        --data-type)
            DATA_TYPE="$2"
            shift 2
            ;;
        --no-atlas)
            NO_ATLAS="--no-atlas"
            shift
            ;;
        --no-legend)
            NO_LEGEND="--no-legend"
            shift
            ;;
        --no-errors)
            NO_ERRORS="--no-errors"
            shift
            ;;
        -h|--help)
            head -35 "$0" | tail -34
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "${INPUT_DIR}" ]]; then
    echo "Error: --input is required"
    echo "Use --help for usage information"
    exit 1
fi

if [[ -z "${POI}" ]]; then
    echo "Error: --poi is required"
    echo "Use --help for usage information"
    exit 1
fi

# Resolve INPUT_DIR to absolute path
INPUT_DIR="$(cd "${INPUT_DIR}" 2>/dev/null && pwd)" || {
    echo "Error: Input directory not found: ${INPUT_DIR}"
    exit 1
}

# Auto-detect data type from path if not specified
if [[ -z "${DATA_TYPE}" ]]; then
    if [[ "${INPUT_DIR}" == *"/asimov/"* ]]; then
        DATA_TYPE="Asimov"
    elif [[ "${INPUT_DIR}" == *"/obs/"* ]]; then
        DATA_TYPE="Data"
    else
        DATA_TYPE="Data"
    fi
fi

# Auto-detect model type from path for title
MODEL_LABEL=""
if [[ "${INPUT_DIR}" == *"linear_only"* ]]; then
    MODEL_LABEL="Linear"
elif [[ "${INPUT_DIR}" == *"linear_plus_quadratic"* ]] || [[ "${INPUT_DIR}" == *"quadratic"* ]]; then
    MODEL_LABEL="Quadratic"
fi

# POI display name
POI_LABEL="${POI}"
case "${POI}" in
    cHWtil_combine)
        POI_LABEL="cHWtil"
        ;;
    cHBtil_combine)
        POI_LABEL="cHBtil"
        ;;
    cHWBtil_combine)
        POI_LABEL="cHWBtil"
        ;;
esac

# Default output directory: ../plots relative to input
if [[ -z "${OUTPUT_DIR}" ]]; then
    OUTPUT_DIR="$(dirname "${INPUT_DIR}")/plots"
fi

# Default output filename
if [[ -z "${OUTPUT_FILE}" ]]; then
    # Extract name from input directory (e.g., root_linear_asimov_cHWtil_combine_sequential -> linear_asimov)
    DIR_NAME="$(basename "${INPUT_DIR}")"
    # Remove root_ prefix and _<poi>_sequential/parallel suffix
    NAME="${DIR_NAME#root_}"
    NAME="${NAME%_${POI}_*}"
    OUTPUT_FILE="profile_${NAME}_${POI}.pdf"
fi

# Default title
if [[ -z "${TITLE}" ]]; then
    if [[ -n "${MODEL_LABEL}" ]]; then
        TITLE="${MODEL_LABEL} EFT - ${POI_LABEL} Scan (${DATA_TYPE})"
    else
        TITLE="${POI_LABEL} Scan (${DATA_TYPE})"
    fi
fi

# Create output directory
mkdir -p "${OUTPUT_DIR}"

echo "=============================================="
echo "3POI Profile Plot"
echo "=============================================="
echo "Input:     ${INPUT_DIR}"
echo "POI:       ${POI} (${POI_LABEL})"
echo "Data type: ${DATA_TYPE}"
echo "Title:     ${TITLE}"
echo "Output:    ${OUTPUT_DIR}/${OUTPUT_FILE}"
echo "=============================================="

# Build the command
CMD="python3 ${SCRIPT_DIR}/plot_3poi_profile.py"
CMD+=" --input ${INPUT_DIR}"
CMD+=" --poi ${POI}"
CMD+=" --output ${OUTPUT_FILE}"
CMD+=" --output-dir ${OUTPUT_DIR}"
CMD+=" --data-type ${DATA_TYPE}"
CMD+=" --title \"${TITLE}\""
[[ -n "${NO_ATLAS}" ]] && CMD+=" ${NO_ATLAS}"
[[ -n "${NO_LEGEND}" ]] && CMD+=" ${NO_LEGEND}"
[[ -n "${NO_ERRORS}" ]] && CMD+=" ${NO_ERRORS}"

# Run the plotting script
eval "${CMD}"

echo ""
echo "Done: ${OUTPUT_DIR}/${OUTPUT_FILE}"
