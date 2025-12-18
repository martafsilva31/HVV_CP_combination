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
#   --no-atlas            Disable ATLAS label
#   --no-legend           Disable legend
#   --no-errors           Disable uncertainty bands
#   -h, --help            Show this help message

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
INPUT_DIR=""
POI=""
OUTPUT_FILE=""
OUTPUT_DIR=""
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
            head -17 "$0" | tail -16
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
if [[ "${INPUT_DIR}" == *"/asimov/"* ]]; then
    DATA_TYPE="Asimov"
elif [[ "${INPUT_DIR}" == *"/obs/"* ]]; then
    DATA_TYPE="Data"
else
    DATA_TYPE="Data"
fi

# Auto-detect model type from path
if [[ "${INPUT_DIR}" == *"linear_only"* ]]; then
    MODEL_LABEL="Linear"
elif [[ "${INPUT_DIR}" == *"linear_plus_quadratic"* ]] || [[ "${INPUT_DIR}" == *"quadratic"* ]]; then
    MODEL_LABEL="Quadratic"
else
    MODEL_LABEL=""
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
    OUTPUT_FILE="profile_${POI}.pdf"
fi

# Ensure .pdf extension
if [[ "${OUTPUT_FILE}" != *.pdf ]]; then
    OUTPUT_FILE="${OUTPUT_FILE}.pdf"
fi

# Create output directory
mkdir -p "${OUTPUT_DIR}"

echo "=============================================="
echo "3POI Profile Plot"
echo "=============================================="
echo "Input:     ${INPUT_DIR}"
echo "POI:       ${POI} (${POI_LABEL})"
echo "Model:     ${MODEL_LABEL:-Auto}"
echo "Data type: ${DATA_TYPE}"
echo "Output:    ${OUTPUT_DIR}/${OUTPUT_FILE}"
echo "=============================================="

# Run the plotting script
python3 "${SCRIPT_DIR}/plot_3poi_profile.py" \
    --input "${INPUT_DIR}" \
    --poi "${POI}" \
    --output "${OUTPUT_FILE}" \
    --output-dir "${OUTPUT_DIR}" \
    --data-type "${DATA_TYPE}" \
    ${NO_ATLAS} ${NO_LEGEND} ${NO_ERRORS}

echo ""
echo "Done: ${OUTPUT_DIR}/${OUTPUT_FILE}"
