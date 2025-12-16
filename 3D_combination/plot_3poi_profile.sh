#!/bin/bash
# Plot 3POI profile scan results
# Usage: ./plot_3poi_profile.sh <name> <model> <stat_type> <data_type> <poi>

set -e

NAME=${1:-"linear_asimov"}
MODEL=${2:-"linear_only"}
STAT_TYPE=${3:-"stat_only"}
DATA_TYPE=${4:-"asimov"}
POI=${5:-"cHWtil_combine"}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_DIR="${SCRIPT_DIR}/output/3POI_1D_scans/${MODEL}/${STAT_TYPE}/${DATA_TYPE}/root_${NAME}_${POI}_sequential"
OUTPUT_DIR="${SCRIPT_DIR}/output/3POI_1D_scans/${MODEL}/${STAT_TYPE}/${DATA_TYPE}/plots"

# Determine data label for plot
if [[ "${DATA_TYPE}" == "asimov" ]]; then
    DATA_LABEL="Asimov"
else
    DATA_LABEL="Data"
fi

# Determine model label
if [[ "${MODEL}" == "linear_only" ]]; then
    MODEL_LABEL="Linear"
else
    MODEL_LABEL="Quadratic"
fi

# POI display name
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
    *)
        POI_LABEL="${POI}"
        ;;
esac

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Output file name
OUTPUT_FILE="profile_${NAME}_${POI}.pdf"

echo "=============================================="
echo "3POI Profile Plot"
echo "=============================================="
echo "Name:      ${NAME}"
echo "Model:     ${MODEL} (${MODEL_LABEL})"
echo "Stat type: ${STAT_TYPE}"
echo "Data type: ${DATA_TYPE} (${DATA_LABEL})"
echo "POI:       ${POI} (${POI_LABEL})"
echo ""
echo "Input:     ${INPUT_DIR}"
echo "Output:    ${OUTPUT_DIR}/${OUTPUT_FILE}"
echo "=============================================="

# Check if input directory exists
if [[ ! -d "${INPUT_DIR}" ]]; then
    echo "Error: Input directory not found: ${INPUT_DIR}"
    echo ""
    echo "Available directories:"
    ls -d "${SCRIPT_DIR}/output/3POI_1D_scans/${MODEL}/${STAT_TYPE}/${DATA_TYPE}/root_"* 2>/dev/null || echo "  None found"
    exit 1
fi

# Run the plotting script
python3 "${SCRIPT_DIR}/plot_3poi_profile.py" \
    --input "${INPUT_DIR}" \
    --poi "${POI}" \
    --output "${OUTPUT_FILE}" \
    --output-dir "${OUTPUT_DIR}" \
    --data-type "${DATA_LABEL}" \
    --title "${MODEL_LABEL} EFT - ${POI_LABEL} Scan (${DATA_LABEL})"

echo ""
echo "Done!"
echo "Output: ${OUTPUT_DIR}/${OUTPUT_FILE}"
