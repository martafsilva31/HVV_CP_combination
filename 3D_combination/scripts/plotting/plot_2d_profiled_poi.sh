#!/bin/bash
# Plot 2D scan results showing the profiled value of the floating Wilson coefficient
#
# Usage: ./plot_2d_profiled_poi.sh --input <dir> --poi1 <poi1> --poi2 <poi2> [options]
#
# Required:
#   --input DIR           Input directory containing ROOT scan files 
#   --poi1 POI            First scanned POI (x-axis)
#   --poi2 POI            Second scanned POI (y-axis)
#
# Optional:
#   --floating POI        Floating POI for z-axis (default: auto-detect)
#   --output FILE         Output filename (default: profiled_<poi1>_<poi2>.pdf)
#   --output-dir DIR      Output directory (default: same as input/../plots)
#   --no-atlas            Disable ATLAS label
#   --interpolation TYPE  Interpolation method: linear, cubic, nearest (default: linear)
#   --ncontours N         Number of contour levels (default: 50)
#   --no-contour-lines    Disable contour lines
#   -h, --help            Show this help message

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
INPUT_DIR=""
POI1=""
POI2=""
FLOATING=""
OUTPUT_FILE=""
OUTPUT_DIR=""
NO_ATLAS=""
INTERPOLATION="linear"
NCONTOURS="50"
NO_CONTOUR_LINES=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --input|-i)
            INPUT_DIR="$2"
            shift 2
            ;;
        --poi1|-p1)
            POI1="$2"
            shift 2
            ;;
        --poi2|-p2)
            POI2="$2"
            shift 2
            ;;
        --floating|-f)
            FLOATING="$2"
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
        --interpolation)
            INTERPOLATION="$2"
            shift 2
            ;;
        --ncontours)
            NCONTOURS="$2"
            shift 2
            ;;
        --no-contour-lines)
            NO_CONTOUR_LINES="--no-contour-lines"
            shift
            ;;
        -h|--help)
            head -21 "$0" | tail -20
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

if [[ -z "${POI1}" ]]; then
    echo "Error: --poi1 is required"
    echo "Use --help for usage information"
    exit 1
fi

if [[ -z "${POI2}" ]]; then
    echo "Error: --poi2 is required"
    echo "Use --help for usage information"
    exit 1
fi

# Check if input directory exists
if [[ ! -d "${INPUT_DIR}" ]]; then
    echo "Error: Input directory does not exist: ${INPUT_DIR}"
    exit 1
fi

# Auto-detect data type and model from path
DATA_TYPE="Data"
if [[ "${INPUT_DIR}" == *"asimov"* ]]; then
    DATA_TYPE="Asimov"
fi

MODEL_TYPE="linear"
if [[ "${INPUT_DIR}" == *"quad"* ]]; then
    MODEL_TYPE="quadratic"
fi

# Set default output file if not specified
if [[ -z "${OUTPUT_FILE}" ]]; then
    OUTPUT_FILE="profiled_${POI1}_${POI2}_${MODEL_TYPE}_${DATA_TYPE,,}"
fi

# Ensure .pdf extension
if [[ "${OUTPUT_FILE}" != *.pdf ]]; then
    OUTPUT_FILE="${OUTPUT_FILE}.pdf"
fi

# Set default output directory if not specified
if [[ -z "${OUTPUT_DIR}" ]]; then
    # Default to a profiled_plots subdirectory alongside the input
    OUTPUT_DIR="$(dirname "${INPUT_DIR}")/../plots/profiled_2d"
fi

# Create output directory
mkdir -p "${OUTPUT_DIR}"

echo "========================================"
echo "2D Profiled POI Density Plot"
echo "========================================"
echo "Input directory: ${INPUT_DIR}"
echo "POI 1 (x-axis): ${POI1}"
echo "POI 2 (y-axis): ${POI2}"
echo "Floating POI:   ${FLOATING:-auto-detect}"
echo "Data type:      ${DATA_TYPE}"
echo "Model:          ${MODEL_TYPE}"
echo "Output:         ${OUTPUT_DIR}/${OUTPUT_FILE}"
echo "Interpolation:  ${INTERPOLATION}"
echo "Contours:       ${NCONTOURS}"
echo "========================================"

# Build command
CMD="python3 ${SCRIPT_DIR}/plot_2d_profiled_poi.py"
CMD="${CMD} --input \"${INPUT_DIR}\""
CMD="${CMD} --poi1 ${POI1}"
CMD="${CMD} --poi2 ${POI2}"
CMD="${CMD} --output \"${OUTPUT_FILE}\""
CMD="${CMD} --output-dir \"${OUTPUT_DIR}\""
CMD="${CMD} --interpolation ${INTERPOLATION}"
CMD="${CMD} --ncontours ${NCONTOURS}"

if [[ -n "${FLOATING}" ]]; then
    CMD="${CMD} --floating ${FLOATING}"
fi

if [[ -n "${NO_ATLAS}" ]]; then
    CMD="${CMD} ${NO_ATLAS}"
fi

if [[ -n "${NO_CONTOUR_LINES}" ]]; then
    CMD="${CMD} ${NO_CONTOUR_LINES}"
fi

# Run the plotting script
echo ""
echo "Running: ${CMD}"
echo ""
eval ${CMD}

echo ""
echo "Done!"
