#!/usr/bin/env bash
# =============================================================================
# plot_wide_range_results.sh - Plot all wide-range linear stat-only 2D scans
# =============================================================================
# Produces:
# 1. 2D density plots with contours (deltaNLL)
# 2. 2D profiled POI plots (value of floating 3rd POI)
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_BASE="/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/output/2D_scans_linear_statonly_wide_range"
OUTPUT_DIR="/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/output/plots/2D_wide_range"

# Setup ATLAS environment if ROOT not available
set +e
if ! python3 -c "import ROOT" 2>/dev/null; then
    echo "Setting up ATLAS environment..."
    export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
    source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh 2>/dev/null
    asetup StatAnalysis,0.3.1 2>/dev/null
fi
set -e

mkdir -p "${OUTPUT_DIR}/density"
mkdir -p "${OUTPUT_DIR}/profiled"

echo "=============================================="
echo "Plotting Wide-Range Linear Stat-Only Results"
echo "=============================================="
echo "Input:  ${INPUT_BASE}"
echo "Output: ${OUTPUT_DIR}"
echo "=============================================="
echo

# Define all scan configurations
# Format: workspace:poi1:poi2:floating_poi
SCANS=(
    "linear_obs:cHWtil_combine:cHBtil_combine:cHWBtil_combine"
    "linear_obs:cHWtil_combine:cHWBtil_combine:cHBtil_combine"
    "linear_obs:cHBtil_combine:cHWBtil_combine:cHWtil_combine"
    "linear_asimov:cHWtil_combine:cHBtil_combine:cHWBtil_combine"
    "linear_asimov:cHWtil_combine:cHWBtil_combine:cHBtil_combine"
    "linear_asimov:cHBtil_combine:cHWBtil_combine:cHWtil_combine"
)

for scan in "${SCANS[@]}"; do
    IFS=':' read -r ws poi1 poi2 floating <<< "$scan"
    
    # Construct input directory
    INPUT_DIR="${INPUT_BASE}/root_${ws}_${poi1}_${poi2}_stat_only_wide_range_parallel"
    
    if [[ ! -d "${INPUT_DIR}" ]]; then
        echo "WARNING: Input directory not found: ${INPUT_DIR}"
        continue
    fi
    
    # Check if ROOT files exist
    nfiles=$(ls "${INPUT_DIR}"/*.root 2>/dev/null | wc -l)
    if [[ $nfiles -eq 0 ]]; then
        echo "WARNING: No ROOT files in ${INPUT_DIR}"
        continue
    fi
    
    # Determine data type for naming
    if [[ "$ws" == *"asimov"* ]]; then
        data_type="asimov"
    else
        data_type="obs"
    fi
    
    echo ">>> Processing: ${ws} / ${poi1} vs ${poi2}"
    echo "    Floating: ${floating}"
    echo "    Files: ${nfiles}"
    
    # -------------------------------------------------------------------------
    # 1. Profiled POI plot (showing the value of the floating parameter)
    # -------------------------------------------------------------------------
    PROFILED_OUTPUT="${OUTPUT_DIR}/profiled/profiled_${floating}_${poi1}_vs_${poi2}_linear_wide_${data_type}.pdf"
    
    echo "    Creating profiled plot..."
    python3 "${SCRIPT_DIR}/plot_2d_profiled_poi.py" \
        --input "${INPUT_DIR}" \
        --poi1 "${poi1}" \
        --poi2 "${poi2}" \
        --floating "${floating}" \
        --output "${PROFILED_OUTPUT}" \
        --interpolation linear \
        --ncontours 50 2>&1 | grep -v "^$" | sed 's/^/      /'
    
    echo ""
done

echo "=============================================="
echo "All plots complete!"
echo "Profiled plots: ${OUTPUT_DIR}/profiled/"
echo "=============================================="
